import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/auth_user.dart';
import '../services/storage_service.dart';
import '../services/image_storage_service.dart';
import '../services/user_data_service.dart';

class FirebaseAuthService extends ChangeNotifier {
  static final FirebaseAuthService _instance = FirebaseAuthService._internal();
  factory FirebaseAuthService() => _instance;
  FirebaseAuthService._internal();
  static FirebaseAuthService get instance => _instance;

  FirebaseAuth? _firebaseAuth;
  AuthUser? _currentUser;
  bool _isLoading = false;
  String? _error;

  AuthUser? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _currentUser != null && _currentUser!.isEmailVerified;

  // Initialize auth service (Firebase already initialized in main.dart)
  Future<void> initialize() async {
    _setLoading(true);
    try {
      // Initialize FirebaseAuth (Firebase already initialized)
      _firebaseAuth = FirebaseAuth.instance;
      
      // Listen to auth state changes
      _firebaseAuth!.authStateChanges().listen(_onAuthStateChanged);
      
      // Check if user is already signed in
      final firebaseUser = _firebaseAuth!.currentUser;
      if (firebaseUser != null) {
        await _loadUserData(firebaseUser);
      }
    } catch (e) {
      _setError('Failed to initialize auth service: $e');
      // Error handled
    } finally {
      _setLoading(false);
    }
  }

  // Handle Firebase auth state changes
  Future<void> _onAuthStateChanged(User? firebaseUser) async {
    if (firebaseUser != null) {
      await _loadUserData(firebaseUser);
    } else {
      _currentUser = null;
      await StorageService.clearUser();
      notifyListeners();
    }
  }

