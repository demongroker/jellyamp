import 'package:finamp/components/AlbumScreen/download_dialog.dart';
import 'package:finamp/components/MusicScreen/view_list_tile.dart';
import 'package:finamp/components/PlayerScreen/player_split_screen_scaffold.dart';
import 'package:finamp/components/confirmation_prompt_dialog.dart';
import 'package:finamp/components/finamp_icon.dart';
import 'package:finamp/components/now_playing_bar.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/screens/downloads_screen.dart';
import 'package:finamp/screens/logs_screen.dart';
import 'package:finamp/screens/playback_history_screen.dart';
import 'package:finamp/screens/queue_restore_screen.dart';
import 'package:finamp/screens/settings_screen.dart';
import 'package:finamp/services/finamp_user_helper.dart';
import 'package:finamp/services/queue_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:get_it/get_it.dart';

/// Slim, always-visible left navigation rail that replaces the full-width
/// navigation drawer on the Music screen.
///
/// Uses the Material 3 `NavigationRail` pattern: the active Jellyfin library
/// is the selected destination, while Downloads / Playback History / Queues /
/// Logs / Settings are exposed as rail actions. It inherits the active
/// ember (Android) or ice (iOS/macOS) color scheme from the surrounding theme.
class FinampNavigationRail extends ConsumerWidget {
  const FinampNavigationRail({super.key});

  /// Extra space reserved above the bottom of the rail so the trailing action
  /// column never hides behind the NowPlayingBar during playback.
  ///
  /// The NowPlayingBar is ~`albumImageSize` tall plus its 10px bottom padding
  /// (the Scaffold's `bottomNavigationBar`), and we add the rail's own 12px
  /// breathing room on top of that. The bar is only shown while something is
  /// playing, so this padding is applied conditionally to avoid a gap when idle.
  static const _nowPlayingBarExtraBottomPadding = NowPlayingBar.albumImageSize + 10.0;

  void _push(BuildContext context, String routeName) {
    Navigator.of(context).pushNamed(routeName);
  }

  /// Triggers a whole-library download for [view], mirroring the per-library
  /// `DownloadButton(isLibrary: true)` affordance that used to live on the
  /// navigation drawer (the `ViewListTile`). Exposed on the rail via a
  /// long-press on a library destination.
  Future<void> _downloadLibrary(BuildContext context, BaseItemDto view) async {
    final item = DownloadStub.fromItem(item: view, type: DownloadItemType.collection);
    final viewId = BaseItemId(item.id);
    await showDialog<void>(
      context: context,
      builder:
          (context) => ConfirmationPromptDialog(
            promptText: AppLocalizations.of(context)!.downloadLibraryPrompt(item.name),
            confirmButtonText: AppLocalizations.of(context)!.addButtonLabel,
            onConfirmed: () => DownloadDialog.show(context, item, viewId),
          ),
    );
  }

  Widget _railAction({
    required BuildContext context,
    required IconData icon,
    required String tooltip,
    required String routeName,
  }) {
    return IconButton(icon: Icon(icon), tooltip: tooltip, onPressed: () => _push(context, routeName));
  }

