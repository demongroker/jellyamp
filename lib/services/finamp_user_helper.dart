import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/jellyfin_api.dart' as jellyfin_api;
import 'package:finamp/services/jellyfin_api_helper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_ce/hive.dart';
import 'package:isar/isar.dart';
import 'package:logging/logging.dart';

final finampUserHelperLogger = Logger("FinampUserHelper");

/// Helper class for Finamp users. Note that this class does not talk to the
/// Jellyfin server, so stuff like logging in/out is handled in JellyfinApiData.
class FinampUserHelper {
  FinampUserHelper({required this.deviceId}) {
    _isar.finampUsers.watchObjectLazy(0).listen((event) {
      _currentUserCache = null;
      setAuthHeader();
      if (GetIt.instance.isRegistered(type: ProviderContainer)) {
        GetIt.instance<ProviderContainer>().invalidate(finampCurrentUserProvider);
      }
    });
  }

  Future<void> setAuthHeader() async {
    // The access token lives in secure storage, and saveUser() blanks the copy
    // in Isar on purpose. The foreground isolate keeps it in _accessTokenCache,
    // but a background isolate starts with an empty cache — so without this
    // hydration it builds an Authorization header with no Token and every
    // request 401s (login works, library GETs fail).
    await hydrateAccessTokens();
    authorizationHeader = await jellyfin_api.getAuthHeader(deviceId: deviceId);
  }

  final _isar = GetIt.instance<Isar>();

  final _secureStorage = FlutterSecureStorage();
  final Map<String, String> _accessTokenCache = {};

  final String deviceId;

  final List<void Function()> _postUserHooks = [];

  /// Checks if there are any saved users.
  bool get isUsersEmpty => _isar.finampUsers.countSync() == 0;

  /// Loads the id from CurrentUserId. Returns null if no id is stored.
  String? get currentUserId => _isar.finampUsers.getSync(0)?.id;

  /// Loads the FinampUser with the id from CurrentUserId. Returns null if no
  /// user exists.
  FinampUser? get currentUser {
    var user = _currentUserCache ??= _isar.finampUsers.getSync(0);
    if (user != null && _accessTokenCache.containsKey(user.id)) {
      user.accessToken = _accessTokenCache[user.id]!;
    }
    return user;
  }

  FinampUser? _currentUserCache;

  Iterable<FinampUser> get finampUsers {
    final users = _isar.finampUsers.where().findAllSync();
    for (final u in users) {
      if (_accessTokenCache.containsKey(u.id)) {
        u.accessToken = _accessTokenCache[u.id]!;
      }
    }
    return users;
  }

  late String authorizationHeader;

  static final Provider<FinampUser?> finampCurrentUserProvider = Provider((ref) {
    return GetIt.instance<FinampUserHelper>().currentUser;
  });

  Future<void> migrateFromHive() async {
    await Hive.openBox<FinampUser>("FinampUsers");
    await Hive.openBox<String>("CurrentUserId");
    var currentUserId = Hive.box<String>("CurrentUserId").get("CurrentUserId");
    if (currentUserId != null) {
      var currentUser = Hive.box<FinampUser>("FinampUsers").get(currentUserId);
      if (currentUser != null) {
        _isar.writeTxnSync(() {
          _isar.finampUsers.putSync(currentUser, saveLinks: false);
        });
      }
    }
    // Scrub the legacy plaintext Hive user boxes now that the token lives in
    // secure storage + Isar. Leaving them on disk would keep the old
    // FinampUser.accessToken plaintext around (Advisor follow-up).
    for (final name in const ["FinampUsers", "CurrentUserId"]) {
      try {
        final box = Hive.box(name);
        await box.close();
        await Hive.deleteBoxFromDisk(name);
      } catch (e) {
        finampUserHelperLogger.warning("Failed to scrub legacy Hive box '$name': $e");
      }
    }
  }

  /// Hydrates access tokens from secure storage into memory and migrates any
  /// remaining plaintext Isar tokens to secure storage. Idempotent — safe to run
  /// on every startup.
  Future<void> hydrateAccessTokens() async {
    final users = _isar.finampUsers.where().findAllSync();
    for (final u in users) {
      final key = 'finamp_accessToken_${u.id}';
      final stored = await _secureStorage.read(key: key);
      if (stored != null && stored.isNotEmpty) {
        _accessTokenCache[u.id] = stored;
        if (u.accessToken.isNotEmpty) {
          u.accessToken = '';
          _isar.writeTxnSync(() => _isar.finampUsers.putSync(u, saveLinks: false));
        }
      } else if (u.accessToken.isNotEmpty) {
        await _secureStorage.write(key: key, value: u.accessToken);
        _accessTokenCache[u.id] = u.accessToken;
        u.accessToken = '';
        _isar.writeTxnSync(() => _isar.finampUsers.putSync(u, saveLinks: false));
      }
    }
  }