  // Load user data from storage and sync with Firebase
  Future<void> _loadUserData(User firebaseUser) async {
    try {
      // Get user data from local storage
      final userData = await StorageService.getUserByEmail(firebaseUser.email!);
      
      if (userData != null) {
        // User exists in local storage
        _currentUser = AuthUser.fromJson(userData).copyWith(
          isEmailVerified: firebaseUser.emailVerified,
          lastLoginAt: DateTime.now(),
        );
      } else {
        // Create new user from Firebase data
        _currentUser = AuthUser(
          id: firebaseUser.uid,
          email: firebaseUser.email!,
          username: _generateUsername(firebaseUser.email!),
          displayName: firebaseUser.displayName ?? _generateDisplayName(firebaseUser.email!),
          createdAt: firebaseUser.metadata.creationTime ?? DateTime.now(),
          lastLoginAt: DateTime.now(),
          isEmailVerified: firebaseUser.emailVerified,
          preferences: UserPreferences(),
        );
      }

      // Load persisted images
      final profileImagePath = await ImageStorageService.getImagePath(
        userId: _currentUser!.id,
        isProfilePicture: true,
      );
      
      final bannerImagePath = await ImageStorageService.getImagePath(
        userId: _currentUser!.id,
        isProfilePicture: false,
      );

      // Load user data from Firestore (favorite game and playlists)
      final firestoreData = await UserDataService.getUserProfile(_currentUser!.id);
      
      String? favoriteGameId;
      String? favoriteGameName;
      String? favoriteGameImage;
      List<Map<String, dynamic>> playlists = [];

      if (firestoreData != null) {
        // Load favorite game from Firestore
        final favoriteGame = firestoreData['favoriteGame'] as Map<String, dynamic>?;
        if (favoriteGame != null) {
          favoriteGameId = favoriteGame['gameId'];
          favoriteGameName = favoriteGame['gameName'];
          favoriteGameImage = favoriteGame['gameImage'];
        }

        // Load playlists from Firestore
        playlists = await UserDataService.getUserPlaylists(_currentUser!.id);
      } else {
        // User doesn't exist in Firestore, create their profile
        await UserDataService.saveUserProfile(_currentUser!.id, {
          'id': _currentUser!.id,
          'username': _currentUser!.username,
          'displayName': _currentUser!.displayName,
          'email': _currentUser!.email,
          'bio': '',
          'profileImage': profileImagePath ?? '',
          'gamesPlayed': 0,
          'reviewsWritten': 0,
          'followers': 0,
          'following': 0,
          'joinDate': _currentUser!.createdAt.millisecondsSinceEpoch,
          'createdAt': _currentUser!.createdAt.millisecondsSinceEpoch,
          'lastActiveAt': DateTime.now().millisecondsSinceEpoch,
          'isOnline': true,
        });
        
        // Fallback to local storage for backward compatibility
        favoriteGameId = await StorageService.getFavoriteGame(_currentUser!.id);
        
        final playlistsData = await StorageService.getUserPlaylists(_currentUser!.id);
        final playlistObjects = playlistsData.map((data) => GamePlaylist(
          id: data['id'],
          name: data['name'],
          description: data['description'] ?? '',
          games: (data['games'] as List<dynamic>?)
              ?.map((gameData) => PlaylistGame(
                    gameId: gameData['gameId'],
                    gameName: gameData['gameName'],
                    gameImage: gameData['gameImage'],
                    addedAt: DateTime.parse(gameData['addedAt']),
                  ))
              .toList() ?? [],
          createdAt: DateTime.parse(data['createdAt']),
          updatedAt: DateTime.parse(data['updatedAt'] ?? data['createdAt']),
        )).toList();
        
        // Convert to List<Map<String, dynamic>> for compatibility
        playlists = playlistObjects.map((playlist) => {
          'id': playlist.id,
          'name': playlist.name,
          'description': playlist.description,
          'games': playlist.games.map((game) => {
            'gameId': game.gameId,
            'gameName': game.gameName,
            'gameImage': game.gameImage,
            'addedAt': game.addedAt.toIso8601String(),
          }).toList(),
          'createdAt': playlist.createdAt.toIso8601String(),
          'updatedAt': playlist.updatedAt.toIso8601String(),
        }).toList();
      }

      // Update user with persisted data if they exist
      _currentUser = _currentUser!.copyWith(
        profileImage: profileImagePath ?? _currentUser!.profileImage,
        bannerImage: bannerImagePath ?? _currentUser!.bannerImage,
        favoriteGameId: favoriteGameId ?? _currentUser!.favoriteGameId,
        favoriteGameName: favoriteGameName ?? _currentUser!.favoriteGameName,
        favoriteGameImage: favoriteGameImage ?? _currentUser!.favoriteGameImage,
        playlists: playlists.isNotEmpty ? playlists.map((data) => GamePlaylist(
          id: data['id'],
          name: data['name'],
          description: data['description'] ?? '',
          games: (data['games'] as List<dynamic>?)
              ?.map((gameData) => PlaylistGame(
                    gameId: gameData['gameId'],
                    gameName: gameData['gameName'],
                    gameImage: gameData['gameImage'],
                    addedAt: DateTime.parse(gameData['addedAt']),
                  ))
              .toList() ?? [],
          createdAt: DateTime.parse(data['createdAt']),
          updatedAt: DateTime.parse(data['updatedAt'] ?? data['createdAt']),
        )).toList() : _currentUser!.playlists,
      );

      // Save updated user data to local storage
      await StorageService.saveUser(_currentUser!);

      // Note: updateUserProfile method not available in FriendsService
      // This would need to be implemented if user profile search is needed

      notifyListeners();
    } catch (e) {
      _setError('Failed to load user data: $e');
      // Error handled
    }
  }

  // Register new user with Firebase
  Future<bool> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    if (_firebaseAuth == null) {
      return false;
    }
    
    _setLoading(true);
    _clearError();

    try {
      // Validate input
      if (!_isValidEmail(email)) {
        throw Exception('Invalid email format');
      }
      if (password.length < 6) {
        throw Exception('Password must be at least 6 characters');
      }
      if (displayName.length < 2) {
        throw Exception('Display name must be at least 2 characters');
      }

      // Create user with Firebase
      final credential = await _firebaseAuth!.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        // Update display name
        await credential.user!.updateDisplayName(displayName);
        
        // Send email verification
        await credential.user!.sendEmailVerification();
        
        // Create local user data
        final username = displayName.toLowerCase().replaceAll(' ', '_');
        final user = AuthUser(
          id: credential.user!.uid,
          email: email,
          username: username,
          displayName: displayName,
          createdAt: DateTime.now(),
          lastLoginAt: DateTime.now(),
          isEmailVerified: false, // Will be updated when verified
          preferences: UserPreferences(),
        );

        // Save to local storage
        await StorageService.saveUser(user);
        
        // Save to Firestore for other users to see
        await UserDataService.createOrUpdateUserProfile(
          userId: credential.user!.uid,
          username: username,
          displayName: displayName,
          email: email,
          bio: '',
          profileImageUrl: '',
          bannerImageUrl: '',
        );
        
        _currentUser = user;
        notifyListeners();
        
        return true;
      }
      
