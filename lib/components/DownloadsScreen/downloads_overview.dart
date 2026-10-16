import 'dart:async';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:file_sizes/file_sizes.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import '../../models/finamp_models.dart';
import '../../services/downloads_service.dart';
import '../global_snackbar.dart';

const double downloadsOverviewCardLoadingHeight = 120;

class DownloadsOverview extends ConsumerStatefulWidget {
  const DownloadsOverview({super.key});

  @override
  ConsumerState<DownloadsOverview> createState() => _DownloadsOverviewState();
}

class _DownloadsOverviewState extends ConsumerState<DownloadsOverview> {
  final _downloadsService = GetIt.instance<DownloadsService>();

  Timer? _timer;
  int? _storageUsed;

  @override
  void initState() {
    super.initState();
    _refresh();
    // This is refreshed once every 4 seconds by the timer below.
    _timer = Timer.periodic(const Duration(seconds: 4), (_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Called once on entry: kick the queues and populate the initial view.
  Future<void> _refresh() async {
    _downloadsService.updateDownloadCounts();
    // Attempt to resume syncing/downloading when the downloads screen is shown.
    _downloadsService.restartDownloads();
    await _refreshStorageUsed();
  }

  /// Called every 4 seconds: refresh the live counts + storage used.
  Future<void> _tick() async {
    _downloadsService.updateDownloadCounts();
    await _refreshStorageUsed();
  }

  Future<void> _refreshStorageUsed() async {
    final used = await _downloadsService.getStorageUsed();
    if (mounted && used != _storageUsed) {
      setState(() => _storageUsed = used);
    }
  }

  @override
  Widget build(BuildContext context) {
    // This is refreshed once every 4 seconds by the timer above.
    return StreamBuilder<Map<String, int>>(
      stream: _downloadsService.downloadCountsStream,
      initialData: _downloadsService.downloadCounts,
      builder: (context, countSnapshot) {
        // This is throttled to 10 per second in downloadsService constructor.
        return StreamBuilder<Map<DownloadItemState, int>>(
          stream: _downloadsService.downloadStatusesStream,
          initialData: _downloadsService.downloadStatuses,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              final counts = snapshot.data!;
              final downloadCount =
                  (counts[DownloadItemState.complete] ?? 0) +
                  (counts[DownloadItemState.needsRedownloadComplete] ?? 0) +
                  (counts[DownloadItemState.needsRedownload] ?? 0) +
                  (counts[DownloadItemState.failed] ?? 0) +
                  (counts[DownloadItemState.enqueued] ?? 0) +
                  (counts[DownloadItemState.downloading] ?? 0) +
                  (counts[DownloadItemState.paused] ?? 0);

              final active = counts[DownloadItemState.downloading] ?? 0;
              final paused = counts[DownloadItemState.paused] ?? 0;
              final failed = (counts[DownloadItemState.failed] ?? 0) + (counts[DownloadItemState.syncFailed] ?? 0);
              final stale =
                  (counts[DownloadItemState.needsRedownload] ?? 0) +
                  (counts[DownloadItemState.needsRedownloadComplete] ?? 0);

              final l10n = AppLocalizations.of(context)!;

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AutoSizeText(
                                  l10n.downloadCount(downloadCount),
                                  style: const TextStyle(fontSize: 28),
                                  maxLines: 1,
                                ),
                                Text(
                                  l10n.downloadedCountUnified(
                                    countSnapshot.data?["track"] ?? -1,
                                    countSnapshot.data?["image"] ?? -1,
                                    countSnapshot.data?["sync"] ?? -1,
                                    countSnapshot.data?[repairStepTrackingName] ?? 0,
                                  ),
                                  style: const TextStyle(color: Colors.grey),
                                ),
                                if (_downloadsService.serverMissingBlurhash)
                                  Text(l10n.missingBlurhashWarning, style: const TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 50),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  l10n.dlComplete(
                                    (counts[DownloadItemState.complete] ?? -1) +
                                        (counts[DownloadItemState.needsRedownloadComplete] ?? -1),
                                  ),
                                  style: const TextStyle(color: Colors.blue),
                                ),
                                Text(l10n.dlFailed(failed), style: const TextStyle(color: Colors.red)),
                                Text(
                                  l10n.dlEnqueued(counts[DownloadItemState.enqueued] ?? -1),
                                  style: const TextStyle(color: Colors.grey),
                                ),
                                Text(
                                  l10n.dlRunning(counts[DownloadItemState.downloading] ?? -1),
                                  style: const TextStyle(color: Colors.grey),
                                ),
                                Text(l10n.dlPaused(paused), style: const TextStyle(color: Colors.orange)),
                                Text(l10n.dlStale(stale), style: const TextStyle(color: Colors.orange)),
                                if (_storageUsed != null)
                                  Text(
                                    l10n.storageUsed(FileSize.getSize(_storageUsed!)),
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      // P0.2 step 7: global download controls wired to the state
                      // machine.  Each is enabled only when there is something to
                      // act on.  Transfer rate / remaining storage are documented
                      // gaps (API returns null), so they are intentionally omitted.
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        alignment: WrapAlignment.start,
                        children: [
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            tooltip: l10n.pauseAllDownloads,
                            icon: const Icon(Icons.pause_circle_outline, size: 20),
                            onPressed:
                                active > 0
                                    ? () {
                                      _downloadsService.pauseAllDownloads();
                                      GlobalSnackbar.message(
                                        (scaffold) => AppLocalizations.of(scaffold)!.pauseAllDownloads,
                                      );
                                    }
                                    : null,
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            tooltip: l10n.resumeAllDownloads,
                            icon: const Icon(Icons.play_circle_outline, size: 20),
                            onPressed:
                                paused > 0
                                    ? () {
                                      _downloadsService.resumeAllDownloads();
                                      GlobalSnackbar.message(
                                        (scaffold) => AppLocalizations.of(scaffold)!.resumeAllDownloads,
                                      );
                                    }
                                    : null,
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            tooltip: l10n.retryFailedDownloads,
                            icon: const Icon(Icons.refresh, size: 20),
                            onPressed:
                                failed > 0
                                    ? () {
                                      _downloadsService.retryFailedDownloads();
                                      GlobalSnackbar.message(
                                        (scaffold) => AppLocalizations.of(scaffold)!.retryFailedDownloads,
                                      );
                                    }
                                    : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            } else if (snapshot.hasError) {
              GlobalSnackbar.error(snapshot.error);
              return const SizedBox(height: downloadsOverviewCardLoadingHeight, child: Card(child: Icon(Icons.error)));
            } else {
              return const SizedBox(
                height: downloadsOverviewCardLoadingHeight,
                child: Card(child: Center(child: CircularProgressIndicator.adaptive())),
              );
            }
          },
        );
      },
    );
  }
}
