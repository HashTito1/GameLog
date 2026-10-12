import 'package:flutter/material.dart';
import 'app_network_image.dart';
import '../services/chat_service.dart';
import '../services/firebase_auth_service.dart';
import '../screens/chat_screen.dart';

String friendName(Map<String, dynamic>? friend) =>
    (friend?['displayName'] ?? friend?['username'] ?? 'Friend').toString();

void openChatWith(BuildContext context, String userId, Map<String, dynamic>? friend) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => ChatScreen(
        otherUserId: userId,
        otherName: friendName(friend),
        otherAvatar: friend?['profileImage'],
      ),
    ),
  );
}

/// Telegram-style conversation list: filter pills, then flat rows with a big
/// avatar, name and time, last message and unread badge.
class ChatList extends StatefulWidget {
  /// Your friends (from FriendsService.getFriends); used for names/avatars and
  /// the "Start a chat" section.
  final List<Map<String, dynamic>> friends;
  final String query;
  final EdgeInsets padding;

  const ChatList({
    super.key,
    required this.friends,
    this.query = '',
    this.padding = EdgeInsets.zero,
  });

  @override
  State<ChatList> createState() => _ChatListState();
}

class _ChatListState extends State<ChatList> {
  final Stream<List<ChatSummary>> _chats = ChatService.instance.watchChats();
  bool _unreadOnly = false;

  bool _matches(Map<String, dynamic>? friend) {
    final q = widget.query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return friendName(friend).toLowerCase().contains(q) ||
        (friend?['username'] ?? '').toString().toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final friendsById = {for (final f in widget.friends) f['id'] as String: f};
    final me = FirebaseAuthService().currentUser?.uid;

    return StreamBuilder<List<ChatSummary>>(
      stream: _chats,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          final building = snapshot.error.toString().contains('failed-precondition');
          return _Message(
            icon: Icons.cloud_off_outlined,
            text: building
                ? 'Chats are still being set up. Try again in a few minutes.'
                : 'Could not load chats. Check your connection and try again.',
          );
        }
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final all = snapshot.data!;
        final unreadCount = all.where((c) => c.unreadCount > 0).length;
        final chats = all
            .where((c) => !_unreadOnly || c.unreadCount > 0)
            .where((c) => _matches(friendsById[c.otherUserId]))
            .toList();
        final chatted = all.map((c) => c.otherUserId).toSet();
        final others = _unreadOnly
            ? const <Map<String, dynamic>>[]
            : widget.friends.where((f) => !chatted.contains(f['id']) && _matches(f)).toList();

        return ListView(
          padding: widget.padding,
          children: [
            _FilterBar(
              allCount: all.length,
              unreadCount: unreadCount,
              unreadOnly: _unreadOnly,
              onChanged: (v) => setState(() => _unreadOnly = v),
            ),
            if (chats.isEmpty && others.isEmpty)
              _Message(
                icon: _unreadOnly ? Icons.mark_chat_read_outlined : Icons.forum_outlined,
                text: widget.query.isNotEmpty
                    ? 'No chats match "${widget.query}".'
                    : _unreadOnly
                        ? "You're all caught up."
                        : widget.friends.isEmpty
                            ? 'Add friends to start chatting and sharing games.'
                            : 'No chats yet.',
              ),
            for (var i = 0; i < chats.length; i++)
              _ChatRow(
                chat: chats[i],
                friend: friendsById[chats[i].otherUserId],
                mine: chats[i].lastSenderId == me,
                showDivider: i < chats.length - 1,
              ),
            if (others.isNotEmpty) ...[
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
                child: Text(
                  'Start a chat',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              for (final friend in others)
                InkWell(
                  onTap: () => openChatWith(context, friend['id'], friend),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        ChatAvatar(friend: friend, radius: 24),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(friendName(friend),
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                              if ((friend['username'] ?? '').toString().isNotEmpty)
                                Text('@${friend['username']}',
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
                            ],
                          ),
                        ),
                        Icon(Icons.chat_bubble_outline,
                            size: 20, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                      ],
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 96),
          ],
        );
      },
    );
  }
}

