import 'dart:async';
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:finamp/bootstrap/bootstrap.dart';
import 'package:finamp/color_schemes.g.dart';
import 'package:finamp/theme/jellyamp_theme.dart';
import 'package:finamp/components/Buttons/cta_medium.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/models/music_models.dart';
import 'package:finamp/screens/accessibility_settings_screen.dart';
import 'package:finamp/screens/active_downloads_screen.dart';
import 'package:finamp/screens/add_download_location_screen.dart';
import 'package:finamp/screens/album_screen.dart';
import 'package:finamp/screens/album_settings_screen.dart';
import 'package:finamp/screens/artist_screen.dart';
import 'package:finamp/screens/artist_settings_screen.dart';
import 'package:finamp/screens/audio_service_settings_screen.dart';
import 'package:finamp/screens/customization_settings_screen.dart';
import 'package:finamp/screens/downloads_location_screen.dart';
import 'package:finamp/screens/downloads_screen.dart';
import 'package:finamp/screens/downloads_settings_screen.dart';
import 'package:finamp/screens/genre_screen.dart';
import 'package:finamp/screens/genre_settings_screen.dart';
import 'package:finamp/screens/home_screen_settings_screen.dart';
import 'package:finamp/screens/interaction_settings_screen.dart';
import 'package:finamp/screens/language_selection_screen.dart';
import 'package:finamp/screens/layout_settings_screen.dart';
import 'package:finamp/screens/login_screen.dart';
import 'package:finamp/screens/logs_screen.dart';
import 'package:finamp/screens/lyrics_settings_screen.dart';
import 'package:finamp/screens/music_screen.dart';
import 'package:finamp/screens/network_settings_screen.dart';
import 'package:finamp/screens/playback_history_screen.dart';
import 'package:finamp/screens/playback_reporting_settings_screen.dart';
import 'package:finamp/screens/player_screen.dart';
import 'package:finamp/screens/player_settings_screen.dart';
import 'package:finamp/screens/playlist_edit_screen.dart';
import 'package:finamp/screens/queue_restore_screen.dart';
import 'package:finamp/screens/settings_screen.dart';
import 'package:finamp/screens/splash_screen.dart';
import 'package:finamp/screens/tabs_settings_screen.dart';
import 'package:finamp/screens/transcoding_settings_screen.dart';
import 'package:finamp/screens/view_selector.dart';
import 'package:finamp/screens/volume_normalization_settings_screen.dart';
import 'package:finamp/services/audio_service_helper.dart';
import 'package:finamp/services/carplay_helper.dart';
import 'package:finamp/services/discord_rpc.dart';
import 'package:finamp/services/finamp_logs_helper.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/ios_helpers.dart';
import 'package:finamp/services/item_by_id_provider.dart';
import 'package:finamp/services/item_helper.dart';
import 'package:finamp/services/keep_screen_on_helper.dart';
import 'package:finamp/services/music_player_background_task.dart';
import 'package:finamp/services/music_providers.dart';
import 'package:finamp/services/queue_service.dart';
import 'package:finamp/services/update_checker_provider.dart';
import 'package:finamp/services/widget_bindings_observer_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:gaimon/gaimon.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_ce_flutter/adapters.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';

import 'components/Buttons/simple_button.dart';
import 'components/connectivity_status_indicator.dart';
import 'components/LogsScreen/copy_logs_button.dart';
import 'components/LogsScreen/share_logs_button.dart';
import 'components/PlayerScreen/player_split_screen_scaffold.dart';
import 'components/Shortcuts/global_shortcut_manager.dart';
import 'components/global_snackbar.dart';

/// The root of the application, handed the startup dependencies by `main()`.
///
/// P0.4: replaces the previous `runApp(const Finamp())` entry. The widget tree
/// it mounts is identical to the original.
class JellyampApp extends StatelessWidget {
  const JellyampApp({super.key, required this.dependencies});

  final JellyampDependencies dependencies;

  @override
  Widget build(BuildContext context) {
    return Finamp(providerContainer: dependencies.providerContainer);
  }
}

