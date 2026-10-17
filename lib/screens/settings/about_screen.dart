import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/update_service.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  bool _isCheckingForUpdates = false;
  Map<String, String> _versionInfo = {};

  @override
  void initState() {
    super.initState();
    _loadVersionInfo();
  }

  Future<void> _loadVersionInfo() async {
    final versionInfo = await UpdateService.instance.getCurrentVersionInfo();
    if (mounted) {
      setState(() {
        _versionInfo = versionInfo;
      });
    }
  }

  Future<void> _checkForUpdates() async {
    if (_isCheckingForUpdates) return;
    setState(() => _isCheckingForUpdates = true);

    final updateInfo = await UpdateService.instance.checkForUpdates();
    if (!mounted) return;
    setState(() => _isCheckingForUpdates = false);

    if (updateInfo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't reach GitHub. Check your connection and try again.")),
      );
    } else if (updateInfo.isUpdateAvailable) {
      await UpdateService.instance.showUpdateDialog(context, updateInfo);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("You're on the latest version (${_versionInfo['version'] ?? ''}).")),
      );
    }
  }

  Future<void> _open(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open link')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'About',
          style: TextStyle(fontSize: 18, color: theme.colorScheme.onSurface),
        ),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        toolbarHeight: 50,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildAppInfo(theme),
          const SizedBox(height: 24),
          _buildSection(
            title: 'App Information',
            theme: theme,
            children: [
              _buildInfoTile('Version', _versionInfo['version'] ?? '', theme),
              _buildInfoTile('Build Number', _versionInfo['buildNumber'] ?? '', theme),
              _buildUpdateTile(theme),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: 'More',
            theme: theme,
            children: [
              _buildActionTile(
                title: 'Release notes',
                subtitle: 'Every version and what changed',
                onTap: () => UpdateService.instance.openReleasesPage(),
                theme: theme,
              ),
              _buildActionTile(
                title: 'Source code',
                subtitle: 'GameLog on GitHub',
                onTap: () => _open('https://github.com/HashTito1/GameLog'),
                theme: theme,
              ),
              _buildActionTile(
                title: 'Send feedback',
                subtitle: 'Report a bug or suggest a feature',
                onTap: () => _open('mailto:nebilmesfin22@gmail.com?subject=GameLog%20feedback'),
                theme: theme,
              ),
              _buildActionTile(
                title: 'Open source licenses',
                onTap: () => _showLicensePage(context),
                theme: theme,
              ),
            ],
          ),
          const SizedBox(height: 32),
          _buildFooter(theme),
        ],
      ),
    );
  }

  Widget _buildAppInfo(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.videogame_asset,
              color: Colors.white,
              size: 40,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'GameLog',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Track, rate, and discover your favorite games',
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSection({required String title, required List<Widget> children, required ThemeData theme}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text(title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              for (int i = 0; i < children.length; i++) ...[
                children[i],
                if (i < children.length - 1)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    height: 0.5,
                    color: theme.colorScheme.outline.withValues(alpha: 0.3),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoTile(String title, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpdateTile(ThemeData theme) {
    // Make entire row tappable for better UX
    return InkWell(
      onTap: _isCheckingForUpdates ? null : _checkForUpdates,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                _isCheckingForUpdates ? Icons.refresh : Icons.system_update,
                color: theme.colorScheme.primary,
                size: 16,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Check for Updates',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _isCheckingForUpdates ? theme.colorScheme.onSurface.withValues(alpha: 0.6) : theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Look for a newer version of GameLog',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            if (_isCheckingForUpdates)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                ),
              )
            else
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                size: 16,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    return ListTile(
      title: Text(title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: theme.colorScheme.onSurface,
        ),
      ),
      subtitle: subtitle != null
          ? Text(subtitle,
              style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 12),
            )
          : null,
      trailing: Icon(Icons.chevron_right, color: theme.colorScheme.onSurface.withValues(alpha: 0.5), size: 20),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }

  Widget _buildFooter(ThemeData theme) {
    return Column(
      children: [
        Text(
          '© ${DateTime.now().year} GameLog',
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Made with ❤️ for gamers',
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
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
      applicationVersion: _versionInfo['version'],
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
}


