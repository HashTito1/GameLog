import 'package:flutter/material.dart';
import '../services/report_service.dart';

/// Ask the user why they're reporting something, then file the report.
/// Shows a confirmation snackbar on success.
Future<void> showReportDialog(
  BuildContext context, {
  required String type,
  required String targetId,
  String? targetOwnerId,
  String? targetPreview,
  String title = 'Report content',
}) async {
  final submitted = await showDialog<bool>(
    context: context,
    builder: (context) => _ReportDialog(
      title: title,
      onSubmit: (reason, details) => ReportService.submitReport(
        type: type,
        reason: reason,
        details: details,
        targetId: targetId,
        targetOwnerId: targetOwnerId,
        targetPreview: targetPreview,
      ),
    ),
  );

  if (submitted == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Thanks. Our moderators will take a look.')),
    );
  }
}

/// Free-text bug report sent to the admin reports queue.
Future<void> showBugReportDialog(BuildContext context) async {
  final submitted = await showDialog<bool>(
    context: context,
    builder: (context) => _ReportDialog(
      title: 'Report a bug',
      requireDetails: true,
      detailsHint: 'What happened, and what did you expect to happen?',
      onSubmit: (_, details) => ReportService.submitReport(
        type: ReportType.bug,
        reason: 'Bug report',
        details: details,
      ),
    ),
  );

  if (submitted == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Thanks for the report. It helps a lot.')),
    );
  }
}

class _ReportDialog extends StatefulWidget {
  final String title;
  final bool requireDetails;
  final String detailsHint;
  final Future<void> Function(String reason, String? details) onSubmit;

  const _ReportDialog({
    required this.title,
    required this.onSubmit,
    this.requireDetails = false,
    this.detailsHint = 'Add details (optional)',
  });

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  final _detailsController = TextEditingController();
  String? _reason;
  bool _isSubmitting = false;
  String? _error;

  bool get _canSubmit {
    if (_isSubmitting) return false;
    if (widget.requireDetails) return _detailsController.text.trim().length >= 10;
    return _reason != null;
  }

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      final details = _detailsController.text.trim();
      await widget.onSubmit(_reason ?? '', details.isEmpty ? null : details);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _error = 'Could not send the report. Check your connection and try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(widget.title, style: TextStyle(color: theme.colorScheme.onSurface)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!widget.requireDetails) ...[
              Text(
                'Why are you reporting this?',
                style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: 8),
              RadioGroup<String>(
                groupValue: _reason,
                onChanged: (value) => setState(() => _reason = value),
                child: Column(
                  children: ReportService.contentReasons
                      .map((reason) => RadioListTile<String>(
                            value: reason,
                            title: Text(reason, style: TextStyle(color: theme.colorScheme.onSurface)),
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 8),
            ],
            TextField(
              controller: _detailsController,
              maxLines: widget.requireDetails ? 6 : 3,
              maxLength: 2000,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: widget.detailsHint,
                border: const OutlineInputBorder(),
              ),
            ),
            if (_error != null)
              Text(_error!, style: TextStyle(color: theme.colorScheme.error, fontSize: 12)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _canSubmit ? _submit : null,
          child: _isSubmitting
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Send'),
        ),
      ],
    );
  }
}