class _FilterBar extends StatelessWidget {
  final int allCount;
  final int unreadCount;
  final bool unreadOnly;
  final ValueChanged<bool> onChanged;

  const _FilterBar({
    required this.allCount,
    required this.unreadCount,
    required this.unreadOnly,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          _pill(theme, 'All chats', allCount, !unreadOnly, () => onChanged(false)),
          _pill(theme, 'Unread', unreadCount, unreadOnly, () => onChanged(true)),
        ],
      ),
    );
  }

  Widget _pill(ThemeData theme, String label, int count, bool selected, VoidCallback onTap) {
    final fg = selected ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.6);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? theme.colorScheme.primary.withValues(alpha: 0.16) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: fg)),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(
                  color: selected ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: selected ? theme.colorScheme.onPrimary : theme.colorScheme.surface,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChatRow extends StatelessWidget {
  final ChatSummary chat;
  final Map<String, dynamic>? friend;
  final bool mine;
  final bool showDivider;

  const _ChatRow({required this.chat, required this.friend, required this.mine, required this.showDivider});

  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  /// 09:31 today, a weekday this week, "Jun 07" this year, "Jun 07, 2025" before.
  static String time(DateTime t) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(t.year, t.month, t.day);
    if (day == today) {
      return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    }
    if (today.difference(day).inDays < 7) return _days[t.weekday - 1];
    final md = '${_months[t.month - 1]} ${t.day.toString().padLeft(2, '0')}';
    return t.year == now.year ? md : '$md, ${t.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.55);
    final unread = chat.unreadCount > 0;
    final seen = chat.otherUnreadCount == 0;

    return InkWell(
      onTap: () => openChatWith(context, chat.otherUserId, friend),
      child: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: Row(
          children: [
            ChatAvatar(friend: friend, radius: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Container(
                padding: const EdgeInsets.fromLTRB(0, 12, 14, 12),
                decoration: BoxDecoration(
                  border: showDivider
                      ? Border(bottom: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.08)))
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            friendName(friend),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                        if (mine) ...[
                          Icon(
                            seen ? Icons.done_all_rounded : Icons.done_rounded,
                            size: 17,
                            color: seen ? theme.colorScheme.primary : muted,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          time(chat.updatedAt),
                          style: TextStyle(
                            fontSize: 12.5,
                            color: unread ? theme.colorScheme.primary : muted,
                            fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                if (mine)
                                  TextSpan(
                                    text: 'You: ',
                                    style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.8)),
                                  ),
                                TextSpan(text: chat.lastMessagePreview),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 14.5, color: muted),
                          ),
                        ),
                        if (unread) ...[
                          const SizedBox(width: 8),
                          Container(
                            constraints: const BoxConstraints(minWidth: 24),
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              chat.unreadCount > 999 ? '999+' : '${chat.unreadCount}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.onPrimary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Round profile picture, or coloured initials when there isn't one.
class ChatAvatar extends StatelessWidget {
  final Map<String, dynamic>? friend;
  final double radius;

  const ChatAvatar({super.key, required this.friend, this.radius = 24});

  static const _palette = [
    Color(0xFF6366F1),
    Color(0xFFEC4899),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFF3B82F6),
    Color(0xFF8B5CF6),
    Color(0xFFEF4444),
  ];

  @override
  Widget build(BuildContext context) {
    final name = friendName(friend);
    final image = (friend?['profileImage'] ?? '').toString();
    final color = _palette[name.codeUnits.fold<int>(0, (a, b) => a + b) % _palette.length];
    final initials = Container(
      width: radius * 2,
      height: radius * 2,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, Color.lerp(color, Colors.black, 0.25)!],
        ),
      ),
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: radius * 0.8),
      ),
    );
    if (image.isEmpty) return initials;
    return ClipOval(
      child: AppNetworkImage(
        imageUrl: image,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        placeholder: (context, url) => initials,
        errorWidget: (context, url, error) => initials,
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Message({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 64, 32, 32),
      child: Column(
        children: [
          Icon(icon, size: 48, color: muted),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center, style: TextStyle(color: muted)),
        ],
      ),
    );
  }
}
