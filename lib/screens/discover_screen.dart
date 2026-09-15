import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Placeholder for now — content to be added later.
class DiscoverScreen extends StatelessWidget {
  final bool embedded;
  const DiscoverScreen({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final body = const Center(
      child: Text('Discover — coming soon', style: TextStyle(color: AppColors.muted)),
    );
    return embedded
        ? body
        : Scaffold(
            backgroundColor: AppColors.bgDeep,
            appBar: AppBar(title: const Text('Discover')),
            body: body,
          );
  }
}
