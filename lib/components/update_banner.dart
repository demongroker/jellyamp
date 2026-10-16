import 'dart:async';
import 'dart:io';

import 'package:finamp/services/update_checker.dart';
import 'package:finamp/services/update_checker_provider.dart';
import 'package:finamp/services/update_installer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

/// Subtle, non-intrusive update banner with in-app download + install.
class UpdateBanner extends ConsumerStatefulWidget {
  const UpdateBanner({super.key});

  @override
  ConsumerState<UpdateBanner> createState() => _UpdateBannerState();
}

enum _UpdateStatus { idle, downloading, installing }

class _UpdateBannerState extends ConsumerState<UpdateBanner> {
  bool _dismissed = false;
  _UpdateStatus _status = _UpdateStatus.idle;
  double _progress = 0;
  String? _message;

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    final updateAsync = ref.watch(updateCheckerProvider);

    return updateAsync.when(
      data: (update) {
        if (update == null) return const SizedBox.shrink();

        return Container(
          color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.system_update_alt, size: 18),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Jellyamp ${update.latestVersion} is available',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        if (update.note != null)
                          Text(
                            update.note!,
                            style: Theme.of(context).textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  _buildAction(update),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setState(() => _dismissed = true),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              if (_status == _UpdateStatus.downloading) ...[
                const SizedBox(height: 8),
                ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: _progress)),
                const SizedBox(height: 4),
                Text(
                  'Downloading… ${(_progress * 100).toStringAsFixed(0)}%',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (_message != null) ...[
                const SizedBox(height: 4),
                Text(_message!, style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildAction(UpdateInfo update) {
    switch (_status) {
      case _UpdateStatus.downloading:
        return const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
        );
      case _UpdateStatus.installing:
        return const TextButton(onPressed: null, child: Text('Installing…'));
      case _UpdateStatus.idle:
        return TextButton(onPressed: () => _downloadAndInstall(update), child: const Text('Update'));
    }
  }

  Future<void> _downloadAndInstall(UpdateInfo update) async {
    final downloadUrl = update.downloadUrl;
    if (downloadUrl == null) {
      // No APK asset exposed — fall back to the release page in the browser.
      await launchUrl(Uri.parse(update.htmlUrl));
      return;
    }

    try {
      final canInstall = await UpdateInstaller.canInstallPackages();
      if (!mounted) return;
      if (!canInstall) {
        final open = await showDialog<bool>(
          context: context,
          builder:
              (ctx) => AlertDialog(
                title: const Text('Allow installs'),
                content: const Text(
                  'To update Jellyamp in-app, allow installing apps from this source, then tap Update again.',
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Open settings')),
                ],
              ),
        );
        if (open ?? false) {
          await UpdateInstaller.openInstallPermissionSettings();
          if (mounted) {
            setState(() => _message = 'Allow installs, then tap Update again.');
          }
        }
        return;
      }

      setState(() {
        _status = _UpdateStatus.downloading;
        _progress = 0;
        _message = null;
      });

      final file = await UpdateInstaller.downloadApk(
        downloadUrl,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );

      if (!mounted) return;

      // Verify integrity before install (SHA-256 published with the release).
      if (update.sha256 != null) {
        setState(() => _message = 'Verifying package…');
        final ok = await UpdateInstaller.verifySha256(file, update.sha256!);
        if (!mounted) return;
        if (!ok) {
          setState(() {
            _status = _UpdateStatus.idle;
            _message = 'Update verification failed — the download does not match the release. Tap Update to retry.';
          });
          return;
        }
      }

      setState(() {
        _status = _UpdateStatus.installing;
        _message = null;
      });

      await UpdateInstaller.installApk(file.path);

      if (mounted) {
        setState(() {
          _status = _UpdateStatus.idle;
          _message = 'Install prompt shown — finish it to update.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = _UpdateStatus.idle;
          _message = _friendlyUpdateError(e);
        });
      }
    }
  }

  /// Maps low-level update exceptions to human-readable messages.
  String _friendlyUpdateError(Object e) {
    if (e is SocketException || e is TimeoutException || e is http.ClientException) {
      return 'Couldn\'t download the update. Check your connection and try again.';
    }
    return 'Update failed. Check your connection and try again, or open the release page.';
  }
}
