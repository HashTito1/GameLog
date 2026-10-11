import 'package:flutter/material.dart';
import '../services/admin_service.dart';
import '../services/report_service.dart';

class AdminContentModerationScreen extends StatefulWidget {
  /// Which tab to open first: 'ratings', 'comments' or 'reports'.
  final String initialTab;

  const AdminContentModerationScreen({super.key, this.initialTab = 'ratings'});

  @override
  State<AdminContentModerationScreen> createState() => _AdminContentModerationScreenState();
}

class _AdminContentModerationScreenState extends State<AdminContentModerationScreen> {
  bool _isLoading = true;
  String? _error;
  late String _selectedTab = widget.initialTab; // ratings, comments, reports
  List<Map<String, dynamic>> _items = [];
  Set<String> _reportedIds = {};

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      List<Map<String, dynamic>> items;
      Set<String> reportedIds = {};
      switch (_selectedTab) {
        case 'comments':
          items = await AdminService.instance.getRecentComments();
          reportedIds = await ReportService.getReportedTargetIds(ReportType.comment);
          break;
        case 'reports':
          items = await ReportService.getOpenReports();
          break;
        default:
          items = await AdminService.instance.getRecentRatings();
          reportedIds = await ReportService.getReportedTargetIds(ReportType.rating);
      }

      // Reported content first so it gets looked at.
      items.sort((a, b) {
        final aReported = reportedIds.contains(a['id']) ? 0 : 1;
        final bReported = reportedIds.contains(b['id']) ? 0 : 1;
        return aReported.compareTo(bReported);
      });

