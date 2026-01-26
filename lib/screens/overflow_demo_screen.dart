import 'package:flutter/material.dart';

class OverflowDemoScreen extends StatelessWidget {
  const OverflowDemoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Overflow Demo'),
      ),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 20),
            const Text('Overflow handling examples will go here'),
          ],
        ),
      ),
    );
  }
}



