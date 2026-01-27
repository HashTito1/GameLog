import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'About',
          style: TextStyle(fontSize: 18),
        ),
        backgroundColor: const Color(0xFF1F2937),
        elevation: 0,
        toolbarHeight: 50,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildAppInfo(),
          const SizedBox(height: 24),
          _buildSection(
            title: 'App Information',
            children: [
              _buildInfoTile('Version', '1.0.0'),
              _buildInfoTile('Build Number', '1'),
              _buildInfoTile('Release Date', 'January 2025'),
              _buildInfoTile('Platform', 'Flutter'),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: 'Legal',
            children: [
              _buildActionTile(
                title: 'Terms of Service',
                onTap: () => _showComingSoonDialog(context, 'Terms of Service'),
              ),
              _buildActionTile(
                title: 'Privacy Policy',
                onTap: () => _showComingSoonDialog(context, 'Privacy Policy'),
              ),
              _buildActionTile(
                title: 'Open Source Licenses',
                onTap: () => _showLicensePage(context),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: 'Connect',
            children: [
              _buildActionTile(
                title: 'Website',
                subtitle: 'Visit our website',
                onTap: () => _showComingSoonDialog(context, 'Website'),
              ),
              _buildActionTile(
                title: 'Social Media',
                subtitle: 'Follow us for updates',
                onTap: () => _showComingSoonDialog(context, 'Social Media'),
              ),
              _buildActionTile(
                title: 'Rate the App',
                subtitle: 'Help us improve',
                onTap: () => _showComingSoonDialog(context, 'App Rating'),
              ),
            ],
          ),
          const SizedBox(height: 32),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildAppInfo() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.videogame_asset,
              color: Colors.white,
              size: 40,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'GameLog',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Track, rate, and discover your favorite games',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF9CA3AF), // Using hex color instead of Colors.grey.shade400
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSection({required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1F2937),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildInfoTile(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(value,
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      title: Text(title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
      ),
      subtitle: subtitle != null
          ? Text(subtitle,
              style: const TextStyle(color: Colors.grey),
            )
          : null,
      trailing: const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF), size: 20),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  Widget _buildFooter() {
    return const Column(
      children: [
        Text(
          '© 2025 GameLog. All rights reserved.',
          style: TextStyle(
            fontSize: 12,
            color: Color(0xFF6B7280), // Using hex color instead of Colors.grey.shade600
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 8),
        Text(
          'Made with ❤️ for gamers',
          style: TextStyle(
            fontSize: 12,
            color: Color(0xFF6B7280), // Using hex color instead of Colors.grey.shade600
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  void _showLicensePage(BuildContext context) {
    showLicensePage(
      context: context,
      applicationName: 'GameLog',
      applicationVersion: '1.0.0',
      applicationIcon: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFF6366F1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.videogame_asset,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }

  static void _showComingSoonDialog(BuildContext context, String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Coming Soon', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This feature is currently under development and will be available in a future update.',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK', style: TextStyle(color: Color(0xFF6366F1))),
          ),
        ],
      ),
    );
  }
}


