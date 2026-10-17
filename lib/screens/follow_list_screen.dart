import 'package:flutter/material.dart';
import '../services/firebase_auth_service.dart';
import '../services/follow_service.dart';
import '../widgets/chat_list.dart' show ChatAvatar, friendName;
import 'user_profile_screen.dart';

/// A user's followers and the people they follow, as two tabs. Each row
/// opens that profile and (for anyone but you) has a Follow / Following
/// button.
class FollowListScreen extends StatefulWidget {
  final String userId;
  final String? displayName;

  /// 0 = Followers, 1 = Following.
  final int initialTab;

  const FollowListScreen({super.key, required this.userId, this.displayName, this.initialTab = 0});

  @override
  State<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends State<FollowListScreen> {
  late Future<List<Map<String, dynamic>>> _followers;
  late Future<List<Map<String, dynamic>>> _following;
  Set<String> _myFollowing = {};
  final Set<String> _busy = {};
  final String? _me = FirebaseAuthService().currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _followers = FollowService.getFollowers(widget.userId);
    _following = FollowService.getFollowing(widget.userId);
    FollowService.getFollowingIds(refresh: true).then((ids) {
      if (mounted) setState(() => _myFollowing = {...ids});
    });
  }

  Future<void> _refresh() async {
    setState(_load);
    await Future.wait([_followers, _following]);
  }

  Future<void> _toggleFollow(String userId) async {
    if (_busy.contains(userId)) return;
    final wasFollowing = _myFollowing.contains(userId);
    // Flip the button straight away; undo it if the write fails.
    setState(() {
      _busy.add(userId);
      wasFollowing ? _myFollowing.remove(userId) : _myFollowing.add(userId);
    });
    try {
      if (wasFollowing) {
        await FollowService.unfollowUser(userId);
      } else {
        await FollowService.followUser(userId);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => wasFollowing ? _myFollowing.add(userId) : _myFollowing.remove(userId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(wasFollowing ? 'Could not unfollow. Try again.' : 'Could not follow. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _busy.remove(userId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMe = widget.userId == _me;
    final title = isMe ? 'Your network' : (widget.displayName ?? 'Connections');

    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialTab.clamp(0, 1),
      child: Scaffold(
        appBar: AppBar(
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          bottom: TabBar(
            tabs: [
              _CountTab(label: 'Followers', future: _followers),
              _CountTab(label: 'Following', future: _following),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _list(_followers,
                empty: isMe ? 'No followers yet.\nRate and review games so people find you.' : 'No followers yet.'),
            _list(_following,
                empty: isMe ? "You're not following anyone yet.\nFollow players from their profiles." : 'Not following anyone yet.'),
          ],
        ),
      ),
    );
  }

  Widget _list(Future<List<Map<String, dynamic>>> future, {required String empty}) {
    final theme = Theme.of(context);
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final people = snapshot.data!;
          if (people.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 120),
                Icon(Icons.people_outline, size: 52, color: theme.colorScheme.onSurface.withValues(alpha: 0.35)),
                const SizedBox(height: 14),
                Text(
                  empty,
                  textAlign: TextAlign.center,
                  style: TextStyle(height: 1.5, color: theme.colorScheme.onSurface.withValues(alpha: 0.55)),
                ),
              ],
            );
          }
          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: people.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              indent: 84,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
            ),
            itemBuilder: (context, i) => _row(people[i]),
          );
        },
      ),
    );
  }

  Widget _row(Map<String, dynamic> person) {
    final theme = Theme.of(context);
    final id = (person['id'] ?? '').toString();
    final username = (person['username'] ?? '').toString();
    final bio = (person['bio'] ?? '').toString().trim();
    final following = _myFollowing.contains(id);
    const followAccent = Color(0xFFF5B83D);

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => UserProfileScreen(userId: id)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            ChatAvatar(friend: person, radius: 26),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    friendName(person),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  if (username.isNotEmpty)
                    Text(
                      '@$username',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.55)),
                    ),
                  if (bio.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      bio,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.75)),
                    ),
                  ],
                ],
              ),
            ),
            if (id.isNotEmpty && id != _me) ...[
              const SizedBox(width: 10),
              SizedBox(
                height: 36,
                child: following
                    ? OutlinedButton(
                        onPressed: () => _toggleFollow(id),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: followAccent,
                          side: const BorderSide(color: followAccent),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Following'),
                      )
                    : FilledButton(
                        onPressed: () => _toggleFollow(id),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Follow'),
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Tab label with the list's count once it has loaded.
class _CountTab extends StatelessWidget {
  final String label;
  final Future<List<Map<String, dynamic>>> future;

  const _CountTab({required this.label, required this.future});

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: future,
        builder: (context, snapshot) =>
            Text(snapshot.hasData ? '$label · ${snapshot.data!.length}' : label),
      ),
    );
  }
}
