// Simple test to check authentication
import 'lib/services/firebase_auth_service.dart';

void main() {
  print('🔍 Testing Authentication...');
  
  final authService = FirebaseAuthService();
  final currentUser = authService.currentUser;
  
  if (currentUser == null) {
    print('❌ No user authenticated');
    print('   Please make sure you are logged in to the app');
  } else {
    print('✅ User authenticated:');
    print('   ID: ${currentUser.id}');
    print('   Email: ${currentUser.email}');
    print('   Username: ${currentUser.username}');
    print('   Email Verified: ${currentUser.isEmailVerified}');
  }
}