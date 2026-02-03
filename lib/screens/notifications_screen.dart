import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_auth_service.dart';
import '../services/friends_service.dart';
import 'user_profile_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<NotificationItem> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    
    try {
      final currentUser = FirebaseAuthService().currentUser;
      if (currentUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      final notifications = <NotificationItem>[];
      
      // Load friend requests as notifications
      final friendRequests = await FriendsService.instance.getPendingRequests(currentUser.id);
      for (final request in friendRequests) {
        final senderProfile = request['senderProfile'] ?? {};
        final senderName = senderProfile['displayName'] ?? senderProfile['username'] ?? 'Someone';
        
        notifications.add(NotificationItem(
          id: 'friend_request_${request['id']}',
          type: NotificationType.friendRequest,
          icon: Icons.person_add,
          iconColor: const Color(0xFF06D6A0),
          title: 'New Friend Request',
          message: '$senderName wants to be your friend',
          time: DateTime.fromMillisecondsSinceEpoch(
            request['createdAt']?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch
          ),
          isUnread: true,
          actionData: {
            'requestId': request['id'],
            'fromUserId': request['fromUserId'],
            'toUserId': request['toUserId'],
            'senderProfile': senderProfile,
          },
        ));
      }

      // Load system notifications from Firestore
      final systemNotifications = await _loadSystemNotifications(currentUser.id);
      notifications.addAll(systemNotifications);

      // Sort by time (newest first)
      notifications.sort((a, b) => b.time.compareTo(a.time));

      if (mounted) {
        setState(() {
          _notifications = notifications;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading notifications: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load notifications: $e')),
        );
      }
    }
  }

  Future<List<NotificationItem>> _loadSystemNotifications(String userId) async {
    try {
      final notificationsQuery = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      final notifications = <NotificationItem>[];
      for (final doc in notificationsQuery.docs) {
        final data = doc.data();
        notifications.add(NotificationItem(
          id: doc.id,
          type: NotificationType.system,
          icon: _getIconFromType(data['type'] ?? 'info'),
          iconColor: _getColorFromType(data['type'] ?? 'info'),
          title: data['title'] ?? 'Notification',
          message: data['message'] ?? '',
          time: DateTime.fromMillisecondsSinceEpoch(
            data['createdAt']?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch
          ),
          isUnread: data['isUnread'] ?? false,
          actionData: data['actionData'],
        ));
      }

      return notifications;
    } catch (e) {
      debugPrint('Error loading system notifications: $e');
      return [];
    }
  }

  IconData _getIconFromType(String type) {
    switch (type) {
      case 'welcome':
        return Icons.celebration;
      case 'rating':
        return Icons.star;
      case 'friend':
        return Icons.people;
      case 'game':
        return Icons.videogame_asset;
      case 'achievement':
        return Icons.emoji_events;
      default:
        return Icons.notifications;
    }
  }

  Color _getColorFromType(String type) {
    switch (type) {
      case 'welcome':
        return const Color(0xFF6366F1);
      case 'rating':
        return const Color(0xFFF59E0B);
      case 'friend':
        return const Color(0xFF06D6A0);
      case 'game':
        return const Color(0xFF8B5CF6);
      case 'achievement':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF6366F1);
    }
  }

  void _markAsRead(String notificationId) async {
    try {
      final currentUser = FirebaseAuthService().currentUser;
      if (currentUser == null) return;

      // Update in Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.id)
          .collection('notifications')
          .doc(notificationId)
          .update({'isUnread': false});

      // Update local state
      setState(() {
        final index = _notifications.indexWhere((n) => n.id == notificationId);
        if (index != -1) {
          _notifications[index] = _notifications[index].copyWith(isUnread: false);
        }
      });
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  void _markAllAsRead() async {
    try {
      final currentUser = FirebaseAuthService().currentUser;
      if (currentUser == null) return;

      final batch = FirebaseFirestore.instance.batch();
      
      for (final notification in _notifications.where((n) => n.isUnread && n.type == NotificationType.system)) {
        final docRef = FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.id)
            .collection('notifications')
            .doc(notification.id);
        batch.update(docRef, {'isUnread': false});
      }

      await batch.commit();

      setState(() {
        for (int i = 0; i < _notifications.length; i++) {
          if (_notifications[i].type == NotificationType.system) {
            _notifications[i] = _notifications[i].copyWith(isUnread: false);
          }
        }
      });
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
    }
  }

  Future<void> _handleFriendRequest(NotificationItem notification, bool accept) async {
    try {
      final actionData = notification.actionData;
      final fromUserId = actionData['fromUserId'];
      final toUserId = actionData['toUserId'];

      if (accept) {
        await FriendsService.acceptFriendRequest(fromUserId, toUserId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Friend request accepted!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        await FriendsService.declineFriendRequest(fromUserId, toUserId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Friend request declined'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }

      // Remove notification from list
      setState(() {
        _notifications.removeWhere((n) => n.id == notification.id);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to ${accept ? 'accept' : 'decline'} friend request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unreadCount = _notifications.where((n) => n.isUnread).length;
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        title: Text(
          'Notifications',
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: _markAllAsRead,
              child: Text(
                'Mark all read',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          IconButton(
            icon: Icon(Icons.refresh, color: theme.colorScheme.onSurface),
            onPressed: _loadNotifications,
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
              ),
            )
          : _notifications.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) {
                      final notification = _notifications[index];
                      return _buildNotificationCard(notification);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none,
            size: 80,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No notifications yet',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We\'ll notify you when something interesting happens',
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(NotificationItem notification) {
    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: notification.isUnread 
            ? theme.colorScheme.surface.withValues(alpha: 0.8)
            : theme.colorScheme.surface.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: notification.isUnread
            ? Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3))
            : Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            if (notification.type == NotificationType.system) {
              _markAsRead(notification.id);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: notification.iconColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        notification.icon,
                        color: notification.iconColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  notification.title,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: notification.isUnread 
                                        ? FontWeight.w600 
                                        : FontWeight.w500,
                                  ),
                                ),
                              ),
                              if (notification.isUnread)
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF8B5CF6),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            notification.message,
                            style: const TextStyle(
                              color: Color(0xFFA1A1AA),
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _formatTime(notification.time),
                            style: const TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // Friend request actions
                if (notification.type == NotificationType.friendRequest) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _handleFriendRequest(notification, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Accept'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _handleFriendRequest(notification, false),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF374151),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Decline'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () {
                          final senderId = notification.actionData['fromUserId'];
                          if (senderId != null) {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => UserProfileScreen(userId: senderId),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.person, color: Color(0xFF6366F1)),
                        tooltip: 'View Profile',
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${time.day}/${time.month}/${time.year}';
    }
  }
}

enum NotificationType {
  system,
  friendRequest,
  gameUpdate,
  achievement,
}

class NotificationItem {
  final String id;
  final NotificationType type;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final DateTime time;
  final bool isUnread;
  final Map<String, dynamic> actionData;

  const NotificationItem({
    required this.id,
    required this.type,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    required this.time,
    required this.isUnread,
    this.actionData = const {},
  });

  NotificationItem copyWith({
    String? id,
    NotificationType? type,
    IconData? icon,
    Color? iconColor,
    String? title,
    String? message,
    DateTime? time,
    bool? isUnread,
    Map<String, dynamic>? actionData,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      type: type ?? this.type,
      icon: icon ?? this.icon,
      iconColor: iconColor ?? this.iconColor,
      title: title ?? this.title,
      message: message ?? this.message,
      time: time ?? this.time,
      isUnread: isUnread ?? this.isUnread,
      actionData: actionData ?? this.actionData,
    );
  }
}


