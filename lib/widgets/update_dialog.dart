import 'dart:io';
import 'package:flutter/material.dart';
import '../services/update_service.dart';
import '../utils/date_format.dart';

enum _Phase { offer, downloading, installing, failed }

/// "A new version is available" popup. Downloads the APK in place with a
/// progress bar, then hands it to Android's installer.
class UpdateAvailableDialog extends StatefulWidget {
  final UpdateInfo info;
  final String currentVersion;

  const UpdateAvailableDialog({super.key, required this.info, required this.currentVersion});

  @override
  State<UpdateAvailableDialog> createState() => _UpdateAvailableDialogState();
}

class _UpdateAvailableDialogState extends State<UpdateAvailableDialog> {
  _Phase _phase = _Phase.offer;
  double? _progress;
  int _received = 0;
  String _error = '';
  bool _cancelled = false;
  File? _apk;

  UpdateInfo get _info => widget.info;

  Future<void> _download() async {
    if (_info.downloadUrl.isEmpty || !Platform.isAndroid) {
      await UpdateService.instance.openInBrowser(_info.releasePageUrl);
      if (mounted) Navigator.pop(context);
      return;
    }
    setState(() {
      _phase = _Phase.downloading;
      _progress = 0;
      _received = 0;
      _cancelled = false;
    });
    try {
      _apk = await UpdateService.instance.downloadUpdate(
        _info,
        isCancelled: () => _cancelled,
        onProgress: (progress, received) {
          if (mounted) {
            setState(() {
              _progress = progress;
              _received = received;
            });
          }
        },
      );
      await _install();
    } catch (e) {
      if (!mounted) return;
      if (isDownloadCancelled(e)) {
        setState(() => _phase = _Phase.offer);
      } else {
        setState(() {
          _phase = _Phase.failed;
          _error = 'The download didn\'t finish. Check your connection and try again.';
        });
      }
    }
  }

  Future<void> _install() async {
    final apk = _apk;
    if (apk == null) return;
    setState(() => _phase = _Phase.installing);
    try {
      final started = await UpdateService.instance.installApk(apk);
      if (!mounted) return;
      if (!started) {
        setState(() {
          _phase = _Phase.failed;
          _error = 'Allow GameLog to install apps when Android asks, then tap Install again.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.failed;
        _error = 'Android couldn\'t open the installer. You can download the update in your browser instead.';
      });
    }
  }

  String _mb(int bytes) => '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';

  /// Release notes come from GitHub as markdown; show them as plain text.
  String get _notes {
    final lines = _info.releaseNotes
        .split('\n')
        .map((l) => l.trimRight())
        .where((l) => !l.trim().startsWith('<!--'))
        .map((l) => l
            .replaceFirst(RegExp(r'^#+\s*'), '')
            .replaceFirst(RegExp(r'^\s*[-*]\s+'), '• ')
            .replaceAll('**', '')
            .replaceAll('`', ''))
        .toList();
    return lines.join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final busy = _phase == _Phase.downloading;

    return PopScope(
      canPop: !busy,
      child: AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
        title: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.system_update_rounded, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Update available',
                      style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(
                    widget.currentVersion.isEmpty
                        ? 'Version ${_info.version}'
                        : '${widget.currentVersion}  →  ${_info.version}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                [
                  'Released ${formatShortDate(_info.releaseDate)}',
                  if (_info.downloadSize > 0) _mb(_info.downloadSize),
                ].join(' · '),
                style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
              ),
              if (_notes.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text("What's new", style: TextStyle(fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface)),
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 220),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      _notes,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                ),
              ],
              if (_phase == _Phase.downloading || _phase == _Phase.installing) ...[
                const SizedBox(height: 18),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: _phase == _Phase.installing ? 1 : _progress,
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _phase == _Phase.installing
                      ? 'Opening the installer…'
                      : _progress != null
                          ? 'Downloading… ${(_progress! * 100).round()}% · ${_mb(_received)}'
                              '${_info.downloadSize > 0 ? ' of ${_mb(_info.downloadSize)}' : ''}'
                          : 'Downloading… ${_mb(_received)}',
                  style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                ),
              ],
              if (_phase == _Phase.failed) ...[
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.error_outline, size: 18, color: theme.colorScheme.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_error, style: TextStyle(fontSize: 13, color: theme.colorScheme.error)),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        actions: _actions(),
      ),
    );
  }

  List<Widget> _actions() {
    switch (_phase) {
      case _Phase.offer:
        return [
          TextButton(
            onPressed: () async {
              await UpdateService.instance.skipVersion(_info.version);
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Skip version'),
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Later')),
          FilledButton.icon(
            onPressed: _download,
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text('Download'),
          ),
        ];
      case _Phase.downloading:
        return [
          TextButton(
            onPressed: () => setState(() => _cancelled = true),
            child: const Text('Cancel'),
          ),
        ];
      case _Phase.installing:
        return [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          FilledButton(onPressed: _install, child: const Text('Install')),
        ];
      case _Phase.failed:
        return [
          TextButton(
            onPressed: () {
              UpdateService.instance.openInBrowser(
                  _info.downloadUrl.isNotEmpty ? _info.downloadUrl : _info.releasePageUrl);
              Navigator.pop(context);
            },
            child: const Text('Use browser'),
          ),
          FilledButton(
            onPressed: _apk != null ? _install : _download,
            child: Text(_apk != null ? 'Install' : 'Try again'),
          ),
        ];
    }
  }
}