class Finamp extends StatefulWidget {
  const Finamp({super.key, this.providerContainer});

  /// The riverpod container created during startup. When null (as in the
  /// integration-test harness) the container is read from the service locator,
  /// which is the same instance.
  final ProviderContainer? providerContainer;

  @override
  State<Finamp> createState() => _FinampState();
}

class _FinampState extends State<Finamp> with WindowListener {
  static final Logger windowManagerLogger = Logger("WindowManager");
  static final Logger linkHandlingLogger = Logger("LinkHandling");

  StreamSubscription<Uri>? _uriLinkSubscription;

  @override
  void initState() {
    super.initState();

    SchedulerBinding.instance.addPostFrameCallback((_) {
      _uriLinkSubscription = AppLinks().uriLinkStream.listen((uri) async {
        linkHandlingLogger.info("Received link: $uri");

        var state = GlobalSnackbar.navigatorState;
        if (state != null) {
          _handleAppLink(uri, state);
        } else {
          linkHandlingLogger.warning("No context available to handle link");
        }
      });
    });

    // If the app is running on desktop, we add a listener to the window manager
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      WindowManager.instance.addListener(this);
      // windowManager.setPreventClose(true); //!!! destroying the window manager instance doesn't seem to work on Windows release builds, the app just freezes instead
    }

    // iOS-specific setup (CarPlay, Siri)
    if (Platform.isIOS) {
      GetIt.instance<CarPlayHelper>().setupCarplay();
      IosSiriHandler.setup();
    }
  }

  void _handleAppLink(Uri uri, NavigatorState state) async {
    final container = GetIt.instance<ProviderContainer>();
    switch (uri.host) {
      case "internal":
        await state.pushNamed(uri.path);

      // Also see _hasInitialPlayLink in QueueService
      case "play":
        switch (uri.pathSegments) {
          case ["surprisemix"]:
            await GetIt.instance<AudioServiceHelper>().startSurpriseMeMix();
          case [String itemId]:
            final item = await container.read(itemByIdProvider(BaseItemId(itemId)).future);
            if (item != null) {
              await GetIt.instance<QueueService>().startSlicePlayback(
                await GetIt.instance<ProviderContainer>().read(
                  getPlayableSliceProvider(item: FinampPlayableDto.fromItem(item), startingOffset: 0).future,
                ),
              );
            }
          case _:
            linkHandlingLogger.warning("Link: $uri could not be deciphered by play handler");
        }

      case "show":
        switch (uri.pathSegments) {
          case [String itemId]:
            final item = await container.read(itemByIdProvider(BaseItemId(itemId)).future);
            if (item != null) {
              openItemPage(item, state, showTracks: true);
            }
          case _:
            linkHandlingLogger.warning("Link: $uri could not be deciphered by show handler");
        }

      case _:
        linkHandlingLogger.warning("Link: $uri could not be deciphered");
    }
  }

  @override
  Future<void> dispose() async {
    super.dispose();
    await DiscordRpc.stop().timeout(Duration(milliseconds: 500));
    await _uriLinkSubscription?.cancel();

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      WindowManager.instance.removeListener(this);
    }

    if (Platform.isIOS) {
      GetIt.instance<CarPlayHelper>().disposeCarplay();
    }
  }

  @override
  Widget build(BuildContext context) {
    return UncontrolledProviderScope(
      key: providerScopeKey,
      container: widget.providerContainer ?? GetIt.instance<ProviderContainer>(),
      child: GestureDetector(
        onTap: () {
          // This code resets focus and removes the focus highlight whenever we tap/click on the background
          // TODO is this actually needed?
          final navigatorContext = GlobalSnackbar.navigatorState?.context;
          if (navigatorContext == null) return;
          FocusScopeNode navigatorFocus = FocusScope.of(navigatorContext, createDependency: false);
          navigatorFocus.requestScopeFocus();
        },
        child: FinampProviderBuilder(child: FinampApp()),
      ),
    );
  }

  @override
  void onWindowEvent(String eventName) async {
    if (eventName == "move" || eventName == "resize") return;

    windowManagerLogger.finer("[WindowManager] onWindowEvent: $eventName");

    if (eventName == "moved" || eventName == "resized") {
      FinampSetters.setScreenSize(ScreenSize.from(await windowManager.getBounds()));

      windowManagerLogger.finer("Saved window size and position");
    }
  }

  @override
  void onWindowClose() async {
    if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      return;
    }

    // Destroy player on platforms using mediaKit.
    if (Platform.isWindows || Platform.isLinux) {
      await GetIt.instance<MusicPlayerBackgroundTask>().dispose();
      windowManagerLogger.info("Player disposed.");
    }
  }
}

