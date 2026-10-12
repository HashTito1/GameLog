import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/game.dart';
import '../models/user_rating.dart';
import '../services/chat_service.dart';
import '../services/firebase_auth_service.dart';
import '../services/friends_service.dart';

/// Pick a friend and send them a game or a review as a chat message.
/// Pass either [game], or [review] (with its game's title/cover if known).
Future<void> showSendToFriendSheet(
  BuildContext context, {
  Game? game,
  UserRating? review,
  String? gameTitle,
  String? gameCover,
}) async {
  assert(game != null || review != null);
  final sentTo = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _SendToFriendSheet(
      game: game,
      review: review,
      gameTitle: gameTitle,
      gameCover: gameCover,
    ),
  );
  if (sentTo != null && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Sent to $sentTo')),
    );
  }
}

class _SendToFriendSheet extends StatefulWidget {
  final Game? game;
  final UserRating? review;
  final String? gameTitle;
  final String? gameCover;

  const _SendToFriendSheet({this.game, this.review, this.gameTitle, this.gameCover});

  @override
  State<_SendToFriendSheet> createState() => _SendToFriendSheetState();
}

class _SendToFriendSheetState extends State<_SendToFriendSheet> {
  late final Future<List<Map<String, dynamic>>> _friends = () async {
    final me = FirebaseAuthService().currentUser?.uid;
    if (me == null) return <Map<String, dynamic>>[];
    return FriendsService.instance.getFriends(me);
  }();
  String? _sendingTo;

  Future<void> _send(Map<String, dynamic> friend) async {
    final friendId = friend['id'] as String;
    final name = (friend['displayName'] ?? friend['username'] ?? 'your friend').toString();
    setState(() => _sendingTo = friendId);
    try {
      if (widget.game != null) {
        await ChatService.instance.sendGame(friendId, widget.game!);
      } else {
        await ChatService.instance.sendReview(
          friendId,
          widget.review!,
          gameTitle: widget.gameTitle,
          gameCover: widget.gameCover,
        );
      }
      if (mounted) Navigator.pop(context, name);
    } catch (e) {
      if (mounted) {
        setState(() => _sendingTo = null);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not send: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final what = widget.game != null ? widget.game!.title : 'this review';

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.6,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
            child: Text('Send to a friend', style: theme.textTheme.titleLarge),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              'Share $what in a chat',
              style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _friends,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final friends = snapshot.data!;
                if (friends.isEmpty) {
                  return const Center(child: Text('Add friends to share games with them.'));
                }
                return ListView.builder(
                  itemCount: friends.length,
                  itemBuilder: (context, index) {
                    final friend = friends[index];
                    final name = (friend['displayName'] ?? friend['username'] ?? 'Friend').toString();
                    final avatar = friend['profileImage'] as String?;
                    final sending = _sendingTo == friend['id'];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                        backgroundImage: (avatar != null && avatar.isNotEmpty)
                            ? CachedNetworkImageProvider(avatar)
                            : null,
                        child: (avatar == null || avatar.isEmpty)
                            ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?')
                            : null,
                      ),
                      title: Text(name),
                      trailing: sending
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : FilledButton.tonal(
                              onPressed: _sendingTo == null ? () => _send(friend) : null,
                              child: const Text('Send'),
                            ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