  /// Saves a new user to the Hive box and sets the CurrentUserId.
  Future<void> saveUser(FinampUser newUser) async {
    final token = newUser.accessToken;
    if (token.isNotEmpty) {
      await _secureStorage.write(key: 'finamp_accessToken_${newUser.id}', value: token);
      _accessTokenCache[newUser.id] = token;
      newUser.accessToken = '';
    }
    _isar.writeTxnSync(() {
      _isar.finampUsers.putSync(newUser, saveLinks: false);
    });
    _currentUserCache = null;
    await setAuthHeader();
    while (_postUserHooks.isNotEmpty) {
      _postUserHooks.removeAt(0)();
    }
  }

  void runUserHook(void Function() func) {
    if (currentUser != null) {
      func();
    } else {
      _postUserHooks.add(func);
    }
  }

  /// Sets the views of the current user
  void setCurrentUserViews(List<BaseItemDto> newViews) {
    FinampUser currentUserTemp = currentUser!;

    currentUserTemp.views = Map<BaseItemId, BaseItemDto>.fromEntries(newViews.map((e) => MapEntry(e.id, e)));
    currentUserTemp.currentViewId = currentUserTemp.views.keys.first;
    currentUserTemp.accessToken = ''; // token lives in secure storage; never re-persist plaintext

    _isar.writeTxnSync(() {
      _isar.finampUsers.putSync(currentUserTemp, saveLinks: false);
    });
    _currentUserCache = null;
  }

  void setCurrentUserCurrentViewId(BaseItemId newViewId) {
    FinampUser currentUserTemp = currentUser!;

    currentUserTemp.currentViewId = newViewId;
    currentUserTemp.accessToken = ''; // token lives in secure storage; never re-persist plaintext

    _isar.writeTxnSync(() {
      _isar.finampUsers.putSync(currentUserTemp, saveLinks: false);
    });
    _currentUserCache = null;
  }

  /// Removes the user with the given id. If the given id is the current user
  /// id, CurrentUserId is cleared.
  void removeUser(String id) {
    _isar.writeTxnSync(() {
      _isar.finampUsers.filter().idEqualTo(id).deleteAllSync();
    });
    _accessTokenCache.remove(id);
    _secureStorage.delete(key: 'finamp_accessToken_$id');
    if (_currentUserCache?.id == id) {
      _currentUserCache = null;
    }
  }
}

class UserInfo {
  final UserDto? jellyfinUser;
  final FinampUser? finampUser;

  UserInfo({required this.jellyfinUser, required this.finampUser});

  bool get isAdmin => jellyfinUser?.policy?.isAdministrator ?? false;

  @override
  String toString() {
    return "UserInfo(jellyfinUser: $jellyfinUser, finampUser: $finampUser)";
  }
}

class UserInfoProviders {
  static final AutoDisposeFutureProviderFamily<UserInfo?, String> userInfoProvider = FutureProvider.autoDispose
      .family<UserInfo?, String>((ref, userId) async {
        final jellyfinApiHelper = GetIt.instance<JellyfinApiHelper>();

        final currentUserInfo = ref.watch(FinampUserHelper.finampCurrentUserProvider);
        final bool isCurrentUser = currentUserInfo?.id == userId;
        UserInfo userInfo = UserInfo(jellyfinUser: null, finampUser: currentUserInfo);
        finampUserHelperLogger.fine("Fetching user info for '$userId'");

        //!!! return last-known value if offline, instead of making a network request
        if (ref.watch(finampSettingsProvider.isOffline)) {
          return ref.state.value;
        }

        UserDto jellyfinUser;
        try {
          final user = await jellyfinApiHelper.getUserById(userId);
          if (user == null) {
            throw Exception("Received null user info");
          }
          jellyfinUser = user;
        } catch (e) {
          finampUserHelperLogger.severe("Failed to fetch user '$userId':", e);
          return null;
        }

        userInfo = UserInfo(jellyfinUser: jellyfinUser, finampUser: isCurrentUser ? currentUserInfo : null);

        finampUserHelperLogger.fine("Fetched user info for '$userId': $userInfo");

        return userInfo;
      });

  /// Provider for additional user info fetched from the server
  static final currentUserInfoProvider = Provider<AsyncValue<UserInfo?>>((ref) {
    final currentUserId = ref.watch(FinampUserHelper.finampCurrentUserProvider)?.id;
    if (currentUserId != null) {
      return ref.watch(userInfoProvider(currentUserId));
    }
    return const AsyncValue.data(null);
  });
}