      return false;
    } on FirebaseAuthException catch (e) {
      _setError(_getFirebaseErrorMessage(e));
      return false;
    } catch (e) {
      _setError(e.toString());
      return false;
      // Error handled
    } finally {
      _setLoading(false);
    }
  }

  // Login user with Firebase
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    if (_firebaseAuth == null) {
      return false;
    }
    
    _setLoading(true);
    _clearError();

    try {
      final credential = await _firebaseAuth!.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        // User data will be loaded automatically via _onAuthStateChanged
        return true;
      }
      
      return false;
    } on FirebaseAuthException catch (e) {
      _setError(_getFirebaseErrorMessage(e));
      return false;
    } catch (e) {
      _setError(e.toString());
      return false;
      // Error handled
    } finally {
      _setLoading(false);
    }
  }

  // Send email verification
  Future<bool> sendEmailVerification() async {
    if (_firebaseAuth == null) {
      return false;
    }
    
    _setLoading(true);
    _clearError();

    try {
      final user = _firebaseAuth!.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        return true;
      }
      return false;
    } on FirebaseAuthException catch (e) {
      _setError(_getFirebaseErrorMessage(e));
      return false;
    } catch (e) {
      _setError(e.toString());
      return false;
      // Error handled
    } finally {
      _setLoading(false);
    }
  }

  // Check if email is verified and reload user
  Future<bool> checkEmailVerification() async {
    if (_firebaseAuth == null) {
      return false;
    }
    
    try {
      final user = _firebaseAuth!.currentUser;
      if (user != null) {
        await user.reload();
        final updatedUser = _firebaseAuth!.currentUser;
        
        if (updatedUser != null && updatedUser.emailVerified) {
          // Update local user data
          if (_currentUser != null) {
            _currentUser = _currentUser!.copyWith(
              isEmailVerified: true,
              lastLoginAt: DateTime.now(),
            );
            await StorageService.saveUser(_currentUser!);
            notifyListeners();
          }
          return true;
        }
      }
      return false;
    } catch (e) {
      _setError('Failed to check email verification: $e');
      return false;
      // Error handled
    }
  }

  // Send password reset email
  Future<bool> sendPasswordResetEmail(String email) async {
    if (_firebaseAuth == null) {
      return false;
    }
    
    _setLoading(true);
    _clearError();

    try {
      await _firebaseAuth!.sendPasswordResetEmail(email: email);
      return true;
    } on FirebaseAuthException catch (e) {
      _setError(_getFirebaseErrorMessage(e));
      return false;
    } catch (e) {
      _setError(e.toString());
      return false;
      // Error handled
    } finally {
      _setLoading(false);
    }
  }

  // Logout user
  Future<void> logout() async {
    if (_firebaseAuth == null) {
      return;
    }
    
    try {
      await _firebaseAuth!.signOut();
      // User data will be cleared automatically via _onAuthStateChanged
    } catch (e) {
      _setError('Failed to logout: $e');
      // Error handled
    }
  }

  // Update user profile
  Future<bool> updateProfile({
    String? displayName,
    String? bio,
    String? profileImage,
    String? bannerImage,
    String? favoriteGameId,
    String? favoriteGameName,
    String? favoriteGameImage,
    List<GamePlaylist>? playlists,
    UserPreferences? preferences,
  }) async {
    if (_currentUser == null || _firebaseAuth == null) {
      return false;
    }

                                    _setLoading(true);
    _clearError();

    try {
      // Update Firebase profile if display name changed
      if (displayName != null && displayName != _currentUser!.displayName) {
        await _firebaseAuth!.currentUser?.updateDisplayName(displayName);
      }

      // Update local user data
      final updatedUser = _currentUser!.copyWith(
        displayName: displayName ?? _currentUser!.displayName,
        bio: bio ?? _currentUser!.bio,
        profileImage: profileImage ?? _currentUser!.profileImage,
        bannerImage: bannerImage ?? _currentUser!.bannerImage,
        favoriteGameId: favoriteGameId ?? _currentUser!.favoriteGameId,
        favoriteGameName: favoriteGameName ?? _currentUser!.favoriteGameName,
        favoriteGameImage: favoriteGameImage ?? _currentUser!.favoriteGameImage,
        playlists: playlists ?? _currentUser!.playlists,
        preferences: preferences ?? _currentUser!.preferences,
      );

      // Save to Firestore
      Map<String, dynamic>? favoriteGameData;
      if (favoriteGameId != null || favoriteGameName != null || favoriteGameImage != null) {
        favoriteGameData = {
          'gameId': favoriteGameId ?? updatedUser.favoriteGameId,
          'gameName': favoriteGameName ?? updatedUser.favoriteGameName,
          'gameImage': favoriteGameImage ?? updatedUser.favoriteGameImage,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        };
      }

      await UserDataService.createOrUpdateUserProfile(
        userId: updatedUser.id,
        displayName: displayName,
        bio: bio,
        profileImageUrl: profileImage,
        bannerImageUrl: bannerImage,
        favoriteGame: favoriteGameData,
        playlists: playlists?.map((playlist) => {
          'id': playlist.id,
          'name': playlist.name,
          'description': playlist.description,
          'games': playlist.games.map((game) => {
            'gameId': game.gameId,
            'gameName': game.gameName,
            'gameImage': game.gameImage,
            'addedAt': game.addedAt.toIso8601String(),
          }).toList(),
          'createdAt': playlist.createdAt.toIso8601String(),
          'updatedAt': playlist.updatedAt.toIso8601String(),
        }).toList(),
      );

      // Save to local storage for backward compatibility
      await StorageService.saveUser(updatedUser);
      
      // Save favorite game to local storage if provided
      if (favoriteGameId != null) {
        await StorageService.saveFavoriteGame(updatedUser.id, favoriteGameId);
      }
      
      // Save playlists to local storage if provided
      if (playlists != null) {
        final playlistsData = playlists.map((playlist) => {
          'id': playlist.id,
          'name': playlist.name,
          'description': playlist.description,
          'games': playlist.games.map((game) => {
            'gameId': game.gameId,
            'gameName': game.gameName,
            'gameImage': game.gameImage,
            'addedAt': game.addedAt.toIso8601String(),
          }).toList(),
          'createdAt': playlist.createdAt.toIso8601String(),
          'updatedAt': playlist.updatedAt.toIso8601String(),
        }).toList();
        await StorageService.saveUserPlaylists(updatedUser.id, playlistsData);
      }

      _currentUser = updatedUser;
      
      // Note: updateUserProfile method not available in FriendsService
      // This would need to be implemented if user profile search is needed
      
      notifyListeners();
      return true;
    } catch (e) {
      if (kDebugMode) {
                // Error handled
    }
      _setError('Failed to update profile: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Force refresh user data from storage
  Future<void> refreshUserData() async {
    if (_firebaseAuth?.currentUser != null) {
      await _loadUserData(_firebaseAuth!.currentUser!);
    }
  }

  // Private helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  String _generateUsername(String email) {
    return email.split('@')[0].toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '_');
  }

  String _generateDisplayName(String email) {
    final username = email.split('@')[0];
    return username.split('.').map((part) => 
      part.isNotEmpty ? part[0].toUpperCase() + part.substring(1) : part
    ).join(' ');
  }

  String _getFirebaseErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'email-already-in-use':
        return 'An account already exists for this email.';
      case 'user-not-found':
        return 'No user found for this email.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'too-many-requests':
        return 'Too many requests. Try again later.';
      case 'operation-not-allowed':
        return 'Email/password accounts are not enabled.';
      default:
        return e.message ?? 'An error occurred during authentication.';
    }
  }
}


