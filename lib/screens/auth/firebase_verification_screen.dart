import 'package:flutter/material.dart';
import 'dart:async';
import '../../services/firebase_auth_service.dart';
import '../main_screen.dart';

class FirebaseVerificationScreen extends StatefulWidget {
  final String email;
  
  const FirebaseVerificationScreen({
    super.key,
    required this.email,
  });

  @override
  State<FirebaseVerificationScreen> createState() => _FirebaseVerificationScreenState();
}

class _FirebaseVerificationScreenState extends State<FirebaseVerificationScreen> 
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _isCheckingVerification = false;
  Timer? _verificationTimer;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic));
    
    _animationController.forward();
    _startVerificationCheck();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _verificationTimer?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startVerificationCheck() {
    // Check for email verification every 3 seconds
    _verificationTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!_isCheckingVerification) {
        _checkEmailVerification();
      }
    });
  }

  Future<void> _checkEmailVerification() async {
    if (!mounted) {
      return;
    }
    
    setState(() => _isCheckingVerification = true);
    
    final isVerified = await FirebaseAuthService().checkEmailVerification();
    
    if (mounted) {
      setState(() => _isCheckingVerification = false);
      
      if (isVerified) {
        _verificationTimer?.cancel();
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email verified successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        
        // Navigate to main screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MainScreen()),
        );
      }
    }
  }

  Future<void> _resendVerification() async {
    if (_resendCooldown > 0) {
      return;
    }
    
    final success = await FirebaseAuthService().sendEmailVerification();
    
    if (mounted) {
      if (success) {
        // Start cooldown
        setState(() => _resendCooldown = 60);
        _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (mounted) {
            setState(() {
              _resendCooldown--;
              if (_resendCooldown <= 0) {
                timer.cancel();
              }
            });
          } else {
            timer.cancel();
          }
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification email sent!'),
            backgroundColor: Color(0xFF8B5CF6),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(FirebaseAuthService().error ?? 'Failed to send verification email'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topRight,
            radius: 1.5,
            colors: [
              Color(0xFF1F2937),
              Color(0xFF111827),
              Color(0xFF000000),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Back button
                Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_ios,
                      color: Colors.white,
                    ),
                  ),
                ),
                
                Expanded(
                  child: Stack(
                    children: [
                      // Floating elements
                      _buildFloatingElement(
                        top: 50,
                        right: 30,
                        color: const Color(0xFF8B5CF6),
                        size: 60,
                      ),
                      _buildFloatingElement(
                        top: 120,
                        left: 40,
                        color: const Color(0xFF06D6A0),
                        size: 40,
                      ),
                      _buildFloatingElement(
                        top: 200,
                        right: 80,
                        color: const Color(0xFFF59E0B),
                        size: 30,
                      ),
                      
                      // Main content
                      Center(
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: FadeTransition(
                            opacity: _fadeAnimation,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Email icon
                                Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(Icons.email_outlined,
                                    size: 60,
                                    color: const Color(0xFF8B5CF6),
                                  ),
                                ),
                                const SizedBox(height: 32),
                                
                                // Title
                                const Text(
                                  'Check Your Email',
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                
                                // Subtitle
                                Text(
                                  'We sent a verification link to\n${widget.email}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                    height: 1.5,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                
                                // Instructions
                                const Text(
                                  'Click the link in your email to verify your account.\nWe\'ll automatically detect when you\'ve verified.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                    height: 1.5,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 40),
                                
                                // Checking status
                                if (_isCheckingVerification) ...[
                                  const Column(
                                    children: [
                                      CircularProgressIndicator(
                                        valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFF8B5CF6)),
                                      ),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'Checking verification status...',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                
                                const SizedBox(height: 40),
                                
                                // Manual check button
                                Container(
                                  width: double.infinity,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [const Color(0xFF8B5CF6), const Color(0xFF6366F1)],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                                        blurRadius: 20,
                                        offset: const Offset(0, 10),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    onPressed: _isCheckingVerification ? null : _checkEmailVerification,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: const Text(
                                      'I\'ve Verified My Email',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                
                                // Resend email
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text(
                                      'Didn\'t receive the email? ',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 16,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: _resendCooldown > 0 ? null : _resendVerification,
                                      child: Text(
                                        _resendCooldown > 0 
                                          ? 'Resend in $_resendCooldown'
                                          : 'Resend Email',
                                        style: TextStyle(
                                          color: _resendCooldown > 0 
                                            ? Colors.grey 
                                            : const Color(0xFF8B5CF6),
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                
                                // Tips
                                Container(
                                  padding: EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1F2937).withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.grey.withValues(alpha: 0.2),
                                    ),
                                  ),
                                  child: const Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        '💡 Tips:',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      const Text(
                                        '• Check your spam/junk folder\n• Make sure you clicked the link in the email\n• The verification happens automatically',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 14,
                                          height: 1.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingElement({
    required double top,
    double? left,
    double? right,
    required Color color,
    required double size,
  }) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      child: TweenAnimationBuilder<double>(
        duration: Duration(milliseconds: 2000 + (size * 10).round()),
        tween: Tween(begin: 0.0, end: 1.0),
        builder: (context, value, child) {
          return Transform.translate(
            offset: Offset(0, -10 * value),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.3),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.2),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}


