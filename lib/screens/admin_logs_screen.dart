import 'package:flutter/material.dart';
import '../utils/date_format.dart';
import '../services/admin_service.dart';

/// Read-only history of moderation actions (deletes, bans, admin changes).
class AdminLogsScreen extends StatefulWidget {
  const AdminLogsScreen({super.key});

  @override
  State<AdminLogsScreen> createState() => _AdminLogsScreenState();
}

class _AdminLogsScreenState extends State<AdminLogsScreen> {
  late Future<List<Map<String, dynamic>>> _logs = AdminService.instance.getRecentLogs();

  static const _actions = {
    'delete_rating': (Icons.star_outline, 'Deleted a review'),
    'delete_comment': (Icons.comment_outlined, 'Deleted a comment'),
    'delete_forum_post': (Icons.forum_outlined, 'Deleted a forum post'),
    'ban_user': (Icons.block, 'Banned a user'),
    'unban_user': (Icons.lock_open, 'Unbanned a user'),
    'add_admin': (Icons.person_add_alt, 'Added an admin'),
    'remove_admin': (Icons.person_remove_alt_1, 'Removed an admin'),
  };

  Future<void> _refresh() async {
    setState(() => _logs = AdminService.instance.getRecentLogs());
    await _logs;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('System Logs')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _logs,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Could not load logs: ${snapshot.error}'));
          }
          final logs = snapshot.data ?? [];
          if (logs.isEmpty) {
            return Center(
              child: Text(
                'No moderation actions yet',
                style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              itemCount: logs.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final log = logs[index];
                final (icon, label) = _actions[log['action']] ?? (Icons.history, log['action'] ?? 'Action');
                final details = log['details'] as String?;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                    child: Icon(icon, color: theme.colorScheme.primary, size: 20),
                  ),
                  title: Text(label),
                  subtitle: Text(
                    [
                      'by ${log['adminName'] ?? 'admin'} · ${_formatDate(log['createdAt'])}',
                      if (details != null && details.isNotEmpty) '"$details"',
                    ].join('\n'),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  isThreeLine: details != null && details.isNotEmpty,
                );
              },
            ),
          );
        },
      ),
    );
  }

  String _formatDate(dynamic millis) {
    if (millis is! int) return '';
    final date = DateTime.fromMillisecondsSinceEpoch(millis);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${formatShortDate(date)} ${two(date.hour)}:${two(date.minute)}';
  }
}
