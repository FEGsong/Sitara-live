import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Placeholder for now — SVIP tiers/perks to be added later.
class SvipScreen extends StatelessWidget {
  const SvipScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(title: const Text('SVIP')),
      body: const Center(
        child: Text('SVIP — coming soon', style: TextStyle(color: AppColors.muted)),
      ),
    );
  }
}
