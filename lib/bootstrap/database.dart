import 'dart:io';

import 'package:finamp/hive_registrar.g.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/locale_adapter.dart';
import 'package:finamp/models/migration_adapters.dart';
import 'package:finamp/models/theme_mode_adapter.dart';
import 'package:finamp/services/downloads_service.dart';
import 'package:finamp/services/downloads_service_backend.dart';
import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_ce_flutter/adapters.dart';
import 'package:isar/isar.dart';
import 'package:path/path.dart' as path_helper;
import 'package:path_provider/path_provider.dart';

/// Opens the Hive boxes (settings, queues, offline listens, cached themes,
/// update state, last server URL) and the Isar database used for downloads and
/// users, registering the Isar instance with the service locator.
///
/// P0.4: extracted from `main.dart` (was `setupHive`). Order and behavior are
/// unchanged.
Future<void> setupHive() async {
  final dir =
      (Platform.isAndroid || Platform.isIOS)
          ? await getApplicationDocumentsDirectory()
          : await getApplicationSupportDirectory();

  // Use Hive.init instead of initFlutter to set correct default path.
  WidgetsFlutterBinding.ensureInitialized();
  Hive.init(dir.path);
  Hive.registerAdapters();
  Hive.registerAdapter(ThemeModeAdapter());
  Hive.registerAdapter(ColorAdapter());
  Hive.registerAdapter(LocaleAdapter());
  Hive.registerAdapter(FinampStorableQueueInfoMigrationAdapter());

  await Future.wait([
    Hive.openBox<FinampSettings>("FinampSettings", path: dir.path),
    Hive.openBox<FinampStorableQueueInfo>("Queues", path: dir.path),
    Hive.openBox<OfflineListen>("OfflineListens", path: dir.path),
    Hive.openBox<RawThemeResult>("CachedThemes", path: dir.path),
    Hive.openBox<String>("UpdateState", path: dir.path),
    Hive.openBox<String>("LastServerUrl", path: dir.path),
  ]);

  // If the settings box is empty, we add an initial settings value here.
  Box<FinampSettings> finampSettingsBox = Hive.box("FinampSettings");
  if (finampSettingsBox.isEmpty) {
    await finampSettingsBox.put("FinampSettings", await FinampSettings.create());
  }

  final compactFile = File(path_helper.join(dir.path, "$isarDatabaseName.isar.compact"));
  if (compactFile.existsSync()) {
    compactFile.deleteSync();
  }
  final isar = await Isar.open(
    [DownloadItemSchema, IsarTaskDataSchema, FinampUserSchema, DownloadedLyricsSchema],
    directory: dir.path,
    name: isarDatabaseName,
    compactOnLaunch: CompactCondition(minBytes: 5 * 1024 * 1024),
    relaxedDurability: true,
  );
  GetIt.instance.registerSingleton(isar);
}
