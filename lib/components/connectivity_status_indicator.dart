import 'package:finamp/color_schemes.g.dart';
import 'package:finamp/components/PlayerScreen/player_split_screen_scaffold.dart';
import 'package:finamp/services/connectivity_state.dart';
import 'package:finamp/theme/jellyamp_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

/// P0.3 step 7 - the ONE subtle global connectivity indicator.
///
/// Per the roadmap UX rule we must NOT flood ordinary screens with network
/// error dialogs, broken artwork placeholders, retry popups, or full-screen
/// errors. Instead there is a single, small, non-interactive status pill that
/// appears at the top of the app only when we are not online:
///
///   * DEGRADED -> "DEGRADED - Server unreliable"
///   * OFFLINE  -> "OFFLINE - Showing downloaded library"
///   * ONLINE   -> nothing is rendered.
///
/// It uses the frozen JellyAmp design system (ice #7DD3FC, charcoal #0B0F14,
/// platinum/highlight #E0F2FE; see color_schemes.g.dart + jellyamp_theme.dart)
/// and is wrapped in [IgnorePointer] so it never blocks interaction.
class ConnectivityStatusIndicator extends ConsumerWidget {
  const ConnectivityStatusIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(connectivityStateProvider);
    if (state == ConnectivityState.online) {
      return const SizedBox.shrink();
    }

    final (IconData icon, String label) = switch (state) {
      ConnectivityState.degraded => (Icons.cloud_queue, "DEGRADED - Server unreliable"),
      ConnectivityState.offline => (TablerIcons.cloud_off, "OFFLINE - Showing downloaded library"),
      ConnectivityState.online => (Icons.cloud_done, ""),
    };

    return IgnorePointer(
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: jSpaceMd, vertical: jSpaceXs),
          decoration: BoxDecoration(
            color: iceBgColor.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(jRadiusArtwork),
            border: Border.all(color: icePrimaryColor.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: icePrimaryColor),
              const SizedBox(width: jSpaceSm),
              Text(label, style: const TextStyle(color: iceHighlightColor, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

/// MaterialApp.builder hook that stacks the global connectivity indicator over
/// the existing app shell ([buildPlayerSplitScreenScaffold]). Additive: it only
/// wraps the current builder and layers the indicator on top; it does not
/// change the shell's behavior.
Widget buildAppWithConnectivityIndicator(BuildContext context, Widget? widget) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Stack(
      children: [
        buildPlayerSplitScreenScaffold(context, widget),
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(bottom: false, minimum: EdgeInsets.only(top: jSpaceSm), child: ConnectivityStatusIndicator()),
        ),
      ],
    ),
  );
}
