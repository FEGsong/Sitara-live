import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Placeholder for now — content to be added later.
class BagScreen extends StatelessWidget {
  const BagScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(title: const Text('Bag')),
      body: const Center(
        child: Text('Bag — coming soon', style: TextStyle(color: AppColors.muted)),
      ),
    );
  }
}
