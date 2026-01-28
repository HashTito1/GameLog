import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class StarRatingWidget extends StatelessWidget {
  final double rating;
  final Function(double)? onRatingChanged;
  final double size;
  final bool interactive;
  final Color activeColor;
  final Color inactiveColor;

  const StarRatingWidget({
    super.key,
    required this.rating,
    this.onRatingChanged,
    this.size = 24.0,
    this.interactive = false,
    this.activeColor = const Color(0xFF10B981), // Green color like in reference
    this.inactiveColor = const Color(0xFF374151), // Darker gray for better contrast
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        if (interactive && onRatingChanged != null) {
          return GestureDetector(
            onTapDown: (details) {
              // Calculate which half of the star was tapped
              final RenderBox box = context.findRenderObject() as RenderBox;
              final localPosition = box.globalToLocal(details.globalPosition);
              
              // Get the star's position and width
              final starWidth = size + 4; // size + padding
              final starCenterX = (index * starWidth) + (starWidth / 2);
              
              HapticFeedback.selectionClick();
              
              // If tap is on left half of star, set to .5, if on right half, set to full
              if (localPosition.dx < starCenterX) {
                onRatingChanged!(index + 0.5);
              } else {
                onRatingChanged!((index + 1).toDouble());
              }
            },
            child: Container(
              width: size + 4,
              height: size + 4,
              padding: const EdgeInsets.all(2),
              child: _buildStar(index),
            ),
          );
        } else {
          return Container(
            width: size + 4,
            height: size + 4,
            padding: const EdgeInsets.all(2),
            child: _buildStar(index),
          );
        }
      }),
    );
  }

  Widget _buildStar(int index) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Background star (empty)
        Icon(
          Icons.star,
          size: size,
          color: inactiveColor,
        ),
        // Full star overlay - only show if rating is >= index + 1
        if (rating >= index + 1)
          Icon(
            Icons.star,
            size: size,
            color: activeColor,
          ),
        // Half star overlay - only show if rating is exactly index + 0.5
        if (rating == index + 0.5)
          ClipRect(
            clipper: HalfStarClipper(),
            child: Icon(
              Icons.star,
              size: size,
              color: activeColor,
            ),
          ),
      ],
    );
  }
}

// Custom clipper for half stars
class HalfStarClipper extends CustomClipper<Rect> {
  @override
  Rect getClip(Size size) {
    return Rect.fromLTRB(0, 0, size.width / 2, size.height);
  }

  @override
  bool shouldReclip(CustomClipper<Rect> oldClipper) => false;
}