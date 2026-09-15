import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'new_friends_screen.dart';
import 'contact_us_screen.dart';
import 'notifications_screen.dart';

class InboxScreen extends StatelessWidget {
  final bool embed;
  const InboxScreen({super.key, this.embed = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: embed
          ? null
          : AppBar(title: const Text('Message')),
      body: SafeArea(
        child: ListView(
          children: [
            if (embed)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Message',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ),
            _rowItem(
              context,
              icon: Icons.people_alt,
              color: AppColors.hot,
              title: 'New Friends',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NewFriendsScreen()),
              ),
            ),
            _rowItem(
              context,
              icon: Icons.support_agent,
              color: AppColors.gold,
              title: 'Contact us',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ContactUsScreen()),
              ),
            ),
            _rowItem(
              context,
              icon: Icons.notifications,
              color: AppColors.cyan,
              title: 'Notification',
              subtitle: '[Custom]',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              ),
            ),
            const Divider(color: AppColors.line, height: 1),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Center(
                child: Text('No messages yet', style: TextStyle(color: AppColors.muted)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rowItem(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color,
        child: Icon(icon, color: Colors.white, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: subtitle != null
          ? Text(subtitle, style: const TextStyle(color: AppColors.muted, fontSize: 11))
          : null,
      onTap: onTap,
    );
  }
}
