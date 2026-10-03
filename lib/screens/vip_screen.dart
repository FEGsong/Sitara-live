import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Placeholder for now — VIP tiers/perks to be added later.
class VipScreen extends StatelessWidget {
  const VipScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(title: const Text('VIP')),
      body: const Center(
        child: Text('VIP — coming soon', style: TextStyle(color: AppColors.muted)),
      ),
    );
  }
}
