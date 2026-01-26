import 'package:flutter/material.dart';

class ProfilePictureViewer extends StatelessWidget {
  final String? imageUrl;
  final double size;
  final VoidCallback? onTap;

  const ProfilePictureViewer({
    super.key,
    this.imageUrl,
    this.size = 100,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFFE5E7EB),
        ),
        child: imageUrl != null
            ? ClipOval(
                child: Image.network(
                  imageUrl!,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.person,
                      size: size * 0.6,
                      color: Color(0xFF9CA3AF),
                    );
                  },
                ),
              )
            : Icon(
                Icons.person,
                size: size * 0.6,
                color: Color(0xFF9CA3AF),
              ),
      ),
    );
  }
}



