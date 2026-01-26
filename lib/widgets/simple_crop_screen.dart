import 'package:flutter/material.dart';

class SimpleCropScreen extends StatefulWidget {
  final String imagePath;

  const SimpleCropScreen({
    super.key,
    required this.imagePath,
  });

  @override
  State<SimpleCropScreen> createState() => _SimpleCropScreenState();
}

class _SimpleCropScreenState extends State<SimpleCropScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crop Image'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context, widget.imagePath);
            },
            child: const Text('Done'),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Image cropping functionality'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, widget.imagePath);
              },
              child: const Text('Use Original'),
            ),
          ],
        ),
      ),
    );
  }
}



