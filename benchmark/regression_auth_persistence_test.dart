// JellyAmp P0.5 step 11 — critical regression: LOGIN + AUTHENTICATION
// PERSISTENCE + SERVER-RECONNECT STATE.
//
// Exercises the REAL FinampUserHelper (lib/services/finamp_user_helper.dart)
// against a REAL Isar FinampUser collection, with ONLY the platform storage
// boundary faked:
//   - flutter_secure_storage method channel -> in-memory map (the token vault);
//   - package_info method channel -> a fixed current version;
//   - device_info needs NO fake on Linux (reads /etc/os-release + machine-id).
//
// This exercises the real saveUser/currentUser/removeUser/hydrateAccessTokens
// auth-persistence state machine (token moved out of plaintext into secure
// storage + Isar user row, restored on restart) without any server/network.
//
// Run:  flutter test benchmark/regression_auth_persistence_test.dart
import 'dart:async';
import 'dart:io';

import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/services/finamp_user_helper.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:device_info_plus_platform_interface/device_info_plus_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:isar/isar.dart';

import 'regression_helpers.dart';

/// A minimal fake [DeviceInfoPlatform] that returns a LinuxDeviceInfo, so
/// DeviceInfoPlugin().linuxInfo works headless (it casts to LinuxDeviceInfo).
class _FakeDeviceInfoPlatform extends DeviceInfoPlatform {
  @override
  Future<BaseDeviceInfo> deviceInfo() async => LinuxDeviceInfo(
        name: 'Test',
        id: 'test',
        prettyName: 'Test',
        machineId: 'device-1',
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Isar isar;
  late Directory tempDir;
  final storage = <String, String>{};

  setUpAll(() async {
    (isar, tempDir) = await openTempIsar([FinampUserSchema], name: 'auth');
    GetIt.instance.registerSingleton<Isar>(isar);
    GetIt.instance.registerSingleton<ProviderContainer>(ProviderContainer());
    // --- ALL platform mocks registered FIRST, before helper construction
    //     (setAuthHeader / constructor chain calls them synchronously) ---
    // Register a real fake DeviceInfoPlatform so DeviceInfoPlugin().linuxInfo
    // (a cast to LinuxDeviceInfo) works headless (the Linux plugin's
    // registerWith() does NOT run in flutter test).
    DeviceInfoPlatform.instance = _FakeDeviceInfoPlatform();

    // fake platform secure-storage vault (in-memory)
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async {
        final args = (call.arguments as Map?) ?? {};
        final key = args['key'] as String?;
        switch (call.method) {
          case 'read':
            return storage[key];
          case 'write':
            storage[key!] = args['value'] as String;
            return null;
          case 'delete':
            storage.remove(key);
            return null;
          case 'deleteAll':
            storage.clear();
            return null;
          case 'containsKey':
            return storage.containsKey(key);
          case 'readAll':
            return Map<String, String>.from(storage);
          case 'isProtectedDataAvailable':
            return null;
          default:
            return null;
        }
      },
    );

    // fake package_info current version
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/package_info'),
      (call) async => {
        'appName': 'Jellyamp',
        'packageName': 'com.unicornsonlsd.finamp',
        'version': '1.1.0',
        'buildNumber': '1',
        'buildSignature': '',
      },
    );

    // Register the real helper once (production does this in setupFinampUserHelper)
    // so GetIt-dependent calls (getAuthHeader / hydrateAccessTokens) resolve.
    final helper = FinampUserHelper(deviceId: 'dev-1');
    GetIt.instance.registerSingleton<FinampUserHelper>(helper);
    await helper.setAuthHeader();
  });

  tearDownAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'), null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('dev.fluttercommunity.plus/package_info'), null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('dev.fluttercommunity.plus/device_info'), null);
    await isar.close(deleteFromDisk: true);
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    await GetIt.instance.reset();
  });

  FinampUser makeUser(String id, {String token = 'secret-token'}) => FinampUser(
        id: id,
        publicAddress: 'https://jellyfin.example',
        localAddress: 'http://192.168.1.10',
        preferLocalNetwork: true,
        isLocal: true,
        accessToken: token,
        serverId: 'server-1',
      );

  test('saveUser persists the user and moves the token out of plaintext', () async {
    final helper = GetIt.instance<FinampUserHelper>();

    expect(helper.isUsersEmpty, isTrue);
    await helper.saveUser(makeUser('user-1'));

    // Current user is the saved one.
    expect(helper.currentUser!.id, 'user-1');
    expect(helper.currentUserId, 'user-1');
    expect(helper.isUsersEmpty, isFalse);

    // The Isar row's accessToken is cleared (token moved to secure storage).
    final row = await isar.finampUsers.get(0);
    expect(row!.accessToken, isEmpty, reason: 'token must not persist in plaintext Isar');
    // ...and it is in the secure-storage vault.
    expect(storage['finamp_accessToken_user-1'], 'secret-token');
  });

  test('auth persists across app restart and tokens hydrate from secure storage', () async {
    // Restart, first half: nothing but the vault may hold the token. This is the
    // security-relevant contract, and it is checked on the DB, not on a live
    // object that may hydrate at any moment.
    final persisted = await isar.finampUsers.get(0);
    expect(persisted!.accessToken, isEmpty, reason: 'no plaintext token in Isar after restart');

    // "Restart": a brand-new helper on the same DB (fresh instance, same Isar).
    final helper = FinampUserHelper(deviceId: 'dev-1');
    // setAuthHeader() hydrates from the vault on purpose (finamp_user_helper.dart:
    // a background isolate starts with an empty token cache and would otherwise
    // send an Authorization header with no Token and 401 every request), so the
    // contract is NOT "the token is still absent after this call" — it is "the
    // header carries the vaulted token".
    await helper.setAuthHeader();
    expect(helper.isUsersEmpty, isFalse, reason: 'user row survived');
    expect(helper.currentUser!.id, 'user-1', reason: 'auth persistence');
    expect(helper.currentUser!.accessToken, 'secret-token', reason: 'hydrated from the vault');
    expect(storage['finamp_accessToken_user-1'], 'secret-token', reason: 'vault still authoritative');

    // Hydration is idempotent: a second pass must not blank or duplicate it.
    await helper.hydrateAccessTokens();
    expect(helper.currentUser!.accessToken, 'secret-token');

    // A saved queue / playback state uses the auth header for server reconnect;
    // it must not be empty and must carry the user id AND the vaulted token.
    final header = helper.authorizationHeader;
    expect(header, startsWith('MediaBrowser '));
    expect(header, contains('UserId="user-1"'));
    expect(header, contains('Token="secret-token"'), reason: 'header must carry the vaulted token');
  });

  test('removeUser clears the current user and the stored token', () async {
    final helper = GetIt.instance<FinampUserHelper>();
    expect(helper.currentUser, isNotNull);

    helper.removeUser('user-1');

    expect(helper.isUsersEmpty, isTrue, reason: 'user removed');
    expect(helper.currentUser, isNull);
    expect(helper.currentUserId, isNull);
    expect(storage.containsKey('finamp_accessToken_user-1'), isFalse, reason: 'vault entry scrubbed');
  });
}
