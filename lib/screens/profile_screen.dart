import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/app_state.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'login_screen.dart';
import 'admin_screen.dart';

class ProfileScreen extends StatefulWidget {
  final bool embedded;
  const ProfileScreen({super.key, this.embedded = false});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController _usernameCtrl;
  late final TextEditingController _nicknameCtrl;

  @override
  void initState() {
    super.initState();
    _usernameCtrl = TextEditingController(text: AppState.instance.username);
    _nicknameCtrl = TextEditingController(text: AppState.instance.nickname);
  }

  Future<void> _saveProfile() async {
    final username = _usernameCtrl.text.trim();
    final nickname = _nicknameCtrl.text.trim();
    await FirestoreService().updateProfile(
      AppState.instance.uid,
      username: username.isEmpty ? null : username,
      nickname: nickname.isEmpty ? null : nickname,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('✅ Profile saved')));
  }

  Future<void> _togglePublic(bool value) async {
    setState(() => AppState.instance.profilePublic = value);
    await FirestoreService()
        .updateProfile(AppState.instance.uid, profilePublic: value);
  }

  Future<void> _logout() async {
    await AuthService().signOut();
    AppState.instance.reset();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    final body = ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (!widget.embedded)
          const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Profile',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.line),
              borderRadius: BorderRadius.circular(18)),
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                    gradient: LinearGradient(
                        colors: [AppColors.hot, Color(0xFF7A1BFF)]),
                    shape: BoxShape.circle),
                alignment: Alignment.center,
                child: const Icon(Icons.person, size: 30, color: Colors.white),
              ),
              const SizedBox(height: 10),
              Text(state.phone.isEmpty ? '+92 3XX XXXXXXX' : state.phone,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('Host ID: STL-8842',
                  style: TextStyle(fontSize: 12, color: AppColors.muted)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              _field('Username', _usernameCtrl),
              const SizedBox(height: 12),
              _field('Nickname', _nicknameCtrl),
              const SizedBox(height: 4),
              _toggleRow(
                'Public Profile',
                'Turning this off makes your profile private',
                state.profilePublic,
                _togglePublic,
              ),
              const SizedBox(height: 12),
              SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                      onPressed: _saveProfile,
                      child: const Text('Save Profile'))),
              const SizedBox(height: 20),
              if (AppState.instance.isOwnerOrAdmin) ...[
  _toggleRow(
    'Admin Mode (for me)',
    'Trigger the "Admin watching" effect when you join someone\'s live',
    state.adminMode,
    (v) => setState(() => state.adminMode = v),
  ),
  const SizedBox(height: 12),
  SizedBox(
    width: double.infinity,
    child: OutlinedButton(
      onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AdminScreen())),
      child: const Text('🛠️ Admin Panel — Admins & Coin Requests'),
    ),
  ),
],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _logout,
                  child: const Text('Logout'),
                ),
              ),
            ],
          ),
        ),
      ],
    );

    return widget.embedded ? body : Scaffold(body: SafeArea(child: body));
  }

  Widget _field(String label, TextEditingController ctrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11,
                color: AppColors.muted,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(controller: ctrl),
      ],
    );
  }

  Widget _toggleRow(
      String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 10.5, color: AppColors.muted)),
              ],
            ),
          ),
          Switch(
              value: value, onChanged: onChanged, activeColor: AppColors.gold),
        ],
      ),
    );
  }
}
