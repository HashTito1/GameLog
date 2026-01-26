import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/user_data_service.dart';
import '../services/firebase_auth_service.dart';

enum FriendshipStatus {
  none,
  friends,
  requestSent,
  requestReceived,
  self,
}

// Temporary FriendsService stub
class FriendsService {
  static final FriendsService _instance = FriendsService._internal();
  factory FriendsService() => _instance;
  FriendsService._internal();
  static FriendsService get instance => _instance;

  static Future<FriendshipStatus> getFriendshipStatus(String currentUserId, String targetUserId) async {
    return FriendshipStatus.none;
  }

  static Future<void> sendFriendRequest(String fromUserId, String toUserId) async {
    // Stub implementation
  }

  static Future<void> removeFriend(String userId, String friendId) async {
    // Stub implementation
  }

  Future<List<Map<String, dynamic>>> getFriends(String userId) async {
    return [];
  }

  Future<List<Map<String, dynamic>>> getPendingRequests(String userId) async {
    return [];
  }

  Future<void> acceptFriendRequest(String requestId) async {
    // Stub implementation
  }
}

class UserProfileScreen extends StatefulWidget {
  final String userId;
  
  const UserProfileScreen({super.key, required this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  FriendshipStatus _friendshipStatus = FriendshipStatus.none;
  bool _isLoadingAction = false;
  bool _isLoading = true;
  User? _user;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      debugPrint('Loading user data for userId: ${widget.userId}');
      
      // Load user data
      final userData = await UserDataService.getUserProfile(widget.userId);
      debugPrint('User data received: $userData');
      
      // Load friendship status
      final currentUser = FirebaseAuthService.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }
      
      final friendshipStatus = await FriendsService.getFriendshipStatus(currentUser.uid, widget.userId);
      debugPrint('Friendship status: $friendshipStatus');
      
      if (mounted) {
        if (userData != null) {
          setState(() {
            _user = User.fromMap(userData);
            _friendshipStatus = friendshipStatus;
            _isLoading = false;
          });
          debugPrint('User profile loaded successfully: ${_user?.username}');
        } else {
          setState(() {
            _isLoading = false;
          });
          debugPrint('No user data found for userId: ${widget.userId}');
          
          // Show a more helpful error message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User profile not found. This user may not exist or may not have completed registration.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load user profile: $e')),
        );
      }
    }
  }

  Future<void> _sendFriendRequest() async {
    setState(() {
      _isLoadingAction = true;
    });

    try {
      final currentUser = FirebaseAuthService.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }
      
      await FriendsService.sendFriendRequest(currentUser.uid, widget.userId);
      
      if (mounted) {
        setState(() {
          _friendshipStatus = FriendshipStatus.requestSent;
          _isLoadingAction = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Friend request sent!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingAction = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send friend request: $e')),
        );
      }
    }
  }

  Future<void> _removeFriend() async {
    setState(() {
      _isLoadingAction = true;
    });

    try {
      final currentUser = FirebaseAuthService.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }
      
      await FriendsService.removeFriend(currentUser.uid, widget.userId);
      
      if (mounted) {
        setState(() {
          _friendshipStatus = FriendshipStatus.none;
          _isLoadingAction = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Friend removed')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingAction = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove friend: $e')),
        );
      }
    }
  }

  Future<void> _acceptFriendRequest() async {
    setState(() {
      _isLoadingAction = true;
    });

    try {
      final currentUser = FirebaseAuthService.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }
      
      // Find the friend request first
      final pendingRequests = await FriendsService.instance.getPendingRequests(currentUser.uid);
      final request = pendingRequests.firstWhere(
        (req) => req['fromUserId'] == widget.userId,
        orElse: () => throw Exception('Friend request not found'),
      );
      
      await FriendsService.instance.acceptFriendRequest(request['id']);
      
      if (mounted) {
        setState(() {
          _friendshipStatus = FriendshipStatus.friends;
          _isLoadingAction = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Friend request accepted!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingAction = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to accept friend request: $e')),
        );
      }
    }
  }

  String _formatJoinDate(DateTime joinDate) {
    final now = DateTime.now();
    final difference = now.difference(joinDate);
    
    if (difference.inDays < 30) {
      return 'Joined ${difference.inDays} days ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return 'Joined $months month${months > 1 ? 's' : ''} ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return 'Joined $years year${years > 1 ? 's' : ''} ago';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111827),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F2937),
        elevation: 0,
        title: const Text(
          'User Profile',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
              ),
            )
          : _user == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'User not found',
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'User ID: ${widget.userId}',
                        style: const TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () async {
                          // Test loading current user's profile
                          final currentUser = FirebaseAuthService.instance.currentUser;
                          if (currentUser != null) {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (context) => UserProfileScreen(userId: currentUser.uid),
                              ),
                            );
                          }
                        },
                        child: const Text('View My Profile (Debug)'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildProfileHeader(),
                      const SizedBox(height: 24),
                      _buildStatsSection(),
                      const SizedBox(height: 24),
                      _buildFriendshipActions(),
                      const SizedBox(height: 24),
                      _buildBioSection(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF374151)),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: const Color(0xFF6366F1),
            backgroundImage: _user!.profileImage.isNotEmpty
                ? NetworkImage(_user!.profileImage)
                : null,
            child: _user!.profileImage.isEmpty
                ? Text(
                    _user!.displayName.isNotEmpty
                        ? _user!.displayName[0].toUpperCase()
                        : _user!.username[0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 16),
          Text(
            _user!.displayName.isNotEmpty ? _user!.displayName : _user!.username,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          if (_user!.displayName.isNotEmpty && _user!.displayName != _user!.username)
            Text(
              '@${_user!.username}',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          const SizedBox(height: 8),
          Text(
            _formatJoinDate(_user!.joinDate),
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF374151)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatItem('Games', _user!.gamesPlayed.toString()),
          _buildStatItem('Reviews', _user!.reviewsWritten.toString()),
          _buildStatItem('Followers', _user!.followers.toString()),
          _buildStatItem('Following', _user!.following.toString()),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildFriendshipActions() {
    return SizedBox(
      width: double.infinity,
      child: _buildFriendshipButton(),
    );
  }

  Widget _buildFriendshipButton() {
    switch (_friendshipStatus) {
      case FriendshipStatus.none:
        return ElevatedButton.icon(
          onPressed: _isLoadingAction ? null : _sendFriendRequest,
          icon: _isLoadingAction
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.person_add),
          label: const Text('Send Friend Request'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6366F1),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      case FriendshipStatus.requestSent:
        return ElevatedButton.icon(
          onPressed: null,
          icon: const Icon(Icons.schedule),
          label: const Text('Request Sent'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      case FriendshipStatus.requestReceived:
        return Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isLoadingAction ? null : _acceptFriendRequest,
                icon: _isLoadingAction
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: const Text('Accept'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isLoadingAction ? null : _removeFriend,
                icon: const Icon(Icons.close),
                label: const Text('Decline'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        );
      case FriendshipStatus.friends:
        return ElevatedButton.icon(
          onPressed: _isLoadingAction ? null : _removeFriend,
          icon: _isLoadingAction
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.person_remove),
          label: const Text('Remove Friend'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFEF4444),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      case FriendshipStatus.self:
        return ElevatedButton.icon(
          onPressed: null,
          icon: const Icon(Icons.person),
          label: const Text('This is you'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
    }
  }

  Widget _buildBioSection() {
    if (_user!.bio.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF374151)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'About',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _user!.bio,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}