      if (mounted) {
        setState(() {
          _items = items;
          _reportedIds = reportedIds;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Could not load content: $e';
        });
      }
    }
  }

  Future<bool> _confirm(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _runAction(Future<void> Function() action, String successMessage) async {
    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(successMessage)));
      }
      await _loadContent();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Action failed: $e'), backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    }
  }

  Future<void> _deleteRating(Map<String, dynamic> rating) async {
    if (!await _confirm('Delete review?', 'This removes the rating and review for everyone.')) return;
    await _runAction(() async {
      await AdminService.instance.deleteGameRating(rating['id']);
      await ReportService.closeReportsForTarget(rating['id']);
    }, 'Review deleted');
  }

  Future<void> _deleteComment(Map<String, dynamic> comment) async {
    if (!await _confirm('Delete comment?', 'This removes the comment for everyone.')) return;
    await _runAction(() async {
      await AdminService.instance.deleteRatingComment(comment['id']);
      await ReportService.closeReportsForTarget(comment['id']);
    }, 'Comment deleted');
  }

  Future<void> _deleteReportedContent(Map<String, dynamic> report) async {
    final targetId = report['targetId'] as String?;
    if (targetId == null) return;
    if (!await _confirm('Delete reported content?', 'This removes the reported item for everyone.')) return;
    await _runAction(() async {
      switch (report['type']) {
        case ReportType.rating:
          await AdminService.instance.deleteGameRating(targetId);
          break;
        case ReportType.comment:
          await AdminService.instance.deleteRatingComment(targetId);
          break;
        case ReportType.forumPost:
          await AdminService.instance.deleteForumPost(targetId);
          break;
      }
      await ReportService.closeReportsForTarget(targetId);
    }, 'Content deleted and report resolved');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Content Moderation',
          style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold),
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loadContent,
            icon: Icon(Icons.refresh, color: theme.colorScheme.onSurface),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'ratings', label: Text('Reviews'), icon: Icon(Icons.star_outline)),
                ButtonSegment(value: 'comments', label: Text('Comments'), icon: Icon(Icons.comment_outlined)),
                ButtonSegment(value: 'reports', label: Text('Reports'), icon: Icon(Icons.flag_outlined)),
              ],
              selected: {_selectedTab},
              onSelectionChanged: (selection) {
                setState(() => _selectedTab = selection.first);
                _loadContent();
              },
            ),
          ),
          Expanded(child: _buildBody(theme)),
        ],
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return _buildMessage(theme, Icons.error_outline, 'Something went wrong', _error!);
    }
    if (_items.isEmpty) {
      return switch (_selectedTab) {
        'reports' => _buildMessage(theme, Icons.verified_outlined, 'No open reports', 'Nothing needs attention right now.'),
        'comments' => _buildMessage(theme, Icons.comment_outlined, 'No comments yet', 'New comments on reviews show up here.'),
        _ => _buildMessage(theme, Icons.star_outline, 'No reviews yet', 'New reviews show up here.'),
      };
    }

    return RefreshIndicator(
      onRefresh: _loadContent,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final item = _items[index];
          return switch (_selectedTab) {
            'reports' => _buildReportCard(theme, item),
            'comments' => _buildContentCard(
                theme,
                author: item['authorDisplayName'] ?? item['authorUsername'] ?? 'Unknown',
                subtitle: 'Comment',
                body: item['content'] ?? '',
                createdAt: item['createdAt'],
                isReported: _reportedIds.contains(item['id']),
                onDelete: () => _deleteComment(item),
              ),
            _ => _buildContentCard(
                theme,
                author: item['displayName'] ?? item['username'] ?? 'Unknown',
                subtitle: '${item['gameTitle'] ?? 'Game ${item['gameId']}'} · ${(item['rating'] ?? 0).toString()}★',
                body: (item['review'] as String?)?.isNotEmpty == true ? item['review'] : 'No written review',
                createdAt: item['updatedAt'],
                isReported: _reportedIds.contains(item['id']),
                onDelete: () => _deleteRating(item),
              ),
          };
        },
      ),
    );
  }

  Widget _buildContentCard(
    ThemeData theme, {
    required String author,
    required String subtitle,
    required String body,
    required dynamic createdAt,
    required bool isReported,
    required VoidCallback onDelete,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isReported ? theme.colorScheme.error : theme.colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(author,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (isReported) ...[
                        const SizedBox(width: 8),
                        _buildChip(theme, 'Reported', theme.colorScheme.error),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$subtitle · ${_formatDate(createdAt)}',
                    style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                  ),
                  const SizedBox(height: 8),
                  Text(body, maxLines: 4, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            IconButton(
              onPressed: onDelete,
              icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
              tooltip: 'Delete',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard(ThemeData theme, Map<String, dynamic> report) {
    final type = report['type'] as String? ?? '';
    final isBug = type == ReportType.bug;
    final typeLabel = switch (type) {
      ReportType.rating => 'Review',
      ReportType.comment => 'Comment',
      ReportType.forumPost => 'Forum post',
      ReportType.bug => 'Bug report',
      _ => type,
    };

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildChip(theme, typeLabel, isBug ? theme.colorScheme.tertiary : theme.colorScheme.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isBug ? 'From ${report['reporterName'] ?? 'a user'}' : report['reason'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  _formatDate(report['createdAt']),
                  style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                ),
              ],
            ),
            if (report['targetPreview'] != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('"${report['targetPreview']}"', maxLines: 4, overflow: TextOverflow.ellipsis),
              ),
            ],
            if (report['details'] != null) ...[
              const SizedBox(height: 8),
              Text(report['details'], maxLines: isBug ? 12 : 4, overflow: TextOverflow.ellipsis),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _runAction(
                    () => ReportService.closeReport(report['id'], isBug ? 'resolved' : 'dismissed'),
                    isBug ? 'Marked as handled' : 'Report dismissed',
                  ),
                  child: Text(isBug ? 'Mark handled' : 'Dismiss'),
                ),
                if (!isBug && report['targetId'] != null)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.error),
                    onPressed: () => _deleteReportedContent(report),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Delete content'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(ThemeData theme, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }

  Widget _buildMessage(ThemeData theme, IconData icon, String title, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(dynamic millis) {
    if (millis is! int) return '';
    final date = DateTime.fromMillisecondsSinceEpoch(millis);
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}
