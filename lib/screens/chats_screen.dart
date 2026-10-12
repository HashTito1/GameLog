import 'package:flutter/material.dart';
import '../services/firebase_auth_service.dart';
import '../services/friends_service.dart';
import '../widgets/chat_list.dart';

/// All your conversations, Telegram style, with search and a "new message"
/// button that picks a friend.
class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _friends = [];
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    final me = FirebaseAuthService().currentUser?.uid;
    if (me == null) return;
    try {
      final friends = await FriendsService.instance.getFriends(me);
      if (mounted) setState(() => _friends = friends);
    } catch (e) {
      debugPrint('Could not load friends: $e');
    }
  }

  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (!_searching) _searchController.clear();
    });
  }

  void _newMessage() {
    final theme = Theme.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => SizedBox(
        height: MediaQuery.of(sheetContext).size.height * 0.7,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text('New message', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            ),
            Expanded(
              child: _friends.isEmpty
                  ? Center(
                      child: Text(
                        'Add friends to start chatting.',
                        style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _friends.length,
                      itemBuilder: (context, i) {
                        final friend = _friends[i];
                        final username = (friend['username'] ?? '').toString();
                        return ListTile(
                          leading: ChatAvatar(friend: friend, radius: 22),
                          title: Text(friendName(friend), style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: username.isEmpty ? null : Text('@$username'),
                          onTap: () {
                            Navigator.pop(sheetContext);
                            openChatWith(context, friend['id'], friend);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
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
            : const Text('Chats', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            onPressed: _toggleSearch,
            icon: Icon(_searching ? Icons.close : Icons.search),
            tooltip: _searching ? 'Close search' : 'Search',
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadFriends,
        child: ChatList(friends: _friends, query: _searchController.text),
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
}
