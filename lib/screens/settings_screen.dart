import 'package:flutter/material.dart';
import '../services/firebase_auth_service.dart';
import '../services/content_filter_service.dart';
import '../widgets/age_verification_dialog.dart';
import 'settings/privacy_settings_screen.dart';
import 'settings/notification_settings_screen.dart';
import 'settings/theme_settings_screen.dart';
import 'settings/help_support_screen.dart';
import 'settings/about_screen.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback? onNavigateToProfile;
  
  const SettingsScreen({super.key, this.onNavigateToProfile});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _adultContentEnabled = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final adultContentEnabled = await ContentFilterService.instance.isAdultContentEnabled();
      setState(() {
        _adultContentEnabled = adultContentEnabled;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(theme),
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(12),
                      children: [
                        _buildSettingsSection(
                          title: 'Account',
                          children: [
                            _buildSettingsTile(
                              icon: Icons.person_outline,
                              title: 'Profile Settings',
                              subtitle: 'Edit your profile information',
                              onTap: () {
                                if (widget.onNavigateToProfile != null) {
                                  widget.onNavigateToProfile!();
                                }
                              },
                              theme: theme,
                            ),
                            _buildSettingsTile(
                              icon: Icons.security,
                              title: 'Privacy & Security',
                              subtitle: 'Manage your privacy settings',
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => const PrivacySettingsScreen(),
                                  ),
                                );
                              },
                              theme: theme,
                            ),
                          ],
                          theme: theme,
                        ),
                        const SizedBox(height: 16),
                        _buildSettingsSection(
                          title: 'Content',
                          children: [
                            _buildAdultContentToggle(theme),
                          ],
                          theme: theme,
                        ),
                        const SizedBox(height: 16),
                        _buildSettingsSection(
                          title: 'Preferences',
                          children: [
                            _buildSettingsTile(
                              icon: Icons.notifications_outlined,
                              title: 'Notifications',
                              subtitle: 'Configure notification preferences',
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => const NotificationSettingsScreen(),
                                  ),
                                );
                              },
                              theme: theme,
                            ),
                            _buildSettingsTile(
                              icon: Icons.palette_outlined,
                              title: 'Theme',
                              subtitle: 'Customize app appearance',
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => const ThemeSettingsScreen(),
                                  ),
                                );
                              },
                              theme: theme,
                            ),
                          ],
                          theme: theme,
                        ),
                        const SizedBox(height: 16),
                        _buildSettingsSection(
                          title: 'Support',
                          children: [
                            _buildSettingsTile(
                              icon: Icons.help_outline,
                              title: 'Help & Support',
                              subtitle: 'Get help and contact support',
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => const HelpSupportScreen(),
                                  ),
                                );
                              },
                              theme: theme,
                            ),
                            _buildSettingsTile(
                              icon: Icons.info_outline,
                              title: 'About',
                              subtitle: 'App version and information',
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => const AboutScreen(),
                                  ),
                                );
                              },
                              theme: theme,
                            ),
                          ],
                          theme: theme,
                        ),
                        const SizedBox(height: 24),
                        _buildLogoutButton(context, theme),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Text(
            'Settings',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildSettingsSection({
    required String title,
    required List<Widget> children,
    required ThemeData theme,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildAdultContentToggle(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFF59E0B),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '18+ Content',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _adultContentEnabled 
                      ? 'Adult content is visible' 
                      : 'Adult content is filtered',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _adultContentEnabled,
            onChanged: _toggleAdultContent,
            activeThumbColor: const Color(0xFFF59E0B),
            inactiveThumbColor: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            inactiveTrackColor: theme.colorScheme.outline.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleAdultContent(bool value) async {
    if (value) {
      // Enabling adult content - require age verification
      final isAgeVerified = await ContentFilterService.instance.isAgeVerified();
      
      if (!isAgeVerified) {
        // Show age verification dialog
        final verified = await AgeVerificationDialog.showAgeVerification(
          context,
          onVerified: () {
            setState(() => _adultContentEnabled = true);
          },
        );
        
        if (verified != true) {
          return; // User didn't verify age
        }
      } else {
        // Age already verified, just enable
        await ContentFilterService.instance.enableAdultContent();
        setState(() => _adultContentEnabled = true);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Adult content enabled'),
              backgroundColor: Color(0xFFF59E0B),
            ),
          );
        }
      }
    } else {
      // Disabling adult content
      await ContentFilterService.instance.disableAdultContent();
      setState(() => _adultContentEnabled = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Adult content disabled'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required ThemeData theme,
    bool enabled = true,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: enabled ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.5),
        size: 22,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: enabled ? theme.colorScheme.onSurface : theme.colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: enabled ? theme.colorScheme.onSurface.withValues(alpha: 0.6) : theme.colorScheme.onSurface.withValues(alpha: 0.4),
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: enabled ? theme.colorScheme.onSurface.withValues(alpha: 0.6) : theme.colorScheme.onSurface.withValues(alpha: 0.4),
        size: 20,
      ),
      onTap: enabled ? onTap : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  Widget _buildLogoutButton(BuildContext context, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: ElevatedButton(
        onPressed: () async {
          final shouldLogout = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: theme.colorScheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text('Logout', style: TextStyle(color: theme.colorScheme.onSurface)),
              content: Text(
                'Are you sure you want to logout?',
                style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text('Cancel', style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.7))),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Logout', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );

          if (shouldLogout == true && mounted) {
            await FirebaseAuthService().logout();
            // Auto-close settings screen after logout
            if (mounted) {
              Navigator.of(context).pop();
            }
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red.withValues(alpha: 0.1),
          foregroundColor: Colors.red,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: BorderSide(color: Colors.red.withValues(alpha: 0.3)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout, size: 18),
            SizedBox(width: 8),
            Text('Logout', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}


