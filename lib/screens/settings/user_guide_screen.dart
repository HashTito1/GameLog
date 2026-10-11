import 'package:flutter/material.dart';

/// In-app walkthrough of GameLog's main features.
class UserGuideScreen extends StatelessWidget {
  const UserGuideScreen({super.key});

  static const _sections = [
    _GuideSection(
      icon: Icons.search,
      title: 'Find games',
      steps: [
        'Open the Search tab and type a game name.',
        'Use the filter button to narrow results by genre, platform, rating or release year.',
        'Browse the Home tab for trending titles, top charts and genre categories.',
      ],
    ),
    _GuideSection(
      icon: Icons.bookmark,
      title: 'Track your library',
      steps: [
        'Open any game and add it to your library.',
        'Games you rate count as played; unrated ones stay in your backlog.',
        'The Library tab shows everything you have added, grouped by status.',
      ],
    ),
    _GuideSection(
      icon: Icons.star,
      title: 'Rate and review',
      steps: [
        'On a game\'s page, tap the stars to rate it. Tap the left half of a star for a half star.',
        'Add an optional written review and save.',
        'Edit your rating any time; likes and comments on it are kept.',
        'Tap "View All" under reviews to read everyone\'s, sorted by most recent or highest rating.',
      ],
    ),
    _GuideSection(
      icon: Icons.playlist_add,
      title: 'Make playlists',
      steps: [
        'In the Library tab, switch to Playlists and tap +.',
        'Give it a name, then add games from any game page.',
        'Mark a playlist public to show it on your profile.',
      ],
    ),
    _GuideSection(
      icon: Icons.people,
      title: 'Friends and following',
      steps: [
        'Open someone\'s profile from a review or by searching their username.',
        'Send a friend request, or follow them to get notified when they rate games.',
        'Game pages show your friends\' reviews in their own section.',
      ],
    ),
    _GuideSection(
      icon: Icons.forum,
      title: 'Community forum',
      steps: [
        'Open the forum from Help & Support → Community Forum.',
        'Start a discussion or reply to others, and like posts you agree with.',
      ],
    ),
    _GuideSection(
      icon: Icons.flag,
      title: 'Report problems',
      steps: [
        'In a game\'s full review list, tap ⋯ on a review and choose Report.',
        'Found a bug? Go to Help & Support → Report a Bug.',
        'Moderators review every report.',
      ],
    ),
    _GuideSection(
      icon: Icons.palette,
      title: 'Personalize the app',
      steps: [
        'Settings → Theme changes the app\'s colors.',
        'Edit your profile picture, banner, bio and favorite game from the Profile tab.',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('User Guide')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _sections.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final section = _sections[index];
          return Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
            ),
            child: ExpansionTile(
              initiallyExpanded: index == 0,
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
                child: Icon(section.icon, color: theme.colorScheme.primary, size: 20),
              ),
              title: Text(section.title, style: const TextStyle(fontWeight: FontWeight.w600)),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                for (var i = 0; i < section.steps.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${i + 1}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            section.steps[i],
                            style: TextStyle(
                              height: 1.4,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _GuideSection {
  final IconData icon;
  final String title;
  final List<String> steps;

  const _GuideSection({required this.icon, required this.title, required this.steps});
}
