import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:gamelog/firebase_options.dart';

/// Script to initialize the super admin system
/// This should be run once to set up petrichorvibe69 as the super admin
void main() async {
  print('🚀 Initializing GameLog Super Admin System...');
  
  try {
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    final firestore = FirebaseFirestore.instance;
    const superAdminUsername = 'petrichorvibe69';
    
    print('🔍 Searching for user: $superAdminUsername');
    
    // Find the super admin user by username
    final usersQuery = await firestore
        .collection('users')
        .where('username', isEqualTo: superAdminUsername)
        .limit(1)
        .get();

    if (usersQuery.docs.isEmpty) {
      print('❌ Super admin user $superAdminUsername not found');
      print('   Please make sure the user has registered with this username first.');
      return;
    }

    final superAdminUserId = usersQuery.docs.first.id;
    final userData = usersQuery.docs.first.data();
    
    print('✅ Found super admin user:');
    print('   User ID: $superAdminUserId');
    print('   Username: ${userData['username']}');
    print('   Display Name: ${userData['displayName'] ?? 'Not set'}');
    print('   Email: ${userData['email'] ?? 'Not set'}');
    
    // Initialize the admin system
    await firestore
        .collection('admins')
        .doc('list')
        .set({
      'adminIds': [superAdminUserId],
      'superAdminId': superAdminUserId,
      'superAdminUsername': superAdminUsername,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
      'initializedBy': 'system_script',
    });

    print('✅ Super admin system initialized successfully!');
    print('');
    print('🎉 $superAdminUsername is now the super admin and can:');
    print('   • Access the admin app');
    print('   • Add/remove other administrators');
    print('   • Moderate all community content');
    print('   • View admin statistics and reports');
    print('');
    print('📱 Next steps:');
    print('   1. Build the admin APK: run build_admin_apk.bat');
    print('   2. Install admin APK on admin devices only');
    print('   3. Install regular APK on user devices');
    
  } catch (e) {
    print('❌ Error initializing super admin system: $e');
  }
}