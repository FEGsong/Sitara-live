import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Placeholder for now — content to be added later.
class RewardScreen extends StatelessWidget {
  const RewardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(title: const Text('Reward')),
      body: const Center(
        child: Text('Reward — coming soon', style: TextStyle(color: AppColors.muted)),
      ),
    );
  }
}
