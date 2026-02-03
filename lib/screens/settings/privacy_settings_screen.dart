import 'package:flutter/material.dart';

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  bool _profileVisible = true;
  bool _activityVisible = false;
  bool _libraryVisible = true;
  bool _playlistsVisible = true;
  bool _ratingsVisible = true;
  bool _friendsVisible = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Privacy Settings', style: TextStyle(color: theme.colorScheme.onSurface)),
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
            title: 'Profile Visibility',
            theme: theme,
            children: [
              _buildSwitchTile(
                title: 'Profile Visible to Others',
                subtitle: 'Allow other users to view your profile',
                value: _profileVisible,
                onChanged: (value) => setState(() => _profileVisible = value),
                theme: theme,
              ),
              _buildSwitchTile(
                title: 'Show Activity Status',
                subtitle: 'Display when you\'re online or recently active',
                value: _activityVisible,
                onChanged: (value) => setState(() => _activityVisible = value),
                theme: theme,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: 'Content Visibility',
            theme: theme,
            children: [
              _buildSwitchTile(
                title: 'Library Visible',
                subtitle: 'Allow others to see your game library',
                value: _libraryVisible,
                onChanged: (value) => setState(() => _libraryVisible = value),
                theme: theme,
              ),
              _buildSwitchTile(
                title: 'Public Playlists',
                subtitle: 'Show your public playlists to other users',
                value: _playlistsVisible,
                onChanged: (value) => setState(() => _playlistsVisible = value),
                theme: theme,
              ),
              _buildSwitchTile(
                title: 'Ratings & Reviews Visible',
                subtitle: 'Display your game ratings and reviews publicly',
                value: _ratingsVisible,
                onChanged: (value) => setState(() => _ratingsVisible = value),
                theme: theme,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: 'Social Settings',
            theme: theme,
            children: [
              _buildSwitchTile(
                title: 'Friends List Visible',
                subtitle: 'Allow others to see your friends list',
                value: _friendsVisible,
                onChanged: (value) => setState(() => _friendsVisible = value),
                theme: theme,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: 'Data & Privacy',
            theme: theme,
            children: [
              _buildActionTile(
                icon: Icons.download,
                title: 'Download My Data',
                subtitle: 'Get a copy of your GameLog data',
                onTap: () => _showComingSoonDialog(context, 'Data Download'),
                theme: theme,
              ),
              _buildActionTile(
                icon: Icons.delete_forever,
                title: 'Delete Account',
                subtitle: 'Permanently delete your account and data',
                onTap: () => _showDeleteAccountDialog(context),
                theme: theme,
                isDestructive: true,
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
    bool isDestructive = false,
  }) {
    final color = isDestructive ? Colors.red : theme.colorScheme.primary;
    
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: isDestructive ? Colors.red : theme.colorScheme.onSurface,
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

  void _showDeleteAccountDialog(BuildContext context) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Account', style: TextStyle(color: Colors.red)),
        content: Text(
          'Are you sure you want to delete your account? This action cannot be undone and will permanently remove all your data including:\n\n• Game library and ratings\n• Playlists and reviews\n• Friends and social connections\n• Profile information',
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
              _showComingSoonDialog(context, 'Account Deletion');
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}



