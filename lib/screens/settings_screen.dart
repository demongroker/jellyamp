import 'dart:io';

import 'package:finamp/components/MusicScreen/offline_mode_switch_list_tile.dart';
import 'package:finamp/components/SettingsScreen/logout_list_tile.dart';
import 'package:finamp/components/finamp_app_bar_back_button.dart';
import 'package:finamp/components/finamp_icon.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/menus/client_certificate_authentication_menu.dart';
import 'package:finamp/menus/quick_connect_authorization_menu.dart';
import 'package:finamp/menus/server_sharing_menu.dart';
import 'package:finamp/screens/accessibility_settings_screen.dart';
import 'package:finamp/screens/audio_service_settings_screen.dart';
import 'package:finamp/screens/downloads_settings_screen.dart';
import 'package:finamp/screens/home_screen_settings_screen.dart';
import 'package:finamp/screens/interaction_settings_screen.dart';
import 'package:finamp/screens/language_selection_screen.dart';
import 'package:finamp/screens/layout_settings_screen.dart';
import 'package:finamp/screens/network_settings_screen.dart';
import 'package:finamp/screens/playback_reporting_settings_screen.dart';
import 'package:finamp/screens/transcoding_settings_screen.dart';
import 'package:finamp/screens/view_selector.dart';
import 'package:finamp/screens/volume_normalization_settings_screen.dart';
import 'package:finamp/services/app_share_helper.dart';
import 'package:finamp/services/client_certificate_installer.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/update_checker.dart';
import 'package:finamp/services/update_checker_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:locale_names/locale_names.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  static const routeName = "/settings";

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  static const repoLink = "https://github.com/demongroker/jellyamp";
  static const releaseNotesLink = "https://github.com/demongroker/jellyamp/releases";
  static const translationsLink = "https://hosted.weblate.org/projects/finamp";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.settings),
        leading: FinampAppBarBackButton(),
        actions: [
          FinampSettingsHelper.makeSettingsResetButtonWithDialog(
            context,
            FinampSettingsHelper.resetAllSettings,
            isGlobal: true,
          ),
          Semantics.fromProperties(
            properties: SemanticsProperties(label: AppLocalizations.of(context)!.about, button: true),
            excludeSemantics: true,
            container: true,
            child: IconButton(
              icon: const Icon(Icons.info),
              onPressed: () async {
                final localizations = AppLocalizations.of(context)!;
                final applicationLegalese = AppLocalizations.of(context)!.applicationLegalese(repoLink);
                PackageInfo packageInfo = await PackageInfo.fromPlatform();

                ThemeData theme = Theme.of(context);
                const linkStyle = TextStyle(color: Colors.blue, decoration: TextDecoration.underline);

                showAboutDialog(
                  context: context,
                  applicationName: packageInfo.appName,
                  applicationVersion: packageInfo.version,
                  applicationIcon: Padding(padding: const EdgeInsets.only(top: 8.0), child: FinampIcon(56, 56)),
                  applicationLegalese: applicationLegalese,
                  children: [
                    const SizedBox(height: 20),
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: TextStyle(color: theme.textTheme.bodyMedium!.color),
                        children: [
                          TextSpan(
                            text: localizations.finampTagline,
                            style: const TextStyle(fontStyle: FontStyle.italic, fontWeight: FontWeight.w500),
                          ),
                          const TextSpan(text: '\n\n'),
                          TextSpan(text: localizations.aboutContributionPrompt),
                          const TextSpan(text: '\n\n'),
                          TextSpan(text: '${localizations.aboutContributionLink}\n'),
                          TextSpan(
                            text: repoLink,
                            style: linkStyle,
                            recognizer:
                                TapGestureRecognizer()
                                  ..onTap = () async {
                                    await launchUrl(Uri.parse(repoLink));
                                  },
                          ),
                          const TextSpan(text: '\n\n'),
                          TextSpan(text: '${localizations.aboutTranslations}\n'),
                          TextSpan(
                            text: translationsLink,
                            style: linkStyle,
                            recognizer:
                                TapGestureRecognizer()
                                  ..onTap = () async {
                                    await launchUrl(Uri.parse(translationsLink));
                                  },
                          ),
                          const TextSpan(text: '\n\n'),
                          TextSpan(text: '${localizations.aboutReleaseNotes}\n'),
                          TextSpan(
                            text: releaseNotesLink,
                            style: linkStyle,
                            recognizer:
                                TapGestureRecognizer()
                                  ..onTap = () async {
                                    await launchUrl(Uri.parse(releaseNotesLink));
                                  },
                          ),
                          const TextSpan(text: '\n\n\n'),
                          TextSpan(
                            text: localizations.aboutThanks,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 200.0),
        children: [
          const OfflineModeSwitchListTile(),
          const Divider(),
          ListTile(
            leading: const Icon(TablerIcons.home),
            title: Text(AppLocalizations.of(context)!.homeScreenSettingsTitle),
            onTap: () => Navigator.of(context).pushNamed(HomeScreenSettingsScreen.routeName),
          ),
          ListTile(
            leading: const Icon(Icons.compress),
            title: Text(AppLocalizations.of(context)!.transcoding),
            onTap: () => Navigator.of(context).pushNamed(TranscodingSettingsScreen.routeName),
          ),
          ListTile(
            leading: const Icon(Icons.download),
            title: Text(AppLocalizations.of(context)!.downloadSettings),
            onTap: () => Navigator.of(context).pushNamed(DownloadsSettingsScreen.routeName),
          ),
          ListTile(
            leading: const Icon(Icons.wifi),
            title: Text(AppLocalizations.of(context)!.networkSettingsTitle),
            onTap: () => Navigator.of(context).pushNamed(NetworkSettingsScreen.routeName),
          ),
          ListTile(
            leading: const Icon(Icons.music_note),
            title: Text(AppLocalizations.of(context)!.audioService),
            onTap: () => Navigator.of(context).pushNamed(AudioServiceSettingsScreen.routeName),
          ),
          ListTile(
            leading: const Icon(TablerIcons.cast),
            title: Text(AppLocalizations.of(context)!.playbackReportingSettingsTitle),
            onTap: () => Navigator.of(context).pushNamed(PlaybackReportingSettingsScreen.routeName),
          ),
          ListTile(
            leading: const Icon(Icons.equalizer_rounded),
            title: Text(AppLocalizations.of(context)!.volumeNormalizationSettingsTitle),
            onTap: () => Navigator.of(context).pushNamed(VolumeNormalizationSettingsScreen.routeName),
          ),
          ListTile(
            leading: const Icon(Icons.gesture),
            title: Text(AppLocalizations.of(context)!.interactions),
            onTap: () => Navigator.of(context).pushNamed(InteractionSettingsScreen.routeName),
          ),
          ListTile(
            leading: const Icon(Icons.widgets),
            title: Text(AppLocalizations.of(context)!.layoutAndTheme),
            onTap: () => Navigator.of(context).pushNamed(LayoutSettingsScreen.routeName),
          ),
          ListTile(
            leading: const Icon(TablerIcons.accessible),
            title: Text(AppLocalizations.of(context)!.accessibility),
            onTap: () => Navigator.of(context).pushNamed(AccessibilitySettingsScreen.routeName),
          ),
          ListTile(
            leading: const Icon(Icons.library_music),
            title: Text(AppLocalizations.of(context)!.selectMusicLibraries),
            subtitle:
                ref.watch(finampSettingsProvider.isOffline)
                    ? Text(AppLocalizations.of(context)!.notAvailableInOfflineMode)
                    : null,
            enabled: !ref.watch(finampSettingsProvider.isOffline),
            onTap: () => Navigator.of(context).pushNamed(ViewSelector.routeName),
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(AppLocalizations.of(context)!.language),
            subtitle: Text(
              ref.watch(finampSettingsProvider.locale)?.nativeDisplayLanguage ?? AppLocalizations.of(context)!.system,
            ),
            onTap: () => Navigator.of(context).pushNamed(LanguageSelectionScreen.routeName),
          ),
          Divider(),
          if (Platform.isAndroid) ...[
            ListTile(
              leading: const Icon(TablerIcons.share_2),
              title: Text(AppLocalizations.of(context)!.shareApkTitle),
              subtitle: Text(AppLocalizations.of(context)!.shareApkSubtitle),
              onTap: () => AppShareHelper.shareApkFile(),
            ),
            ListTile(
              leading: Icon(AppShareHelper.isServerRunning ? TablerIcons.wifi : TablerIcons.wifi_off),
              title: Text(
                AppShareHelper.isServerRunning
                    ? AppLocalizations.of(context)!.shareApkServerStopTitle
                    : AppLocalizations.of(context)!.shareApkServerStartTitle,
              ),
              subtitle: Text(AppLocalizations.of(context)!.shareApkServerSubtitle),
              onTap: () async {
                if (AppShareHelper.isServerRunning) {
                  await AppShareHelper.stopLocalApkServer();
                  if (context.mounted) setState(() {});
                  return;
                }
                final urls = await AppShareHelper.startLocalApkServer();
                if (context.mounted) setState(() {});
                if (urls != null && context.mounted) {
                  await showDialog<void>(
                    context: context,
                    builder:
                        (ctx) => AlertDialog(
                          title: Text(AppLocalizations.of(ctx)!.shareApkServerDialogTitle),
                          content: SingleChildScrollView(
                            child: SelectableText('${AppLocalizations.of(ctx)!.shareApkServerDialogBody}\n\n$urls'),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () async {
                                await AppShareHelper.copyLocalApkUrls();
                              },
                              child: Text(AppLocalizations.of(ctx)!.shareApkCopyUrls),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: Text(AppLocalizations.of(ctx)!.close),
                            ),
                          ],
                        ),
                  );
                }
              },
            ),
          ],
          ListTile(
            leading: Icon(TablerIcons.access_point),
            title: Text(AppLocalizations.of(context)!.serverSharingMenuButtonTitle),
            onTap: () => showServerSharingPanel(context: context),
          ),
          ListTile(
            leading: Icon(TablerIcons.lock_bolt),
            title: Text(AppLocalizations.of(context)!.quickConnectAuthorizationMenuButtonTitle),
            onTap: () => showQuickConnectAuthorizationMenu(context: context),
          ),
          if (ClientCertificateInstaller.isSupported)
            ListTile(
              leading: Icon(TablerIcons.certificate),
              title: Text(AppLocalizations.of(context)!.clientCertificate),
              subtitle: Text(
                ref.watch(finampSettingsProvider.clientCertificate) != null
                    ? AppLocalizations.of(context)!.clientCertificateInstalled
                    : AppLocalizations.of(context)!.clientCertificateUnavailable,
              ),
              onTap: () => showClientCertificateMenu(context: context),
            ),
          const LogoutListTile(),
        ],
      ),
    );
  }
}

// Simple update checker integration (B)
// Update checker (runs on app startup via provider)
Widget _buildUpdateTile() {
  return Consumer(
    builder: (context, ref, child) {
      final updateAsync = ref.watch(updateCheckerProvider);

      return updateAsync.when(
        data: (update) {
          if (update == null) return const SizedBox.shrink();

          return ListTile(
            leading: const Icon(Icons.system_update, color: Colors.green),
            title: Text('Update available: v${update.latestVersion}'),
            subtitle: const Text('Tap to view release'),
            onTap: () => launchUrl(Uri.parse(update.htmlUrl)),
          );
        },
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
      );
    },
  );
}