class FinampApp extends ConsumerWidget {
  const FinampApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final useSystemTheme = ref.watch(finampSettingsProvider.useSystemAccentColor);
    // System Accent has priority over custom Accent
    Color? accentColor = ref.watch(
      useSystemTheme ? finampSettingsProvider.systemAccentColor : finampSettingsProvider.accentColor,
    );
    final themeMode = ref.watch(finampSettingsProvider.themeMode);
    final amoledTheme = ref.watch(finampSettingsProvider.amoledTheme);
    final locale = ref.watch(finampSettingsProvider.locale);
    // Trigger update check on app startup
    ref.watch(updateCheckerProvider);
    final transitionBuilder =
        MediaQuery.disableAnimationsOf(context)
            ? PageTransitionsTheme(
              // Disable page transitions on all platforms if [disableAnimations] is true, otherwise use default transitions
              builders: TargetPlatform.values.fold(
                <TargetPlatform, PageTransitionsBuilder>{},
                (previousValue, element) => previousValue..[element] = const NoTransitionPageTransitionsBuilder(),
              ),
            )
            : null;
    return MaterialApp(
      title: "Jellyamp",
      routes: {
        SplashScreen.routeName: (context) => const SplashScreen(),
        LoginScreen.routeName: (context) => const LoginScreen(),
        ViewSelector.routeName: (context) => const ViewSelector(),
        MusicScreen.routeName: (context) => const MusicScreen(),
        AlbumScreen.routeName: (context) => const AlbumScreen(),
        ArtistScreen.routeName: (context) => const ArtistScreen(),
        GenreScreen.routeName: (context) => const GenreScreen(),
        PlayerScreen.routeName: (context) => const PlayerScreen(key: ValueKey(PlayerScreen.routeName)),
        DownloadsScreen.routeName: (context) => const DownloadsScreen(),
        ActiveDownloadsScreen.routeName: (context) => const ActiveDownloadsScreen(),
        PlaybackHistoryScreen.routeName: (context) => const PlaybackHistoryScreen(),
        LogsScreen.routeName: (context) => const LogsScreen(),
        QueueRestoreScreen.routeName: (context) => const QueueRestoreScreen(),
        SettingsScreen.routeName: (context) => const SettingsScreen(),
        HomeScreenSettingsScreen.routeName: (context) => const HomeScreenSettingsScreen(),
        TranscodingSettingsScreen.routeName: (context) => const TranscodingSettingsScreen(),
        DownloadsLocationScreen.routeName: (context) => const DownloadsLocationScreen(),
        DownloadsSettingsScreen.routeName: (context) => const DownloadsSettingsScreen(),
        AddDownloadLocationScreen.routeName: (context) => const AddDownloadLocationScreen(),
        PlaybackReportingSettingsScreen.routeName: (context) => const PlaybackReportingSettingsScreen(),
        AudioServiceSettingsScreen.routeName: (context) => const AudioServiceSettingsScreen(),
        VolumeNormalizationSettingsScreen.routeName: (context) => const VolumeNormalizationSettingsScreen(),
        InteractionSettingsScreen.routeName: (context) => const InteractionSettingsScreen(),
        TabsSettingsScreen.routeName: (context) => const TabsSettingsScreen(),
        LayoutSettingsScreen.routeName: (context) => const LayoutSettingsScreen(),
        CustomizationSettingsScreen.routeName: (context) => const CustomizationSettingsScreen(),
        PlayerSettingsScreen.routeName: (context) => const PlayerSettingsScreen(),
        LyricsSettingsScreen.routeName: (context) => const LyricsSettingsScreen(),
        LanguageSelectionScreen.routeName: (context) => const LanguageSelectionScreen(),
        AlbumSettingsScreen.routeName: (context) => const AlbumSettingsScreen(),
        ArtistSettingsScreen.routeName: (context) => const ArtistSettingsScreen(),
        GenreSettingsScreen.routeName: (context) => const GenreSettingsScreen(),
        NetworkSettingsScreen.routeName: (context) => const NetworkSettingsScreen(),
        AccessibilitySettingsScreen.routeName: (context) => const AccessibilitySettingsScreen(),
        PlaylistEditScreen.routeName:
            (context) => PlaylistEditScreen(playlist: ModalRoute.settingsOf(context)!.arguments as BaseItemDto),
        //ShowAllScreen.routeName: (context) => const ShowAllScreen(),
      },
      initialRoute: SplashScreen.routeName,
      navigatorObservers: [SplitScreenNavigatorObserver(), KeepScreenOnObserver()],
      builder: buildAppWithConnectivityIndicator,
      theme: applyJellyAmpTheme(
        ThemeData(
          brightness: Brightness.light,
          colorScheme: getColorScheme(accentColor, Brightness.light, amoledTheme),
          appBarTheme: const AppBarThemeData(
            systemOverlayStyle: SystemUiOverlayStyle(
              statusBarBrightness: Brightness.light,
              statusBarIconBrightness: Brightness.dark,
              systemNavigationBarIconBrightness: Brightness.dark,
            ),
          ),
          snackBarTheme: const SnackBarThemeData(
            //TODO get rid of floating action buttons and re-enable the floating behavior and insetPadding
            // behavior: SnackBarBehavior.floating,
            elevation: 10.0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12.0))),
            // insetPadding: EdgeInsets.symmetric(
            //   horizontal: 12.0,
            //   vertical: 0.0,
            // ),
            dismissDirection: DismissDirection.horizontal,
          ),
          tooltipTheme: const TooltipThemeData(waitDuration: Duration(milliseconds: 800), preferBelow: false),
          pageTransitionsTheme: transitionBuilder,
        ),
      ),
      darkTheme: applyJellyAmpTheme(
        ThemeData(
          brightness: Brightness.dark,
          colorScheme: getColorScheme(accentColor, Brightness.dark, amoledTheme),
          snackBarTheme: const SnackBarThemeData(
            //TODO get rid of floating action buttons and re-enable the floating behavior and insetPadding
            // behavior: SnackBarBehavior.floating,
            elevation: 10.0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12.0))),
            // insetPadding: EdgeInsets.symmetric(
            //   horizontal: 12.0,
            //   vertical: 0.0,
            // ),
            dismissDirection: DismissDirection.horizontal,
          ),
          pageTransitionsTheme: transitionBuilder,
        ),
      ),
      scrollBehavior: FinampScrollBehavior(),
      themeMode: themeMode,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      // We awkwardly put English as the first supported locale so
      // that basicLocaleListResolution falls back to it instead of
      // the first language in supportedLocales (Arabic as of writing)
      localeListResolutionCallback:
          (locales, supportedLocales) =>
              basicLocaleListResolution(locales, [const Locale("en")].followedBy(supportedLocales)),
      locale: locale,
      scaffoldMessengerKey: GlobalSnackbar.rawMaterialAppScaffoldKey,
      navigatorKey: GlobalSnackbar.rawMaterialAppNavigatorKey,
      shortcuts: GlobalShortcuts.shortcutMap,
      actions: GlobalShortcuts.actionMap,
    );
  }
}

