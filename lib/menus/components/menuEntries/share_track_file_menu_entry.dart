import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/menus/components/menuEntries/menu_entry.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/models/jellyfin_models.dart';
import 'package:finamp/services/finamp_settings_helper.dart';
import 'package:finamp/services/media_share_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

/// Share the original audio file (FLAC/etc.) for a track via the system share sheet.
class ShareTrackFileMenuEntry extends ConsumerWidget implements HideableMenuEntry {
  final BaseItemDto baseItem;

  const ShareTrackFileMenuEntry({super.key, required this.baseItem});

  bool get _isTrack => BaseItemDtoType.fromItem(baseItem) == BaseItemDtoType.track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offline = ref.watch(finampSettingsProvider.isOffline);

    return Visibility(
      // Allow offline if a local download exists — helper handles failure.
      visible: _isTrack,
      child: MenuEntry(
        icon: TablerIcons.file_music,
        title: AppLocalizations.of(context)!.shareAudioFile,
        tooltip:
            offline
                ? AppLocalizations.of(context)!.shareAudioFileTooltipOffline
                : AppLocalizations.of(context)!.shareAudioFileTooltip,
        onTap: () async {
          Navigator.pop(context);
          await MediaShareHelper.shareOriginalAudioFile(baseItem);
        },
      ),
    );
  }

  @override
  bool get isVisible => _isTrack;
}
