import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:finamp/bootstrap/audio.dart';
import 'package:finamp/bootstrap/database.dart';
import 'package:finamp/bootstrap/downloads.dart';
import 'package:finamp/bootstrap/migrations.dart';
import 'package:finamp/bootstrap/networking.dart';
import 'package:finamp/bootstrap/platform.dart';
import 'package:finamp/services/album_image_provider.dart';
import 'package:finamp/services/client_certificate_installer.dart';
import 'package:finamp/services/data_source_service.dart';
import 'package:finamp/services/dbus_manager.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/network_manager.dart';
import 'package:finamp/services/theme_provider.dart';
import 'package:finamp/setup_logging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl_standalone.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../components/global_snackbar.dart';

final _mainLog = Logger("Main()");

/// Tracks when the app process began starting up. Used for diagnostics.
late DateTime startTime;

/// The GlobalKey mounted by the app's root [UncontrolledProviderScope]. Shared
/// between startup ([setupProviders]) and the widget tree ([JellyampApp]) so
/// the frame-builder fallback can rebuild the provider scope.
final providerScopeKey = GlobalKey();

final flutterLogger = Logger("Flutter");

/// Immutable snapshot of the startup dependencies handed to [JellyampApp].
///
/// P0.4: the application still reads services from the existing GetIt
/// service-locator and riverpod providers; this object carries the runtime
/// references the widget tree needs without introducing new global state.
class JellyampDependencies {
  const JellyampDependencies({required this.providerContainer});

  final ProviderContainer providerContainer;
}

/// This is used by the login testing flag to redirect file accesses to the testing folder.
/// Download base directories are not redirected, so loginTesting flag should be avoided on mobile.
class TestingPathProvider extends PathProviderPlatform {
  static Future<Directory> baseDirectory() async {
    // If we're on desktop, use the integration_test directory in the checkout tree
    // If we're on mobile and that doesn't exist, use cache directory.
    Directory outerDirectory = Directory("integration_test");
    if (!outerDirectory.existsSync()) {
      outerDirectory = await getApplicationCacheDirectory();
    }
    final outerPath = outerDirectory.absolute.path;
    return Directory(path.join(outerPath, "testing"));
  }

  TestingPathProvider(Directory dataDir) {
    basePath = dataDir.absolute.path;
  }

  late final String basePath;

  Future<String> _getPath(String extension) async {
    final directory = Directory(path.join(basePath, extension));
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
    return directory.absolute.path;
  }

  @override
  Future<String?> getTemporaryPath() => _getPath("tmp");

  @override
  Future<String?> getApplicationSupportPath() => _getPath("support");

  @override
  Future<String?> getApplicationDocumentsPath() => _getPath("documents");

  @override
  Future<String?> getApplicationCachePath() => _getPath("cache");
}

class FinampProviderObserver extends ProviderObserver {
  @override
  void providerDidFail(
    ProviderBase<Object?> provider,
    Object error,
    StackTrace stackTrace,
    ProviderContainer container,
  ) {
    GlobalSnackbar.error(error);
  }
}

/// Performs the complete application startup in its explicit original order and
/// returns the dependencies the widget tree needs. Throws if any step fails;
/// the caller maps a failure to the startup [FinampErrorApp] (or rethrows when
/// integration testing).
///
/// P0.4: extracted from `main.dart`. The step order, the intermediate log
/// lines, and the fatal-error behavior are unchanged.
Future<JellyampDependencies> bootstrap({required List<String> commandLineArgs, bool integrationTesting = false}) async {
  startTime = DateTime.now();
  await setupLogging();
  await setupEdgeToEdgeOverlayStyle();
  _mainLog.info("Setup edge-to-edge overlay");
  await setupHive();
  _mainLog.info("Setup hive and isar");
  // Apply the persisted verbose logging preference now that settings exist.
  applyLogLevel();
  await runMigrations();
  _mainLog.info("Completed applicable migrations");
  await trustAndroidUserCerts();
  await ClientCertificateInstaller().installClientCertificate();
  _mainLog.info("Installed client certificate");
  await setupFinampUserHelper();
  _mainLog.info("Setup user helper");
  await setupJellyfinApiData();
  _mainLog.info("setup jellyfin api");
  setupOfflineListenLogHelper();
  _mainLog.info("Setup offline listen tracking");
  await setupDownloadsHelper();
  _mainLog.info("Setup downloads service");
  await setupProviders();
  _mainLog.info("Setup providers");
  await setupOSIntegration(commandLineArgs);
  _mainLog.info("Setup os integrations");
  await setupPlayOnService();
  _mainLog.info("Setup PlayOnService");
  await setupPlaybackServices();
  _mainLog.info("Setup audio player");
  await setupKeepScreenOnHelper();
  _mainLog.info("Setup KeepScreenOnHelper");
  await setupDiscordRpc();
  _mainLog.info("Setup Discord RPC");

  if (!integrationTesting) {
    FlutterError.onError = (FlutterErrorDetails details) {
      var error = details.exception;
      if (error is Error) {
        details = details.copyWith(stack: error.stackTrace ?? details.stack);
      }
      FlutterError.presentError(details);
      flutterLogger.severe(error, error, details.stack);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      flutterLogger.severe(error, error, stack);

      // We have not handled printing to console, flutter should still do that.
      return false;
    };
  }

  DartPluginRegistrant.ensureInitialized();

  await findSystemLocale();
  await initializeDateFormatting();
  unawaited(fetchSystemPalette());
  await initDBus();

  _mainLog.info("Launching main app");

  return JellyampDependencies(providerContainer: GetIt.instance<ProviderContainer>());
}

/// Sets up the riverpod [ProviderContainer], the image cache, the data source
/// service and offline state watching, plus the frame-builder fallback.
///
/// P0.4: extracted from `main.dart` (was `_setupProviders`).
Future<void> setupProviders() async {
  var container = ProviderContainer(observers: [FinampProviderObserver()]);
  GetIt.instance.registerSingleton<ProviderContainer>(container);
  // Make sure that finampSettingsProvider always has a value available
  container.listen(finampSettingsProvider, (_, __) {});
  await container.read(finampSettingsProvider.future);

  await initImageCache();

  DataSourceService.create();
  AutoOffline.startWatching();

  unawaited(
    Stream<void>.periodic(Duration(seconds: 1)).forEach((_) {
      if (!SchedulerBinding.instance.framesEnabled) {
        (providerScopeKey.currentContext as InheritedElement?)?.build();
      }
    }),
  );
}