class FinampErrorApp extends StatelessWidget {
  const FinampErrorApp({super.key, required this.error, this.trace});

  final dynamic error;
  final StackTrace? trace;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Jellyamp",
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(brightness: Brightness.light, colorScheme: lightColorScheme),
      darkTheme: ThemeData(brightness: Brightness.dark, colorScheme: darkColorScheme),
      supportedLocales: AppLocalizations.supportedLocales,
      home: ErrorScreen(error: error, trace: trace),
      scaffoldMessengerKey: GlobalSnackbar.rawMaterialAppScaffoldKey,
      navigatorKey: GlobalSnackbar.rawMaterialAppNavigatorKey,
    );
  }
}

class ErrorScreen extends StatelessWidget {
  const ErrorScreen({super.key, this.error, this.trace});

  final dynamic error;
  final StackTrace? trace;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Hero(tag: "finamp_logo", child: SvgPicture.asset('images/jellyamp_icon.svg', width: 75, height: 75)),
              const SizedBox(height: 16.0),
              Text.rich(
                TextSpan(
                  text: AppLocalizations.of(context)!.startupErrorTitle,
                  style: const TextStyle(fontSize: 14.0, fontWeight: FontWeight.w500),
                  children: [
                    TextSpan(
                      text: "\n\n${error.toString()}",
                      style: const TextStyle(
                        fontSize: 14.0,
                        fontWeight: FontWeight.bold,
                        fontFamily: "monospace",
                        color: Colors.red,
                      ),
                    ),
                    if (kDebugMode)
                      WidgetSpan(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: 8.0,
                            children: [
                              SimpleButton(
                                text: 'Delete FinampSettings',
                                icon: Icons.delete,
                                onPressed: () async {
                                  final dir =
                                      (Platform.isAndroid || Platform.isIOS)
                                          ? await getApplicationDocumentsDirectory()
                                          : await getApplicationSupportDirectory();

                                  await Hive.deleteBoxFromDisk("FinampSettings", path: dir.path);
                                  Gaimon.success();
                                },
                              ),
                              SimpleButton(
                                text: 'Delete Stored Queues',
                                icon: Icons.delete,
                                onPressed: () async {
                                  final dir =
                                      (Platform.isAndroid || Platform.isIOS)
                                          ? await getApplicationDocumentsDirectory()
                                          : await getApplicationSupportDirectory();

                                  await Hive.deleteBoxFromDisk("Queues", path: dir.path);
                                  Gaimon.success();
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    TextSpan(
                      text: "\n\n${AppLocalizations.of(context)!.startupErrorCallToAction}",
                      style: const TextStyle(fontSize: 14.0, fontWeight: FontWeight.w500),
                    ),
                    TextSpan(
                      text: "\n\n${AppLocalizations.of(context)!.startupErrorWorkaround}",
                      style: const TextStyle(fontSize: 10.0),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 10.0),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CTAMedium(
                    text: AppLocalizations.of(context)!.exportLogs,
                    icon: TablerIcons.file_download,
                    onPressed: () async {
                      final finampLogsHelper = GetIt.instance<FinampLogsHelper>();
                      await finampLogsHelper.exportLogs();
                    },
                  ),
                ],
              ),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [ShareLogsButton(), CopyLogsButton()]),
              SizedBox(height: 10.0),
              if (trace != null)
                Text.rich(
                  TextSpan(text: trace.toString(), style: const TextStyle(fontSize: 10.0, fontFamily: "monospace")),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// Show scrollbars on all vertically scrolling widgets by default
class FinampScrollBehavior extends MaterialScrollBehavior {
  const FinampScrollBehavior({this.interactive, this.scrollbars = true});

  // If interactive is null, platform default will be used
  final bool? interactive;
  final bool scrollbars;

  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) {
    if (!scrollbars) {
      return child;
    }
    switch (axisDirectionToAxis(details.direction)) {
      case Axis.horizontal:
        return child;
      case Axis.vertical:
        assert(details.controller != null);
        return Scrollbar(controller: details.controller, interactive: interactive, child: child);
    }
  }
}

class NoTransitionPageTransitionsBuilder extends PageTransitionsBuilder {
  /// Constructs a page transition that doesn't animate anything.
  const NoTransitionPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T>? route,
    BuildContext? context,
    Animation<double> animation,
    Animation<double>? secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}
