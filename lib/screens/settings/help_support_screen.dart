import 'package:flutter/material.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Help & Support', style: TextStyle(color: theme.colorScheme.onSurface)),
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
            title: 'Frequently Asked Questions',
            theme: theme,
            children: [
              _buildFAQItem(
                question: 'How do I add games to my library?',
                answer: 'Search for games using the search tab, then tap on a game and select "Add to Library" to choose your status (Playing, Completed, etc.).',
                theme: theme,
              ),
              _buildFAQItem(
                question: 'How do I rate and review games?',
                answer: 'Go to a game\'s detail page and tap the star rating. You can also add a written review below the rating.',
                theme: theme,
              ),
              _buildFAQItem(
                question: 'Can I create custom playlists?',
                answer: 'Yes! Go to your Library tab, switch to Playlists, and tap the + button to create custom game collections.',
                theme: theme,
              ),
              _buildFAQItem(
                question: 'How do I change themes?',
                answer: 'Go to Settings > Theme Settings to choose from 7 different themes including dark and light modes.',
                theme: theme,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: 'Contact Support',
            theme: theme,
            children: [
              _buildContactItem(
                icon: Icons.email,
                title: 'Email Support',
                subtitle: 'Get help via email',
                onTap: () => _showComingSoonDialog(context, 'Email Support'),
                theme: theme,
              ),
              _buildContactItem(
                icon: Icons.chat,
                title: 'Live Chat',
                subtitle: 'Chat with our support team',
                onTap: () => _showComingSoonDialog(context, 'Live Chat'),
                theme: theme,
              ),
              _buildContactItem(
                icon: Icons.bug_report,
                title: 'Report a Bug',
                subtitle: 'Help us improve the app',
                onTap: () => _showComingSoonDialog(context, 'Bug Report'),
                theme: theme,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: 'Resources',
            theme: theme,
            children: [
              _buildContactItem(
                icon: Icons.book,
                title: 'User Guide',
                subtitle: 'Learn how to use GameLog',
                onTap: () => _showComingSoonDialog(context, 'User Guide'),
                theme: theme,
              ),
              _buildContactItem(
                icon: Icons.video_library,
                title: 'Video Tutorials',
                subtitle: 'Watch helpful tutorials',
                onTap: () => _showComingSoonDialog(context, 'Video Tutorials'),
                theme: theme,
              ),
              _buildContactItem(
                icon: Icons.forum,
                title: 'Community Forum',
                subtitle: 'Connect with other users',
                onTap: () => _showComingSoonDialog(context, 'Community Forum'),
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

  Widget _buildFAQItem({required String question, required String answer, required ThemeData theme}) {
    return ExpansionTile(
      title: Text(
        question,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: theme.colorScheme.onSurface,
        ),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Text(
            answer,
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              height: 1.4,
            ),
          ),
        ),
      ],
      iconColor: theme.colorScheme.primary,
      collapsedIconColor: theme.colorScheme.onSurface.withValues(alpha: 0.6),
    );
  }

  Widget _buildContactItem({
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

  static void _showComingSoonDialog(BuildContext context, String feature) {
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
}



