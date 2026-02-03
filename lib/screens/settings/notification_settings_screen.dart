import 'package:flutter/material.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _pushNotifications = true;
  bool _emailNotifications = false;
  bool _friendRequests = true;
  bool _gameUpdates = true;
  bool _socialActivity = false;
  bool _systemUpdates = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Notification Settings', style: TextStyle(color: theme.colorScheme.onSurface)),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildSection(
            title: 'Notification Methods',
            theme: theme,
            children: [
              _buildSwitchTile(
                title: 'Push Notifications',
                subtitle: 'Receive notifications on your device',
                value: _pushNotifications,
                onChanged: (value) => setState(() => _pushNotifications = value),
                theme: theme,
              ),
              _buildSwitchTile(
                title: 'Email Notifications',
                subtitle: 'Receive notifications via email',
                value: _emailNotifications,
                onChanged: (value) => setState(() => _emailNotifications = value),
                theme: theme,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: 'Notification Types',
            theme: theme,
            children: [
              _buildSwitchTile(
                title: 'Friend Requests',
                subtitle: 'When someone sends you a friend request',
                value: _friendRequests,
                onChanged: (value) => setState(() => _friendRequests = value),
                theme: theme,
              ),
              _buildSwitchTile(
                title: 'Game Updates',
                subtitle: 'New releases and updates for games you follow',
                value: _gameUpdates,
                onChanged: (value) => setState(() => _gameUpdates = value),
                theme: theme,
              ),
              _buildSwitchTile(
                title: 'Social Activity',
                subtitle: 'When friends rate games or create playlists',
                value: _socialActivity,
                onChanged: (value) => setState(() => _socialActivity = value),
                theme: theme,
              ),
              _buildSwitchTile(
                title: 'System Updates',
                subtitle: 'App updates and important announcements',
                value: _systemUpdates,
                onChanged: (value) => setState(() => _systemUpdates = value),
                theme: theme,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: 'Notification Settings',
            theme: theme,
            children: [
              _buildActionTile(
                icon: Icons.schedule,
                title: 'Quiet Hours',
                subtitle: 'Set times when notifications are muted',
                onTap: () => _showComingSoonDialog(context, 'Quiet Hours'),
                theme: theme,
              ),
              _buildActionTile(
                icon: Icons.vibration,
                title: 'Sound & Vibration',
                subtitle: 'Customize notification sounds',
                onTap: () => _showComingSoonDialog(context, 'Sound Settings'),
                theme: theme,
              ),
              _buildActionTile(
                icon: Icons.clear_all,
                title: 'Clear All Notifications',
                subtitle: 'Remove all current notifications',
                onTap: () => _showClearNotificationsDialog(context),
                theme: theme,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection({required String title, required List<Widget> children, required ThemeData theme}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              for (int i = 0; i < children.length; i++) ...[
                children[i],
                if (i < children.length - 1)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    height: 0.5,
                    color: theme.colorScheme.outline.withValues(alpha: 0.3),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required ThemeData theme,
  }) {
    return SwitchListTile(
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: theme.colorScheme.onSurface,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
      value: value,
      onChanged: onChanged,
      activeThumbColor: theme.colorScheme.primary,
      activeTrackColor: theme.colorScheme.primary.withValues(alpha: 0.3),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: theme.colorScheme.primary, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: theme.colorScheme.onSurface,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          fontSize: 12,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
        size: 20,
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }

  void _showComingSoonDialog(BuildContext context, String feature) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Coming Soon', style: TextStyle(color: theme.colorScheme.onSurface)),
        content: Text(
          'This feature is currently under development and will be available in a future update.',
          style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK', style: TextStyle(color: theme.colorScheme.primary)),
          ),
        ],
      ),
    );
  }

  void _showClearNotificationsDialog(BuildContext context) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Clear Notifications', style: TextStyle(color: theme.colorScheme.onSurface)),
        content: Text(
          'Are you sure you want to clear all notifications? This action cannot be undone.',
          style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel', style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('All notifications cleared'),
                  backgroundColor: theme.colorScheme.primary,
                ),
              );
            },
            child: Text('Clear', style: TextStyle(color: theme.colorScheme.primary)),
          ),
        ],
      ),
    );
  }
}



