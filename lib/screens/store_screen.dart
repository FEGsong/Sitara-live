import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Placeholder for now — content to be added later.
class StoreScreen extends StatelessWidget {
  const StoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(title: const Text('Store')),
      body: const Center(
        child: Text('Store — coming soon', style: TextStyle(color: AppColors.muted)),
      ),
    );
  }
}
