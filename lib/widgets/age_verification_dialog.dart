import 'package:flutter/material.dart';
import '../services/content_filter_service.dart';

class AgeVerificationDialog extends StatefulWidget {
  final VoidCallback? onVerified;
  
  const AgeVerificationDialog({
    super.key,
    this.onVerified,
  });

  @override
  State<AgeVerificationDialog> createState() => _AgeVerificationDialogState();

  static Future<bool?> showAgeVerification(BuildContext context, {VoidCallback? onVerified}) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AgeVerificationDialog(onVerified: onVerified),
    );
  }
}

class _AgeVerificationDialogState extends State<AgeVerificationDialog> {
  bool _isVerifying = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1F2937),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: const Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Color(0xFFF59E0B),
            size: 24,
          ),
          SizedBox(width: 8),
          Text(
            'Age Verification',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Adult Content Warning',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'You are about to enable access to mature content that may include:',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('• Violence and Gore', style: TextStyle(color: Colors.grey, fontSize: 13)),
              Text('• Sexual Content and Nudity', style: TextStyle(color: Colors.grey, fontSize: 13)),
              Text('• Strong Language', style: TextStyle(color: Colors.grey, fontSize: 13)),
              Text('• Mature Themes', style: TextStyle(color: Colors.grey, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF374151),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFF59E0B), width: 1),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Color(0xFFF59E0B),
                  size: 16,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'You must be 18 years or older to access this content.',
                    style: TextStyle(
                      color: Color(0xFFF59E0B),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Are you 18 years of age or older?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isVerifying ? null : () => Navigator.of(context).pop(false),
          child: const Text(
            'No, I am under 18',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: _isVerifying ? null : _verifyAge,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF59E0B),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: _isVerifying
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text(
                  'Yes, I am 18+',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ],
    );
  }

  Future<void> _verifyAge() async {
    setState(() => _isVerifying = true);
    
    try {
      await ContentFilterService.instance.verifyAge();
      await ContentFilterService.instance.enableAdultContent();
      
      if (mounted) {
        Navigator.of(context).pop(true);
        widget.onVerified?.call();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Adult content enabled. You can disable this in Settings.'),
            backgroundColor: Color(0xFFF59E0B),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isVerifying = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}