import 'package:flutter/material.dart';

/// Small blue checkmark shown next to a verified/official account's
/// name — used on profile, public profile, and posts.
class VerifiedBadge extends StatelessWidget {
  final double size;
  const VerifiedBadge({super.key, this.size = 14});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      margin: const EdgeInsets.only(left: 4),
      decoration: const BoxDecoration(
        color: Color(0xFF1DA1F2),
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.check, size: size * 0.7, color: Colors.white),
    );
  }
}
