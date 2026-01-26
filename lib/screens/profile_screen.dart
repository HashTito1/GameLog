import 'package:flutter/material.dart';
import '../services/firebase_auth_service.dart';
import '../services/user_data_service.dart';
import 'user_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String userId;
  
  const ProfileScreen({super.key, required this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = false;
  Map<String, dynamic>? _userData;

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
        setState(() {
          _userData = userData;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Error loading profile data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuthService.instance.currentUser;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: const Color(0xFF1F2937),
      ),
      backgroundColor: const Color(0xFF111827),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  if (currentUser != null) ...[
                    Text(
                      'Current User: ${currentUser.email}',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    Text(
                      'User ID: ${currentUser.uid}',
                      style: const TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Firestore Data: ${_userData != null ? 'Found' : 'Not Found'}',
                      style: TextStyle(
                        color: _userData != null ? Colors.green : Colors.red,
                        fontSize: 16,
                      ),
                    ),
                    if (_userData != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Username: ${_userData!['username'] ?? 'N/A'}',
                        style: const TextStyle(color: Colors.white),
                      ),
                      Text(
                        'Display Name: ${_userData!['displayName'] ?? 'N/A'}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                    const SizedBox(height: 30),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => UserProfileScreen(userId: currentUser.uid),
                          ),
                        );
                      },
                      child: const Text('View Full Profile'),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: _loadData,
                      child: const Text('Refresh Data'),
                    ),
                  ] else ...[
                    const Text(
                      'No user logged in',
                      style: TextStyle(color: Colors.red, fontSize: 16),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}



