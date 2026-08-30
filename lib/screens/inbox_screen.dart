import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class InboxScreen extends StatelessWidget {
  final bool embed;
  const InboxScreen({super.key, this.embed = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: embed ? null : AppBar(title: const Text('Inbox')),
      body: const Center(
        child: Text(
          'No messages yet',
          style: TextStyle(color: AppColors.muted),
        ),
      ),
    );
  }
}
