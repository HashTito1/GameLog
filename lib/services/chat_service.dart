import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/game.dart';
import '../models/user_rating.dart';
import 'firebase_auth_service.dart';

/// Kinds of chat message. Stored as the `type` field.
class ChatMessageType {
  static const text = 'text';
  static const game = 'game';
  static const review = 'review';
}

class ChatMessage {
  final String id;
  final String senderId;
  final String type;
  final String? text;
  final String? gameId;
  final String? gameTitle;
  final String? gameCover;
  final double? rating;
  final String? reviewText;
  final String? reviewAuthorName;
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.type,
    required this.createdAt,
    this.text,
    this.gameId,
    this.gameTitle,
    this.gameCover,
    this.rating,
    this.reviewText,
    this.reviewAuthorName,
  });

  factory ChatMessage.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    // Server timestamps are null on our own unsent writes; use the estimate.
    final ts = data['createdAt'];
    return ChatMessage(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      type: data['type'] ?? ChatMessageType.text,
      text: data['text'],
      gameId: data['gameId'],
      gameTitle: data['gameTitle'],
      gameCover: data['gameCover'],
      rating: (data['rating'] as num?)?.toDouble(),
      reviewText: data['reviewText'],
      reviewAuthorName: data['reviewAuthorName'],
      createdAt: ts is Timestamp
          ? ts.toDate()
          : DateTime.fromMillisecondsSinceEpoch(data['sentAt'] ?? 0),
    );
  }

  /// One-line summary for the chat list.
  String get preview => switch (type) {
        ChatMessageType.game => '🎮 ${gameTitle ?? 'a game'}',
        ChatMessageType.review => '⭐ Review of ${gameTitle ?? 'a game'}',
        _ => text ?? '',
      };
}

class ChatSummary {
  final String id;
  final String otherUserId;
  final String lastMessagePreview;
  final String? lastSenderId;
  final DateTime updatedAt;
  final int unreadCount;

  const ChatSummary({
    required this.id,
    required this.otherUserId,
    required this.lastMessagePreview,
    required this.updatedAt,
    required this.unreadCount,
    this.lastSenderId,
  });
}

/// One-to-one chats between friends, stored as chats/{a_b} with the two uids
/// sorted, and messages under chats/{a_b}/messages. firestore.rules limits
/// chats to their two participants and requires them to be friends.
class ChatService {
  ChatService._();
  static final ChatService instance = ChatService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? get _myUid => FirebaseAuthService().currentUser?.uid;

  static String chatIdFor(String a, String b) {
    final ids = [a, b]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  DocumentReference<Map<String, dynamic>> _chatRef(String chatId) =>
      _firestore.collection('chats').doc(chatId);

  /// Your conversations, most recent first.
  Stream<List<ChatSummary>> watchChats() {
    final me = _myUid;
    if (me == null) return const Stream.empty();
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: me)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final data = doc.data();
              final participants = List<String>.from(data['participants'] ?? []);
              final last = (data['lastMessage'] as Map<String, dynamic>?) ?? {};
              final updated = data['updatedAt'];
              return ChatSummary(
                id: doc.id,
                otherUserId: participants.firstWhere((p) => p != me, orElse: () => me),
                lastMessagePreview: last['preview'] ?? '',
                lastSenderId: last['senderId'],
                updatedAt: updated is Timestamp ? updated.toDate() : DateTime.now(),
                unreadCount: ((data['unread'] as Map<String, dynamic>?)?[me] ?? 0) as int,
              );
            }).toList());
  }

  /// Total unread messages across all chats (for the Home badge).
  Stream<int> watchUnreadTotal() =>
      watchChats().map((chats) => chats.fold(0, (total, c) => total + c.unreadCount));

  /// Messages in a chat, oldest first.
  Stream<List<ChatMessage>> watchMessages(String chatId, {int limit = 200}) {
    return _chatRef(chatId)
        .collection('messages')
        .orderBy('sentAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(ChatMessage.fromDoc).toList().reversed.toList());
  }

  Future<void> markRead(String chatId) async {
    final me = _myUid;
    if (me == null) return;
    try {
      await _chatRef(chatId).update({'unread.$me': 0});
    } catch (_) {
      // Chat may not exist yet (no messages sent); nothing to clear.
    }
  }

  Future<void> sendText(String otherUid, String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return Future.value();
    return _send(otherUid, {
      'type': ChatMessageType.text,
      'text': trimmed.length > 2000 ? trimmed.substring(0, 2000) : trimmed,
    });
  }

  Future<void> sendGame(String otherUid, Game game, {String? note}) {
    return _send(otherUid, {
      'type': ChatMessageType.game,
      'gameId': game.id,
      'gameTitle': game.title,
      'gameCover': game.coverImage,
      if (note != null && note.trim().isNotEmpty) 'text': note.trim(),
    });
  }

  Future<void> sendReview(String otherUid, UserRating rating, {String? gameTitle, String? gameCover}) {
    return _send(otherUid, {
      'type': ChatMessageType.review,
      'gameId': rating.gameId,
      'gameTitle': gameTitle ?? rating.gameTitle ?? 'a game',
      'gameCover': gameCover,
      'rating': rating.rating,
      'reviewText': rating.review,
      'reviewAuthorName': rating.displayName ?? rating.username,
    });
  }

  Future<void> _send(String otherUid, Map<String, dynamic> content) async {
    final me = _myUid;
    if (me == null) throw Exception('You need to be signed in to send messages');

    final chatId = chatIdFor(me, otherUid);
    final chatRef = _chatRef(chatId);
    final messageRef = chatRef.collection('messages').doc();
    final preview = ChatMessage(
      id: messageRef.id,
      senderId: me,
      type: content['type'],
      text: content['text'],
      gameTitle: content['gameTitle'],
      createdAt: DateTime.now(),
    ).preview;

    // Create the chat on first message; the rules only allow friends to.
    final chatSnap = await chatRef.get();
    if (!chatSnap.exists) {
      final participants = [me, otherUid]..sort();
      await chatRef.set({
        'participants': participants,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'unread': {me: 0, otherUid: 0},
      });
    }

    final batch = _firestore.batch();
    batch.set(messageRef, {
      ...content,
      'senderId': me,
      'createdAt': FieldValue.serverTimestamp(),
      'sentAt': DateTime.now().millisecondsSinceEpoch,
    });
    batch.update(chatRef, {
      'lastMessage': {
        'preview': preview.length > 120 ? '${preview.substring(0, 120)}…' : preview,
        'senderId': me,
      },
      'updatedAt': FieldValue.serverTimestamp(),
      'unread.$otherUid': FieldValue.increment(1),
    });
    await batch.commit();
  }
}
