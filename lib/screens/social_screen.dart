import 'dart:async';
import 'package:flutter/material.dart';
import '../services/firebase_auth_service.dart';
import '../services/friends_service.dart';
import '../services/user_data_service.dart';
import '../widgets/chat_list.dart';
import 'user_profile_screen.dart';

/// One place for your friends and your conversations: friend requests at the
/// top, a row of friends to start a chat, then your chats.
class SocialScreen extends StatefulWidget {
  const SocialScreen({super.key});

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _requests = [];
  bool _loaded = false;
  bool _searching = false;

  String? get _me => FirebaseAuthService().currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final me = _me;
    if (me == null) return;
    try {
      final results = await Future.wait([
        FriendsService.instance.getFriends(me),
        FriendsService.instance.getPendingRequests(me),
      ]);
      if (mounted) {
        setState(() {
          _friends = results[0];
          _requests = results[1];
          _loaded = true;
        });
      }
    } catch (e) {
      debugPrint('Could not load social data: $e');
      if (mounted) setState(() => _loaded = true);
    }
  }

  void _toast(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  void _openProfile(String userId) {
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => UserProfileScreen(userId: userId)));
  }

  Future<void> _openFindPeople() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (context) => const FindPeopleScreen()));
    _load();
  }

  // ---------------------------------------------------------------------------
  // Friend actions
  // ---------------------------------------------------------------------------

  void _friendActions(String userId, Map<String, dynamic>? friend) {
    final theme = Theme.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: ChatAvatar(friend: friend, radius: 22),
              title: Text(friendName(friend), style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: (friend?['username'] ?? '').toString().isEmpty ? null : Text('@${friend!['username']}'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline),
              title: const Text('Message'),
              onTap: () {
                Navigator.pop(sheet);
                openChatWith(context, userId, friend);
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('View profile'),
              onTap: () {
                Navigator.pop(sheet);
                _openProfile(userId);
              },
            ),
            if (friend != null)
              ListTile(
                leading: Icon(Icons.person_remove_outlined, color: theme.colorScheme.error),
                title: Text('Remove friend', style: TextStyle(color: theme.colorScheme.error)),
                onTap: () {
                  Navigator.pop(sheet);
                  _confirmRemove(userId, friend);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmRemove(String userId, Map<String, dynamic> friend) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Remove friend?'),
        content: Text('You and ${friendName(friend)} will no longer be friends. Your chat history stays.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(dialog).colorScheme.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    final me = _me;
    if (ok != true || me == null) return;
    setState(() => _friends.removeWhere((f) => f['id'] == userId));
    try {
      await FriendsService.removeFriend(me, userId);
      if (mounted) _toast('${friendName(friend)} removed');
    } catch (e) {
      if (mounted) _toast('Could not remove friend. Try again.');
      _load();
    }
  }

  // ---------------------------------------------------------------------------
  // Requests
  // ---------------------------------------------------------------------------

  Future<void> _openRequests() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) => _RequestsSheet(
        requests: _requests,
        onChanged: (request, accepted) {
          setState(() => _requests.remove(request));
          if (accepted) _load();
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // New message
  // ---------------------------------------------------------------------------

  void _newMessage() {
    if (_friends.isEmpty) {
      _openFindPeople();
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) => SizedBox(
        height: MediaQuery.of(sheet).size.height * 0.7,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('New message', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _friends.length,
                itemBuilder: (context, i) {
                  final friend = _friends[i];
                  final username = (friend['username'] ?? '').toString();
                  return ListTile(
                    leading: ChatAvatar(friend: friend, radius: 22),
                    title: Text(friendName(friend), style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: username.isEmpty ? null : Text('@$username'),
                    onTap: () {
                      Navigator.pop(sheet);
                      openChatWith(this.context, friend['id'], friend);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        titleSpacing: _searching ? 0 : null,
        title: _searching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(fontSize: 18),
                decoration: const InputDecoration(
                  hintText: 'Search chats',
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              )
            : const Text('Social', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            onPressed: () => setState(() {
              _searching = !_searching;
              if (!_searching) _searchController.clear();
            }),
            icon: Icon(_searching ? Icons.close : Icons.search),
            tooltip: _searching ? 'Close search' : 'Search chats',
          ),
          if (!_searching)
            IconButton(
              onPressed: _openFindPeople,
              icon: const Icon(Icons.person_add_alt_1_outlined),
              tooltip: 'Find people',
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ChatList(
          friends: _friends,
          query: _searchController.text,
          showStartSection: false,
          onLongPress: _friendActions,
          header: _searching ? null : _buildHeader(theme),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _newMessage,
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        shape: const CircleBorder(),
        tooltip: 'New message',
        child: const Icon(Icons.edit_outlined),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_requests.isNotEmpty) _buildRequestsBanner(theme),
        _sectionLabel(theme, 'Friends', trailing: _friends.isEmpty ? null : '${_friends.length}'),
        SizedBox(
          height: 104,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              _FriendBubble(
                label: 'Add',
                onTap: _openFindPeople,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.primary.withValues(alpha: 0.14),
                    border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.5), width: 1.5),
                  ),
                  child: Icon(Icons.add_rounded, color: theme.colorScheme.primary, size: 28),
                ),
              ),
              if (!_loaded)
                for (var i = 0; i < 4; i++)
                  _FriendBubble(
                    label: '',
                    child: CircleAvatar(
                      radius: 30,
                      backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.07),
                    ),
                  ),
              for (final friend in _friends)
                _FriendBubble(
                  label: friendName(friend),
                  onTap: () => openChatWith(context, friend['id'], friend),
                  onLongPress: () => _friendActions(friend['id'], friend),
                  child: ChatAvatar(friend: friend, radius: 30),
                ),
            ],
          ),
        ),
        if (_loaded && _friends.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              'Add friends to chat and share games and reviews with them.',
              style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.55)),
            ),
          ),
        const SizedBox(height: 8),
        _sectionLabel(theme, 'Messages'),
      ],
    );
  }

  Widget _sectionLabel(ThemeData theme, String text, {String? trailing}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          Text(text, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: theme.colorScheme.onSurface)),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            Text(trailing, style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
          ],
        ],
      ),
    );
  }

  Widget _buildRequestsBanner(ThemeData theme) {
    final people = _requests.take(3).map((r) => Map<String, dynamic>.from(r['senderProfile'] ?? {})).toList();
    final count = _requests.length;
    final first = friendName(people.first);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Material(
        color: theme.colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: _openRequests,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                SizedBox(
                  width: 44.0 + (people.length - 1) * 22,
                  height: 44,
                  child: Stack(
                    children: [
                      for (var i = 0; i < people.length; i++)
                        Positioned(
                          left: i * 22.0,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: theme.scaffoldBackgroundColor, width: 2),
                            ),
                            child: ChatAvatar(friend: people[i], radius: 20),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        count == 1 ? 'Friend request' : '$count friend requests',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        count == 1 ? '$first wants to be friends' : '$first and ${count - 1} more',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.65)),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(fontWeight: FontWeight.w800, color: theme.colorScheme.onPrimary),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Round avatar with a name under it, for the friends row.
class _FriendBubble extends StatelessWidget {
  final Widget child;
  final String label;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const _FriendBubble({required this.child, required this.label, this.onTap, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      onLongPress: onLongPress,
      child: SizedBox(
        width: 76,
        child: Column(
          children: [
            const SizedBox(height: 4),
            child,
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet listing incoming friend requests with Accept / Decline.
class _RequestsSheet extends StatefulWidget {
  final List<Map<String, dynamic>> requests;
  final void Function(Map<String, dynamic> request, bool accepted) onChanged;

  const _RequestsSheet({required this.requests, required this.onChanged});

  @override
  State<_RequestsSheet> createState() => _RequestsSheetState();
}

class _RequestsSheetState extends State<_RequestsSheet> {
  late final List<Map<String, dynamic>> _pending = [...widget.requests];
  final Set<Map<String, dynamic>> _busy = {};

  Future<void> _respond(Map<String, dynamic> request, bool accept) async {
    setState(() => _busy.add(request));
    try {
      if (accept) {
        await FriendsService.acceptFriendRequest(request['fromUserId'], request['toUserId']);
      } else {
        await FriendsService.declineFriendRequest(request['fromUserId'], request['toUserId']);
      }
      widget.onChanged(request, accept);
      if (!mounted) return;
      setState(() => _pending.remove(request));
      if (_pending.isEmpty) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy.remove(request));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Something went wrong. Try again.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('Friend requests', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final request in _pending)
                    Builder(builder: (context) {
                      final sender = Map<String, dynamic>.from(request['senderProfile'] ?? {});
                      final username = (sender['username'] ?? '').toString();
                      final busy = _busy.contains(request);
                      return ListTile(
                        contentPadding: const EdgeInsets.fromLTRB(20, 4, 12, 4),
                        leading: ChatAvatar(friend: sender, radius: 24),
                        title: Text(friendName(sender), style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(username.isEmpty ? 'Wants to be friends' : '@$username'),
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (context) => UserProfileScreen(userId: request['fromUserId']),
                        )),
                        trailing: busy
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    onPressed: () => _respond(request, false),
                                    icon: const Icon(Icons.close_rounded),
                                    tooltip: 'Decline',
                                    style: IconButton.styleFrom(
                                      backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  FilledButton(
                                    onPressed: () => _respond(request, true),
                                    style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    child: const Text('Accept'),
                                  ),
                                ],
                              ),
                      );
                    }),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

/// Search for people by name or username, with one action per person
/// (Add / Requested / Accept / Message), plus your pending sent requests.
class FindPeopleScreen extends StatefulWidget {
  const FindPeopleScreen({super.key});

  @override
  State<FindPeopleScreen> createState() => _FindPeopleScreenState();
}

class _FindPeopleScreenState extends State<FindPeopleScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _results = [];
  List<Map<String, dynamic>> _sent = [];
  final Map<String, FriendshipStatus> _status = {};
  final Set<String> _busy = {};
  bool _searching = false;

  String? get _me => FirebaseAuthService().currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _loadSent();
  }

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadSent() async {
    final me = _me;
    if (me == null) return;
    final sent = await FriendsService.instance.getSentRequests(me);
    if (mounted) setState(() => _sent = sent);
  }

  void _onChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(query.trim()));
    setState(() {});
  }

  Future<void> _search(String query) async {
    if (query.isEmpty) {
      setState(() {
        _results = [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    try {
      final results = (await UserDataService.searchUsers(query)).where((u) => u['id'] != _me).toList();
      final me = _me;
      final statuses = me == null
          ? <FriendshipStatus>[]
          : await Future.wait(results.map((u) => FriendsService.getFriendshipStatus(me, u['id'])));
      if (!mounted || _controller.text.trim() != query) return;
      setState(() {
        _results = results;
        for (var i = 0; i < statuses.length; i++) {
          _status[results[i]['id']] = statuses[i];
        }
        _searching = false;
      });
    } catch (e) {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _act(Map<String, dynamic> user) async {
    final me = _me;
    final id = user['id'] as String;
    if (me == null || _busy.contains(id)) return;
    final status = _status[id] ?? FriendshipStatus.none;
    if (status == FriendshipStatus.friends) {
      openChatWith(context, id, user);
      return;
    }
    setState(() => _busy.add(id));
    try {
      if (status == FriendshipStatus.none) {
        await FriendsService.sendFriendRequest(me, id);
        _status[id] = FriendshipStatus.requestSent;
        _loadSent();
      } else if (status == FriendshipStatus.requestReceived) {
        await FriendsService.acceptFriendRequest(id, me);
        _status[id] = FriendshipStatus.friends;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Something went wrong. Try again.')));
      }
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  Future<void> _cancel(Map<String, dynamic> request) async {
    setState(() => _sent.remove(request));
    try {
      await FriendsService.instance.cancelFriendRequest(request['fromUserId'], request['toUserId']);
      _status.remove(request['toUserId']);
    } catch (e) {
      _loadSent();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = _controller.text.trim();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Find people', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: theme.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _controller,
              autofocus: true,
              onChanged: _onChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search by name or @username',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _controller.clear();
                          _onChanged('');
                        },
                      ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
          Expanded(child: query.isEmpty ? _buildSent(theme) : _buildResults(theme)),
        ],
      ),
    );
  }

  Widget _buildResults(ThemeData theme) {
    if (_searching && _results.isEmpty) return const Center(child: CircularProgressIndicator());
    if (_results.isEmpty) {
      return Center(
        child: Text('No one found', style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.55))),
      );
    }
    return ListView.builder(
      itemCount: _results.length,
      itemBuilder: (context, i) => _personRow(theme, _results[i]),
    );
  }

  Widget _buildSent(ThemeData theme) {
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.55);
    if (_sent.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const SizedBox(height: 40),
            Icon(Icons.person_search_outlined, size: 52, color: muted),
            const SizedBox(height: 12),
            Text('Search for friends by their name or username.', textAlign: TextAlign.center, style: TextStyle(color: muted)),
          ],
        ),
      );
    }
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
          child: Text('Sent requests', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: muted)),
        ),
        for (final request in _sent)
          Builder(builder: (context) {
            final person = Map<String, dynamic>.from(request['recipientProfile'] ?? {});
            return ListTile(
              contentPadding: const EdgeInsets.fromLTRB(20, 4, 12, 4),
              leading: ChatAvatar(friend: person, radius: 24),
              title: Text(friendName(person), style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('Request sent'),
              trailing: TextButton(onPressed: () => _cancel(request), child: const Text('Cancel')),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => UserProfileScreen(userId: request['toUserId']),
              )),
            );
          }),
      ],
    );
  }

  Widget _personRow(ThemeData theme, Map<String, dynamic> user) {
    final id = user['id'] as String;
    final username = (user['username'] ?? '').toString();
    final status = _status[id];
    final busy = _busy.contains(id);

    final (String label, bool filled, bool enabled) = switch (status) {
      FriendshipStatus.friends => ('Message', false, true),
      FriendshipStatus.requestSent => ('Requested', false, false),
      FriendshipStatus.requestReceived => ('Accept', true, true),
      FriendshipStatus.self => ('You', false, false),
      FriendshipStatus.none => ('Add', true, true),
      null => ('…', false, false),
    };

    final button = busy
        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
        : filled
            ? FilledButton(
                onPressed: enabled ? () => _act(user) : null,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(label),
              )
            : OutlinedButton(
                onPressed: enabled ? () => _act(user) : null,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(label),
              );

    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(20, 4, 12, 4),
      leading: ChatAvatar(friend: user, radius: 24),
      title: Text(friendName(user), style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: username.isEmpty ? null : Text('@$username'),
      trailing: SizedBox(height: 36, child: Center(widthFactor: 1, child: button)),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => UserProfileScreen(userId: id))),
    );
  }
}
