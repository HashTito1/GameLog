import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/firebase_auth_service.dart';
import '../services/user_data_service.dart';
import '../services/igdb_service.dart';
import '../services/library_service.dart';
import '../services/image_picker_service.dart';
import '../services/hybrid_image_storage_service.dart';
import '../models/game.dart';
import 'favorite_game_selection_screen.dart';
import 'friends_screen.dart';
import 'main_screen.dart';
import 'settings_screen.dart';
import 'game_detail_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String userId;
  
  const ProfileScreen({super.key, required this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = false;
  Map<String, dynamic>? _userData;
  Game? _favoriteGame;
  List<Map<String, dynamic>> _userPlaylists = [];
  int _userRatingsCount = 0;
  double _userAverageRating = 0.0;
  int _userBacklogCount = 0;
  
  // Track expanded playlists
  Set<String> _expandedPlaylists = <String>{};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      final currentUser = FirebaseAuthService.instance.currentUser;
      if (currentUser != null) {
        final userData = await UserDataService.getUserProfile(currentUser.uid);
        
        // If user data exists but username/displayName are missing, update them
        if (userData != null && (userData['username'] == null || userData['displayName'] == null)) {
          debugPrint('Updating missing user profile fields...');
          
          // Generate username and displayName from email if missing
          final email = currentUser.email;
          final username = userData['username'] ?? email.split('@')[0].toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '_');
          final displayName = userData['displayName'] ?? currentUser.displayName ?? email.split('@')[0];
          
          // Update Firestore with missing fields
          await UserDataService.saveUserProfile(currentUser.uid, {
            'username': username,
            'displayName': displayName,
          });
          
          // Reload data after update
          final updatedUserData = await UserDataService.getUserProfile(currentUser.uid);
          setState(() {
            _userData = updatedUserData;
          });
        } else if (userData != null && userData['displayName'] == null) {
          // Special case: if displayName is specifically null, set it from username or email
          debugPrint('Setting displayName from username or email...');
          final email = currentUser.email!;
          final displayName = currentUser.displayName ?? userData['username'] ?? email.split('@')[0];
          
          await UserDataService.saveUserProfile(currentUser.uid, {
            'displayName': displayName,
          });
          
          // Reload data after update
          final updatedUserData = await UserDataService.getUserProfile(currentUser.uid);
          setState(() {
            _userData = updatedUserData;
          });
        } else {
          setState(() {
            _userData = userData;
          });
        }

        // Debug: Print user data to see what's loaded
        debugPrint('Loaded user data: $_userData');

        // Load favorite game if exists
        if (_userData != null && _userData!['favoriteGame'] != null) {
          final favoriteGameData = _userData!['favoriteGame'] as Map<String, dynamic>;
          final gameId = favoriteGameData['gameId']?.toString();
          if (gameId != null) {
            try {
              final game = await IGDBService.instance.getGameDetails(gameId);
              setState(() {
                _favoriteGame = game;
              });
            } catch (e) {
              debugPrint('Error loading favorite game: $e');
            }
          }
        }

        // Load user playlists
        if (_userData != null) {
          final playlists = await UserDataService.getUserPlaylistsWithGames(currentUser.uid);
          setState(() {
            _userPlaylists = playlists;
          });
        }

        // Load user rating stats
        await _loadUserRatingStats(currentUser.uid);
      }
    } catch (e) {
      debugPrint('Error loading profile data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadUserRatingStats(String userId) async {
    try {
      // Use the same stats loading logic as library screen
      final stats = await LibraryService.instance.getUserLibraryStats(userId);
      
      setState(() {
        // Update the user data with stats from library service
        if (_userData != null) {
          _userData!['gamesPlayed'] = stats['totalGames'] ?? 0;
        }
        _userRatingsCount = stats['ratedGames'] ?? 0;
        _userAverageRating = (stats['averageRating'] ?? 0.0).toDouble();
        _userBacklogCount = stats['backlogGames'] ?? 0;
      });
    } catch (e) {
      debugPrint('Error loading user rating stats: $e');
      setState(() {
        _userRatingsCount = 0;
        _userAverageRating = 0.0;
        _userBacklogCount = 0;
      });
    }
  }

  void _selectFavoriteGame() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const FavoriteGameSelectionScreen(),
      ),
    );
    
    if (result != null && result is Game) {
      await _setFavoriteGame(result);
    }
  }

  void _changeProfilePicture() async {
    try {
      String? imagePath;
      final theme = Theme.of(context);
      
      // Show bottom sheet to select image source
      final source = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: theme.colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (BuildContext context) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Select Image Source',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context, 'gallery'),
                        child: Container(
                          width: 120,
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF374151),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF4B5563)),
                          ),
                          child: const Column(
                            children: [
                              Icon(
                                Icons.photo_library,
                                color: Color(0xFF6366F1),
                                size: 32,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Gallery',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context, 'camera'),
                        child: Container(
                          width: 120,
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF374151),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF4B5563)),
                          ),
                          child: const Column(
                            children: [
                              Icon(
                                Icons.camera_alt,
                                color: Color(0xFF6366F1),
                                size: 32,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Camera',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      );

      if (source != null) {
        if (source == 'gallery') {
          imagePath = await ImagePickerService.pickImage(context);
        } else if (source == 'camera') {
          imagePath = await ImagePickerService.takePhoto(context);
        }
      }

      if (imagePath != null) {
        // Show loading indicator
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.onPrimary),
                  ),
                  const SizedBox(width: 16),
                  const Text('Uploading profile picture...'),
                ],
              ),
              backgroundColor: theme.colorScheme.primary,
              duration: const Duration(seconds: 3),
            ),
          );
        }

        // Read image bytes
        final file = File(imagePath);
        final imageBytes = await file.readAsBytes();
        
        final currentUser = FirebaseAuthService.instance.currentUser;
        if (currentUser != null) {
          // Get old profile image URL for deletion
          final oldProfileImageUrl = _userData?['profileImage'] as String?;
          
          // Upload image using hybrid storage (cloud first, local fallback)
          try {
            final downloadUrl = await HybridImageStorageService.uploadProfilePicture(
              userId: currentUser.uid,
              imageBytes: imageBytes,
            );
            
            if (downloadUrl != null) {
              // Update user profile in Firestore with the URL (cloud or local)
              await UserDataService.saveUserProfile(currentUser.uid, {
                'profileImage': downloadUrl,
              });
              
              // Delete old profile image if it exists
              if (oldProfileImageUrl != null && oldProfileImageUrl.isNotEmpty) {
                HybridImageStorageService.deleteOldProfilePicture(oldProfileImageUrl);
              }
              
              // Reload data to reflect changes
              _loadData();
              
              if (mounted) {
                final isCloudUrl = HybridImageStorageService.isCloudStorageUrl(downloadUrl);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isCloudUrl 
                        ? 'Profile picture uploaded to cloud successfully!'
                        : 'Profile picture saved successfully!',
                    ),
                    backgroundColor: theme.colorScheme.secondary,
                  ),
                );
              }
            } else {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Failed to upload profile picture. Please try again.'),
                    backgroundColor: theme.colorScheme.error,
                  ),
                );
              }
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Upload failed: ${e.toString().replaceAll('Exception: ', '')}'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        final theme = Theme.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile picture: $e'),
            backgroundColor: theme.colorScheme.error,
          ),
        );
      }
    }
  }

  void _changeBannerImage() async {
    try {
      String? imagePath;
      final theme = Theme.of(context);
      
      // Show bottom sheet to select image source
      final source = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: theme.colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (BuildContext context) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Select Banner Image Source',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context, 'gallery'),
                        child: Container(
                          width: 120,
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF374151),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF4B5563)),
                          ),
                          child: const Column(
                            children: [
                              Icon(
                                Icons.photo_library,
                                color: Color(0xFF6366F1),
                                size: 32,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Gallery',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context, 'camera'),
                        child: Container(
                          width: 120,
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF374151),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF4B5563)),
                          ),
                          child: const Column(
                            children: [
                              Icon(
                                Icons.camera_alt,
                                color: Color(0xFF6366F1),
                                size: 32,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Camera',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      );

      if (source != null) {
        if (source == 'gallery') {
          imagePath = await ImagePickerService.pickImage(context);
        } else if (source == 'camera') {
          imagePath = await ImagePickerService.takePhoto(context);
        }
      }

      if (imagePath != null) {
        // Show loading indicator
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  ),
                  SizedBox(width: 16),
                  Text('Uploading banner image...'),
                ],
              ),
              backgroundColor: Color(0xFF6366F1),
              duration: Duration(seconds: 3),
            ),
          );
        }

        // Read image bytes
        final file = File(imagePath);
        final imageBytes = await file.readAsBytes();
        
        final currentUser = FirebaseAuthService.instance.currentUser;
        if (currentUser != null) {
          // Get old banner image URL for deletion
          final oldBannerImageUrl = _userData?['bannerImage'] as String?;
          
          // Upload image using hybrid storage (cloud first, local fallback)
          try {
            final downloadUrl = await HybridImageStorageService.uploadBannerImage(
              userId: currentUser.uid,
              imageBytes: imageBytes,
            );
            
            if (downloadUrl != null) {
              // Update user profile in Firestore with the URL (cloud or local)
              await UserDataService.saveUserProfile(currentUser.uid, {
                'bannerImage': downloadUrl,
              });
              
              // Delete old banner image if it exists
              if (oldBannerImageUrl != null && oldBannerImageUrl.isNotEmpty) {
                HybridImageStorageService.deleteOldBannerImage(oldBannerImageUrl);
              }
              
              // Reload data to reflect changes
              _loadData();
              
              if (mounted) {
                final isCloudUrl = HybridImageStorageService.isCloudStorageUrl(downloadUrl);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isCloudUrl 
                        ? 'Banner image uploaded to cloud successfully!'
                        : 'Banner image saved successfully!',
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            } else {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Failed to upload banner image. Please try again.'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Upload failed: ${e.toString().replaceAll('Exception: ', '')}'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update banner image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showProfileMenu() {
    final theme = Theme.of(context);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Profile Options',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                _buildMenuOption(
                  'Change Username',
                  Icons.edit,
                  () {
                    Navigator.pop(context);
                    _showChangeUsernameDialog();
                  },
                ),
                _buildMenuOption(
                  'Change Profile Picture',
                  Icons.photo_camera,
                  () {
                    Navigator.pop(context);
                    _changeProfilePicture();
                  },
                ),
                _buildMenuOption(
                  'Change Banner',
                  Icons.image,
                  () {
                    Navigator.pop(context);
                    _changeBannerImage();
                  },
                ),
                _buildMenuOption(
                  'Settings',
                  Icons.settings,
                  () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => SettingsScreen(),
                      ),
                    );
                  },
                ),
                _buildMenuOption(
                  'Share Profile',
                  Icons.share,
                  () {
                    Navigator.pop(context);
                    // Implement share functionality
                  },
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  void _createPlaylist() async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    bool isPublic = false;
    final theme = Theme.of(context);

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            backgroundColor: theme.colorScheme.surface,
            title: Text(
              'Create Playlist',
              style: TextStyle(color: theme.colorScheme.onSurface),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  style: TextStyle(color: theme.colorScheme.onSurface),
                  decoration: InputDecoration(
                    labelText: 'Playlist Name',
                    labelStyle: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                    hintText: 'Enter playlist name',
                    hintStyle: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: theme.colorScheme.primary),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: theme.colorScheme.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  style: TextStyle(color: theme.colorScheme.onSurface),
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Description (Optional)',
                    labelStyle: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                    hintText: 'Enter playlist description',
                    hintStyle: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: theme.colorScheme.primary),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: theme.colorScheme.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isPublic ? Icons.public : Icons.lock,
                        color: isPublic ? theme.colorScheme.secondary : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isPublic ? 'Public Playlist' : 'Private Playlist',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              isPublic 
                                  ? 'Others can see this playlist on your profile'
                                  : 'Only you can see this playlist',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: isPublic,
                        onChanged: (value) {
                          setDialogState(() {
                            isPublic = value;
                          });
                        },
                        activeThumbColor: theme.colorScheme.secondary,
                        activeTrackColor: theme.colorScheme.secondary.withValues(alpha: 0.3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                ),
              ),
              TextButton(
                onPressed: () {
                  if (nameController.text.trim().isNotEmpty) {
                    Navigator.pop(context, {
                      'name': nameController.text.trim(),
                      'description': descriptionController.text.trim(),
                      'isPublic': isPublic,
                    });
                  }
                },
                child: Text(
                  'Create',
                  style: TextStyle(color: theme.colorScheme.primary),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (result != null) {
      try {
        final currentUser = FirebaseAuthService.instance.currentUser;
        if (currentUser != null) {
          await UserDataService.createPlaylistWithGames(
            userId: currentUser.uid,
            playlistName: result['name']!,
            description: result['description'] ?? '',
            gameIds: [], // Empty playlist initially
            isPublic: result['isPublic'] ?? false,
          );
          
          // Reload data to show new playlist
          _loadData();
          
          if (mounted) {
            final theme = Theme.of(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Playlist "${result['name']}" created successfully!'),
                backgroundColor: theme.colorScheme.secondary,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          final theme = Theme.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to create playlist: $e'),
              backgroundColor: theme.colorScheme.error,
            ),
          );
        }
      }
    }
  }

  void _showChangeUsernameDialog() async {
    final usernameController = TextEditingController();
    final currentUser = FirebaseAuthService.instance.currentUser;
    final theme = Theme.of(context);
    
    if (currentUser == null) return;
    
    // Pre-fill with current username
    final currentUsername = _userData?['username'] ?? '';
    usernameController.text = currentUsername;

    final result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          title: Text(
            'Change Username',
            style: TextStyle(color: theme.colorScheme.onSurface),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Your user ID will remain the same. Only your username will change.',
                style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: usernameController,
                style: TextStyle(color: theme.colorScheme.onSurface),
                decoration: InputDecoration(
                  labelText: 'New Username',
                  labelStyle: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                  hintText: 'Enter new username',
                  hintStyle: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: theme.colorScheme.primary),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: theme.colorScheme.primary),
                  ),
                  helperText: 'Letters, numbers, and underscores only. Min 3 characters.',
                  helperStyle: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 12),
                ),
                maxLength: 20,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
              ),
            ),
            TextButton(
              onPressed: () {
                final newUsername = usernameController.text.trim();
                if (newUsername.isNotEmpty && newUsername != currentUsername) {
                  Navigator.pop(context, newUsername);
                }
              },
              child: Text(
                'Update',
                style: TextStyle(color: theme.colorScheme.primary),
              ),
            ),
          ],
        );
      },
    );

    if (result != null) {
      try {
        // Show loading indicator
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.onPrimary),
                  ),
                  const SizedBox(width: 16),
                  const Text('Updating username...'),
                ],
              ),
              backgroundColor: theme.colorScheme.primary,
              duration: const Duration(seconds: 2),
            ),
          );
        }

        // Update username
        await UserDataService.updateUsername(currentUser.uid, result);
        
        // Update local state instead of reloading all data
        if (mounted) {
          setState(() {
            if (_userData != null) {
              _userData!['username'] = result.toLowerCase();
              _userData!['displayName'] = result;
            }
          });
        }
        
        if (mounted) {
          final theme = Theme.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Username updated to "$result" successfully!'),
              backgroundColor: theme.colorScheme.secondary,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          final theme = Theme.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update username: ${e.toString().replaceAll('Exception: ', '')}'),
              backgroundColor: theme.colorScheme.error,
            ),
          );
        }
      }
    }
  }

  void _navigateToLibraryPlaylist(String? playlistId) {
    // Find the MainScreen in the widget tree and switch to library tab
    final mainScreenState = context.findAncestorStateOfType<MainScreenState>();
    if (mainScreenState != null) {
      if (playlistId != null) {
        mainScreenState.switchToLibraryPlaylist(playlistId);
      } else {
        mainScreenState.switchToTab(3); // Library is at index 3
      }
    }
  }

  Widget _buildMenuOption(String title, IconData icon, VoidCallback onTap) {
    final theme = Theme.of(context);
    
    return ListTile(
      leading: Icon(
        icon,
        color: theme.colorScheme.primary,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: theme.colorScheme.onSurface,
          fontSize: 16,
        ),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      tileColor: Colors.transparent,
      hoverColor: theme.colorScheme.surface,
    );
  }

  Future<void> _setFavoriteGame(Game game) async {
    try {
      final currentUser = FirebaseAuthService.instance.currentUser;
      if (currentUser != null) {
        await UserDataService.saveUserProfile(currentUser.uid, {
          'favoriteGame': {
            'gameId': game.id,
            'gameName': game.title,
            'gameImage': game.coverImage,
            'updatedAt': DateTime.now().millisecondsSinceEpoch,
          },
        });
        
        setState(() {
          _favoriteGame = game;
        });
        
        if (mounted) {
          final theme = Theme.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${game.title} set as favorite game!'),
              backgroundColor: theme.colorScheme.secondary,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        final theme = Theme.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to set favorite game: $e'),
            backgroundColor: theme.colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUser = FirebaseAuthService.instance.currentUser;
    
    if (currentUser == null) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Center(
          child: Text(
            'No user logged in',
            style: TextStyle(color: theme.colorScheme.error, fontSize: 16),
          ),
        ),
      );
    }

    if (_isLoading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
          ),
        ),
      );
    }

    // Extract user data
    final username = _userData?['username'] ?? 'user';
    final displayName = _userData?['displayName'] ?? _userData?['username'] ?? 'User';
    final profileImage = _userData?['profileImage'] ?? '';
    final bannerImage = _userData?['bannerImage'] ?? '';
    final gamesPlayed = _userData?['gamesPlayed'] ?? 0;
    final followers = _userData?['followers'] ?? 0;
    final following = _userData?['following'] ?? 0;

    // Debug: Print extracted values
    debugPrint('Extracted username: $username, displayName: $displayName');

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(bannerImage, profileImage, displayName, username, theme),
          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: 16),
                _buildStatsSection(gamesPlayed, _userRatingsCount, _userBacklogCount, _userAverageRating),
                const SizedBox(height: 16),
                _buildFavoriteGameSection(),
                const SizedBox(height: 16),
                if (_userPlaylists.isNotEmpty) ...[
                  _buildPlaylistsSection(),
                  const SizedBox(height: 16),
                ],
                _buildActionButtons(),
                const SizedBox(height: 16),
                _buildFriendsSection(followers, following),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(String bannerImage, String profileImage, String displayName, String username, ThemeData theme) {
    return SliverAppBar(
      expandedHeight: 240,
      floating: false,
      pinned: true,
      backgroundColor: theme.colorScheme.surface,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          children: [
            // Banner Background
            GestureDetector(
              onTap: _changeBannerImage,
              child: Container(
                decoration: BoxDecoration(
                  gradient: (bannerImage.isEmpty)
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            theme.colorScheme.primary,
                            theme.colorScheme.secondary,
                            theme.colorScheme.tertiary ?? theme.colorScheme.primary,
                            theme.colorScheme.primary.withValues(alpha: 0.8),
                          ],
                        )
                      : null,
                  image: bannerImage.isNotEmpty
                      ? DecorationImage(
                          image: CachedNetworkImageProvider(bannerImage),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: bannerImage.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_photo_alternate,
                              color: Colors.white70,
                              size: 32,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Tap to add banner',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                    : null,
              ),
            ),
            // Gradient overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                  ],
                ),
              ),
            ),
            // Profile content
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  // Profile Picture - Full circle, not cropped
                  GestureDetector(
                    onTap: _changeProfilePicture,
                    child: Stack(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 15,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: profileImage.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: profileImage,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                                      ),
                                    ),
                                    errorWidget: (context, url, error) => _buildDefaultAvatar(displayName),
                                  )
                                : _buildDefaultAvatar(displayName),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Name and username
                  Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 22, // Reduced from 24
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black54,
                          offset: Offset(0, 2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '@$username',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                      shadows: [
                        Shadow(
                          color: Colors.black54,
                          offset: Offset(0, 1),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Edit Profile Button
            Positioned(
              top: 50,
              right: 16,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: IconButton(
                  onPressed: _showProfileMenu,
                  icon: const Icon(
                    Icons.more_vert,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultAvatar(String displayName) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF6366F1),
            Color(0xFF8B5CF6),
          ],
        ),
      ),
      child: Center(
        child: Text(
          displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
          style: const TextStyle(
            fontSize: 42, // Reduced from 48
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildStatsSection(int gamesPlayed, int reviewsWritten, int backlogCount, double averageRating) {
    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatItem('$gamesPlayed', 'Games', Icons.sports_esports),
          _buildStatDivider(),
          _buildStatItem('$reviewsWritten', 'Rated', Icons.star),
          _buildStatDivider(),
          _buildStatItem('$backlogCount', 'Backlog', Icons.bookmark_outline),
          _buildStatDivider(),
          _buildStatItem(averageRating.toStringAsFixed(1), 'Avg Rating', Icons.trending_up),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label, IconData icon) {
    final theme = Theme.of(context);
    
    return Column(
      children: [
        Icon(
          icon,
          color: theme.colorScheme.primary,
          size: 20,
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 18, // Reduced from 20
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildStatDivider() {
    final theme = Theme.of(context);
    
    return Container(
      height: 32,
      width: 1,
      color: theme.colorScheme.outline.withValues(alpha: 0.3),
    );
  }

  Widget _buildFavoriteGameSection() {
    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.favorite,
                color: Color(0xFFEC4899),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Favorite Game',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: _selectFavoriteGame,
                child: Text(
                  _favoriteGame == null ? 'Set Favorite' : 'Change',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_favoriteGame != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(
                      _favoriteGame!.coverImage,
                      width: 50,
                      height: 66,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 50,
                        height: 66,
                        color: theme.colorScheme.outline.withValues(alpha: 0.3),
                        child: Icon(
                          Icons.videogame_asset,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _favoriteGame!.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        if (_favoriteGame!.releaseDate.isNotEmpty)
                          Text(
                            _favoriteGame!.releaseDate,
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.star,
                              color: Color(0xFFFBBF24),
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _favoriteGame!.averageRating.toStringAsFixed(1),
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.videogame_asset,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    size: 40,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No favorite game selected',
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap "Set Favorite" to choose your favorite game',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlaylistsSection() {
    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.playlist_play,
                color: theme.colorScheme.secondary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Playlists',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              Text(
                '${_userPlaylists.length}',
                style: TextStyle(
                  color: theme.colorScheme.secondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Expandable playlists
          Column(
            children: _userPlaylists.map((playlist) => _buildPlaylistItem(playlist)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistItem(Map<String, dynamic> playlist) {
    final theme = Theme.of(context);
    final games = List<Map<String, dynamic>>.from(playlist['games'] ?? []);
    final playlistId = playlist['id'] ?? '';
    final isExpanded = _expandedPlaylists.contains(playlistId);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedPlaylists.remove(playlistId);
                } else {
                  _expandedPlaylists.add(playlistId);
                }
              });
            },
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(Icons.playlist_play,
                    color: theme.colorScheme.secondary,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(playlist['name'] ?? 'Unnamed Playlist',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      if ((playlist['description'] ?? '').isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(playlist['description'],
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                Text(
                  '${games.length} games',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.secondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  size: 18,
                ),
              ],
            ),
          ),
          // Show games based on expansion state
          if (games.isNotEmpty) ...[
            const SizedBox(height: 8),
            if (isExpanded) ...[
              // Expanded view - show games as a vertical list
              Column(
                children: games.take(3).map((game) => _buildPlaylistGameItem(game)).toList(),
              ),
              if (games.length > 3) ...[
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () => _navigateToLibraryPlaylist(playlistId),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'View all ${games.length} games',
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.secondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_ios,
                          color: theme.colorScheme.secondary,
                          size: 12,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ] else ...[
              // Collapsed view - show horizontal thumbnails
              SizedBox(
                height: 60,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: games.length > 5 ? 5 : games.length,
                  itemBuilder: (context, index) {
                    final game = games[index];
                    return Container(
                      width: 45,
                      margin: const EdgeInsets.only(right: 6),
                      child: Column(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: game['gameCoverImage']?.isNotEmpty == true
                                  ? CachedNetworkImage(
                                      imageUrl: game['gameCoverImage'],
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      placeholder: (context, url) => Container(
                                        color: theme.colorScheme.outline.withValues(alpha: 0.3),
                                        child: Icon(Icons.videogame_asset,
                                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                          size: 16,
                                        ),
                                      ),
                                      errorWidget: (context, url, error) => Container(
                                        color: theme.colorScheme.outline.withValues(alpha: 0.3),
                                        child: Icon(Icons.videogame_asset,
                                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                          size: 16,
                                        ),
                                      ),
                                    )
                                  : Container(
                                      color: theme.colorScheme.outline.withValues(alpha: 0.3),
                                      child: Icon(Icons.videogame_asset,
                                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                        size: 16,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            game['gameTitle'] ?? 'Unknown',
                            style: TextStyle(
                              fontSize: 8,
                              color: theme.colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              if (games.length > 5) ...[
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () => _navigateToLibraryPlaylist(playlistId),
                  child: Text(
                    '+${games.length - 5} more games',
                    style: TextStyle(
                      fontSize: 10,
                      color: theme.colorScheme.secondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ] else ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: theme.colorScheme.onSurface.withValues(alpha: 0.7), size: 14),
                  const SizedBox(width: 6),
                  Text(
                    'No games in this playlist yet',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlaylistGameItem(Map<String, dynamic> game) {
    final theme = Theme.of(context);
    final gameTitle = game['gameTitle'] ?? 'Unknown Game';
    final gameCoverImage = game['gameCoverImage'] ?? '';
    final gameDeveloper = game['gameDeveloper'] ?? 'Unknown Developer';
    final gameId = game['gameId'] ?? '';

    return GestureDetector(
      onTap: () {
        if (gameId.isNotEmpty) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => GameDetailScreen(
                gameId: gameId,
              ),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: gameCoverImage.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: gameCoverImage,
                      width: 35,
                      height: 50,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        width: 35,
                        height: 50,
                        color: theme.colorScheme.outline.withValues(alpha: 0.3),
                        child: Icon(Icons.videogame_asset,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          size: 16,
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: 35,
                        height: 50,
                        color: theme.colorScheme.outline.withValues(alpha: 0.3),
                        child: Icon(Icons.videogame_asset,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          size: 16,
                        ),
                      ),
                    )
                  : Container(
                      width: 35,
                      height: 50,
                      color: theme.colorScheme.outline.withValues(alpha: 0.3),
                      child: Icon(Icons.videogame_asset,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        size: 16,
                      ),
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    gameTitle,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    gameDeveloper,
                    style: TextStyle(
                      fontSize: 10,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              size: 12,
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  'Set Favorite',
                  Icons.star,
                  const Color(0xFFFBBF24),
                  _selectFavoriteGame,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildActionButton(
                  'Create Playlist',
                  Icons.playlist_add,
                  const Color(0xFF10B981),
                  _createPlaylist,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: _buildActionButton(
              'Friends',
              Icons.people,
              const Color(0xFF6366F1),
              () {
                // Navigate to friends screen
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const FriendsScreen(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.1),
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: color.withValues(alpha: 0.3)),
        ),
        elevation: 0,
      ),
    );
  }

  Widget _buildFriendsSection(int followers, int following) {
    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.people,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Social',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSocialStat('Followers', followers),
              ),
              Container(
                height: 32,
                width: 1,
                color: theme.colorScheme.outline.withValues(alpha: 0.3),
              ),
              Expanded(
                child: _buildSocialStat('Following', following),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSocialStat(String label, int count) {
    final theme = Theme.of(context);
    
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 18, // Reduced from 20
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}