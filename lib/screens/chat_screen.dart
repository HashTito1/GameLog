import 'dart:async';
import 'package:flutter/material.dart';
import '../widgets/app_network_image.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/game.dart';
import '../models/user_rating.dart';
import '../services/chat_service.dart';
import '../services/firebase_auth_service.dart';
import '../services/igdb_service.dart';
import '../services/rating_service.dart';
import '../services/theme_service.dart';
import '../utils/date_format.dart';
import 'game_detail_screen.dart';
import 'user_profile_screen.dart';

/// One-to-one chat with a friend. Messages can be text, a shared game or a
/// shared review; shared items open the game when tapped.
class ChatScreen extends StatefulWidget {
  final String otherUserId;
  final String otherName;
  final String? otherAvatar;

  const ChatScreen({
    super.key,
    required this.otherUserId,
    required this.otherName,
    this.otherAvatar,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  late final String _chatId;
  late final String _myUid;
  bool _sending = false;
  int _lastCount = 0;

  @override
  void initState() {
    super.initState();
    _myUid = FirebaseAuthService().currentUser?.uid ?? '';
    _chatId = ChatService.chatIdFor(_myUid, widget.otherUserId);
    ChatService.instance.markRead(_chatId);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() send) async {
    setState(() => _sending = true);
    try {
      await send();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not send: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendText() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    await _run(() => ChatService.instance.sendText(widget.otherUserId, text));
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _openGame(String? gameId) {
    if (gameId == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => GameDetailScreen(gameId: gameId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        titleSpacing: 0,
        title: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => UserProfileScreen(userId: widget.otherUserId)),
          ),
          child: Row(
            children: [
              _Avatar(url: widget.otherAvatar, name: widget.otherName, radius: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.otherName,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: ChatService.instance.watchMessages(_chatId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Could not load messages: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final messages = snapshot.data!;
                if (messages.length != _lastCount) {
                  _lastCount = messages.length;
                  ChatService.instance.markRead(_chatId);
                  _scrollToBottom();
                }
                if (messages.isEmpty) return _buildEmpty(theme);

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final previous = index > 0 ? messages[index - 1] : null;
                    final showDay = previous == null ||
                        !_sameDay(previous.createdAt, message.createdAt);
                    return Column(
                      children: [
                        if (showDay) _buildDayDivider(theme, message.createdAt),
                        _buildBubble(theme, message),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          _buildInputBar(theme),
        ],
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _buildDayDivider(ThemeData theme, DateTime date) {
    final now = DateTime.now();
    final label = _sameDay(date, now)
        ? 'Today'
        : _sameDay(date, now.subtract(const Duration(days: 1)))
            ? 'Yesterday'
            : formatShortDate(date);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
      ),
    );
  }

  Widget _buildEmpty(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Avatar(url: widget.otherAvatar, name: widget.otherName, radius: 32),
            const SizedBox(height: 12),
            Text(
              'Say hi to ${widget.otherName}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Send a message, or tap + to share a game or one of your reviews.',
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBubble(ThemeData theme, ChatMessage message) {
    final mine = message.senderId == _myUid;
    final bubbleColor = mine ? theme.colorScheme.primary : theme.colorScheme.surface;
    final textColor = mine ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface;
    final time = '${message.createdAt.hour.toString().padLeft(2, '0')}:'
        '${message.createdAt.minute.toString().padLeft(2, '0')}';

    Widget content;
    switch (message.type) {
      case ChatMessageType.game:
      case ChatMessageType.review:
        content = _buildSharedCard(theme, message, mine);
        break;
      default:
        content = Text(message.text ?? '', style: TextStyle(color: textColor, fontSize: 15, height: 1.3));
    }

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.fromLTRB(12, 9, 12, 7),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(mine ? 18 : 4),
              bottomRight: Radius.circular(mine ? 4 : 18),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              content,
              const SizedBox(height: 3),
              Text(time, style: TextStyle(fontSize: 10, color: textColor.withValues(alpha: 0.6))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSharedCard(ThemeData theme, ChatMessage message, bool mine) {
    final textColor = mine ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface;
    final isReview = message.type == ChatMessageType.review;
    final review = message.reviewText?.trim();

    return InkWell(
      onTap: () => _openGame(message.gameId),
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isReview ? 'Shared a review' : 'Shared a game',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textColor.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 48,
                    height: 64,
                    child: (message.gameCover?.isNotEmpty ?? false)
                        ? AppNetworkImage(imageUrl: message.gameCover!, fit: BoxFit.cover)
                        : Container(
                            color: Colors.black26,
                            child: Icon(Icons.videogame_asset, color: textColor.withValues(alpha: 0.7)),
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        message.gameTitle ?? 'Game',
                        style: TextStyle(fontWeight: FontWeight.w700, color: textColor),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (isReview && message.rating != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star_rounded, size: 14, color: ThemeService().starColor),
                            const SizedBox(width: 2),
                            Text(
                              '${message.rating!.toStringAsFixed(1)} by ${message.reviewAuthorName ?? 'someone'}',
                              style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.85)),
                            ),
                          ],
                        ),
                      ],
                      if (isReview && review != null && review.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          '"$review"',
                          style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: textColor.withValues(alpha: 0.85)),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        'Tap to open',
                        style: TextStyle(fontSize: 11, color: textColor.withValues(alpha: 0.6)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (message.text != null && message.text!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(message.text!, style: TextStyle(color: textColor, fontSize: 15)),
          ],
        ],
      ),
    );
  }

  Widget _buildInputBar(ThemeData theme) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        color: theme.colorScheme.surface,
        child: Row(
          children: [
            IconButton(
              onPressed: _sending ? null : _openShareMenu,
              icon: Icon(Icons.add_circle_outline, color: theme.colorScheme.primary),
              tooltip: 'Share a game or review',
            ),
            Expanded(
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 4,
                maxLength: 2000,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _sendText(),
                decoration: InputDecoration(
                  hintText: 'Message',
                  counterText: '',
                  isDense: true,
                  filled: true,
                  fillColor: theme.colorScheme.onSurface.withValues(alpha: 0.06),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton.filled(
              onPressed: _sending ? null : _sendText,
              icon: _sending
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send_rounded),
              tooltip: 'Send',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openShareMenu() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.videogame_asset_outlined),
              title: const Text('Share a game'),
              subtitle: const Text('Search for any game'),
              onTap: () => Navigator.pop(context, 'game'),
            ),
            ListTile(
              leading: const Icon(Icons.rate_review_outlined),
              title: const Text('Share one of my reviews'),
              subtitle: const Text('Pick from your recent ratings'),
              onTap: () => Navigator.pop(context, 'review'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'game') {
      final game = await showModalBottomSheet<Game>(
        context: context,
        isScrollControlled: true,
        builder: (context) => const _GamePickerSheet(),
      );
      if (game != null) await _run(() => ChatService.instance.sendGame(widget.otherUserId, game));
    } else {
      final picked = await showModalBottomSheet<(UserRating, Game?)>(
        context: context,
        isScrollControlled: true,
        builder: (context) => _ReviewPickerSheet(userId: _myUid),
      );
      if (picked != null) {
        final (rating, game) = picked;
        await _run(() => ChatService.instance.sendReview(
              widget.otherUserId,
              rating,
              gameTitle: game?.title,
              gameCover: game?.coverImage,
            ));
      }
    }
  }
}

class _Avatar extends StatelessWidget {
  final String? url;
  final String name;
  final double radius;

  const _Avatar({required this.url, required this.name, this.radius = 20});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasImage = url != null && url!.isNotEmpty;
    return CircleAvatar(
      radius: radius,
      backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
      backgroundImage: hasImage ? CachedNetworkImageProvider(url!) : null,
      child: hasImage
          ? null
          : Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
                fontSize: radius * 0.8,
              ),
            ),
    );
  }
}

/// Search IGDB and return the picked game.
class _GamePickerSheet extends StatefulWidget {
  const _GamePickerSheet();

  @override
  State<_GamePickerSheet> createState() => _GamePickerSheetState();
}

class _GamePickerSheetState extends State<_GamePickerSheet> {
  Timer? _debounce;
  List<Game> _results = [];
  bool _loading = false;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      if (query.trim().isEmpty) {
        setState(() => _results = []);
        return;
      }
      setState(() => _loading = true);
      try {
        final games = await IGDBService.instance.searchGames(query.trim(), limit: 20);
        if (mounted) setState(() => _results = games);
      } catch (_) {
        if (mounted) setState(() => _results = []);
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return _PickerFrame(
      title: 'Share a game',
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              autofocus: true,
              onChanged: _onChanged,
              decoration: const InputDecoration(
                hintText: 'Search games…',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          Expanded(
            child: ListView.builder(
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final game = _results[index];
                return ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      width: 36,
                      height: 48,
                      child: game.coverImage.isNotEmpty
                          ? AppNetworkImage(imageUrl: game.coverImage, fit: BoxFit.cover)
                          : const Icon(Icons.videogame_asset),
                    ),
                  ),
                  title: Text(game.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(game.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () => Navigator.pop(context, game),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Pick one of the current user's recent ratings.
class _ReviewPickerSheet extends StatefulWidget {
  final String userId;
  const _ReviewPickerSheet({required this.userId});

  @override
  State<_ReviewPickerSheet> createState() => _ReviewPickerSheetState();
}

class _ReviewPickerSheetState extends State<_ReviewPickerSheet> {
  late final Future<List<UserRating>> _ratings =
      RatingService.getUserRecentRatings(widget.userId, limit: 30);
  final Map<String, Future<Game?>> _games = {};

  Future<Game?> _gameFor(String id) => _games.putIfAbsent(id, () async {
        try {
          return await IGDBService.instance.getGameDetails(id);
        } catch (_) {
          return null;
        }
      });

  @override
  Widget build(BuildContext context) {
    return _PickerFrame(
      title: 'Share one of my reviews',
      child: FutureBuilder<List<UserRating>>(
        future: _ratings,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final ratings = snapshot.data!;
          if (ratings.isEmpty) {
            return const Center(child: Text('You haven\'t rated any games yet.'));
          }
          return ListView.builder(
            itemCount: ratings.length,
            itemBuilder: (context, index) {
              final rating = ratings[index];
              return FutureBuilder<Game?>(
                future: _gameFor(rating.gameId),
                builder: (context, gameSnap) {
                  final game = gameSnap.data;
                  return ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(
                        width: 36,
                        height: 48,
                        child: (game?.coverImage.isNotEmpty ?? false)
                            ? AppNetworkImage(imageUrl: game!.coverImage, fit: BoxFit.cover)
                            : const Icon(Icons.videogame_asset),
                      ),
                    ),
                    title: Text(
                      game?.title ?? rating.gameTitle ?? 'Game',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${rating.rating.toStringAsFixed(1)}★'
                      '${(rating.review ?? '').trim().isNotEmpty ? ' · "${rating.review!.trim()}"' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => Navigator.pop(context, (rating, game)),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _PickerFrame extends StatelessWidget {
  final String title;
  final Widget child;
  const _PickerFrame({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}
