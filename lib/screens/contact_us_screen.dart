import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Static "official help" screen for Sitara Live.
class ContactUsScreen extends StatelessWidget {
  const ContactUsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contact Us')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sitara Live — Official Support',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text('WhatsApp: +92 3XX XXXXXXX',
                style: TextStyle(fontSize: 14)),
            const SizedBox(height: 10),
            const Text('Email: support@sitaralive.com',
                style: TextStyle(fontSize: 14)),
            const SizedBox(height: 20),
            const Text(
              'For coin purchases, account issues, or reporting a problem, message us directly and our team will respond as soon as possible.',
              style: TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}
