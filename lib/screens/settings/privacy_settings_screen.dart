import 'package:flutter/material.dart';

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  bool _profileVisible = true;
  bool _activityVisible = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            SwitchListTile(
              title: const Text('Profile Visible'),
              value: _profileVisible,
              onChanged: (value) {
                setState(() {
                  _profileVisible = value;
                });
              },
            ),
            SwitchListTile(
              title: const Text('Activity Visible'),
              value: _activityVisible,
              onChanged: (value) {
                setState(() {
                  _activityVisible = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}