  Widget _actionColumn(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _railAction(
          context: context,
          icon: Icons.file_download_outlined,
          tooltip: l10n.downloads,
          routeName: DownloadsScreen.routeName,
        ),
        _railAction(
          context: context,
          icon: TablerIcons.clock,
          tooltip: l10n.playbackHistory,
          routeName: PlaybackHistoryScreen.routeName,
        ),
        _railAction(
          context: context,
          icon: Icons.auto_delete_outlined,
          tooltip: l10n.queuesScreen,
          routeName: QueueRestoreScreen.routeName,
        ),
        const Divider(height: 16),
        _railAction(
          context: context,
          icon: Icons.bug_report_outlined,
          tooltip: l10n.logs,
          routeName: LogsScreen.routeName,
        ),
        _railAction(
          context: context,
          icon: Icons.settings_outlined,
          tooltip: l10n.settings,
          routeName: SettingsScreen.routeName,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final finampUserHelper = GetIt.instance<FinampUserHelper>();
    final colorScheme = ColorScheme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final views = finampUserHelper.currentUser?.views.values ?? const <BaseItemDto>[];
    final currentViewId = ref.watch(FinampUserHelper.finampCurrentUserProvider.select((value) => value?.currentViewId));

    final activeLibraryIndex = views.toList().indexWhere((view) => view.id == currentViewId);

    // The NowPlayingBar is only rendered while a track is queued/playing (and
    // not in split-screen), matching how `NowPlayingBar.build` decides to show
    // itself. Only then do we reserve room for it at the bottom of the rail so
    // the Logs / Settings actions stay visible and tappable.
    final queueInfo = ref.watch(QueueService.queueProvider);
    final nowPlayingBarVisible = queueInfo?.currentTrack != null && !usingPlayerSplitScreen;
    final bottomPadding = 12.0 + (nowPlayingBarVisible ? _nowPlayingBarExtraBottomPadding : 0.0);

    // The rail is a fixed/narrow left column. Wrapping it in a fixed-width
    // SizedBox keeps the width bounded even though the parent Row lays its
    // non-flex children out with unbounded width; without it the rail could
    // feed an unbounded/negative constraint into the NavigationRail layout
    // (previously producing a ~99,615px right overflow and "negative minimum
    // width" errors) and starving the Expanded content next to it.
    return SizedBox(
      width: 72,
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border(right: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.25))),
        ),
        child: SafeArea(
          child:
              views.isEmpty
                  ? Column(
                    children: [
                      // No libraries configured yet, so there is nothing for the
                      // brand logo to navigate to - it is deliberately left
                      // non-interactive (plain Center, no tap affordance) rather
                      // than rendered as a dead button.
                      const Padding(
                        padding: EdgeInsets.only(top: 16.0, bottom: 16.0),
                        child: Center(child: FinampIcon(36, 36)),
                      ),
                      _actionColumn(context),
                    ],
                  )
                  : NavigationRail(
                    backgroundColor: Colors.transparent,
                    extended: false,
                    minWidth: 68,
                    labelType: NavigationRailLabelType.none,
                    selectedIndex: activeLibraryIndex < 0 ? 0 : activeLibraryIndex,
                    indicatorColor: colorScheme.primaryContainer.withValues(alpha: 0.45),
                    groupAlignment: -0.45,
                    // Pin the action column to the bottom of the rail (above the
                    // NowPlayingBar) as its own rail segment, instead of wrapping
                    // it in Expanded inside `trailing`. Expanded inside a rail
                    // placed in an unbounded-width Row caused the flex to compute
                    // a huge/negative extent; Flutter's NavigationRail already
                    // handles vertical placement of the trailing segment.
                    trailingAtBottom: true,
                    leading: Padding(
                      padding: const EdgeInsets.only(top: 16.0, bottom: 16.0),
                      // The brand logo doubles as the rail's home affordance.
                      // Tapping it returns the user to their primary library
                      // (the SAME destination the rail's first destination
                      // selects), so it is a real button, not a dead/decorative
                      // logo. No new route/screen is introduced.
                      child: Center(
                        child: IconButton(
                          tooltip: l10n.home,
                          onPressed: () {
                            if (views.isNotEmpty) {
                              finampUserHelper.setCurrentUserCurrentViewId(views.first.id);
                            }
                          },
                          icon: const FinampIcon(36, 36),
                        ),
                      ),
                    ),
                    trailing: Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(padding: EdgeInsets.only(bottom: bottomPadding), child: _actionColumn(context)),
                    ),
                    onDestinationSelected: (index) {
                      finampUserHelper.setCurrentUserCurrentViewId(views.elementAt(index).id);
                    },
                    destinations:
                        views.map((view) {
                          final icon = getViewIcon(view.collectionType);
                          final iconWidget = GestureDetector(
                            // Long-press a library icon to download the whole library
                            // (restores the drawer's per-library DownloadButton).
                            onLongPress: () => _downloadLibrary(context, view),
                            child: Icon(icon),
                          );
                          return NavigationRailDestination(
                            icon: iconWidget,
                            selectedIcon: iconWidget,
                            label: Text(view.name ?? AppLocalizations.of(context)!.unknownName),
                          );
                        }).toList(),
                  ),
        ),
      ),
    );
  }
}
