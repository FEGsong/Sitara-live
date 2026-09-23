import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/app_state.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../widgets/verified_badge.dart';
import 'login_screen.dart';
import 'admin_screen.dart';
import 'wallet_screen.dart';
import 'store_screen.dart';
import 'bag_screen.dart';
import 'reward_screen.dart';

class ProfileScreen extends StatefulWidget {
  final bool embedded;
  const ProfileScreen({super.key, this.embedded = false});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController _usernameCtrl;
  late final TextEditingController _nicknameCtrl;
  final _firestore = FirestoreService();

  @override
  void initState() {
    super.initState();
    _usernameCtrl = TextEditingController(text: AppState.instance.username);
    _nicknameCtrl = TextEditingController(text: AppState.instance.nickname);
  }

  Future<void> _saveProfile() async {
    final username = _usernameCtrl.text.trim();
    final nickname = _nicknameCtrl.text.trim();
    await _firestore.updateProfile(
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
    await _firestore.updateProfile(AppState.instance.uid, profilePublic: value);
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

    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.userDoc(state.uid),
      builder: (context, snap) {
        final data = snap.data?.data() as Map<String, dynamic>?;
        final followers = data?['followersCount'] ?? 0;
        final following = data?['followingCount'] ?? 0;
        final profileViews = data?['profileViews'] ?? 0;
        final isVerified = data?['isVerified'] == true;

        final body = ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            if (!widget.embedded)
              const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Profile',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),

            // ---- Profile card: avatar, name, id, stats, views badge ----
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.line),
                  borderRadius: BorderRadius.circular(18)),
              child: Stack(
                children: [
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(.35),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.remove_red_eye,
                              size: 12, color: AppColors.muted),
                          const SizedBox(width: 4),
                          Text('$profileViews',
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.muted)),
                        ],
                      ),
                    ),
                  ),
                  Column(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: const BoxDecoration(
                            gradient: LinearGradient(
                                colors: [AppColors.hot, Color(0xFF7A1BFF)]),
                            shape: BoxShape.circle),
                        alignment: Alignment.center,
                        child: const Icon(Icons.person,
                            size: 30, color: Colors.white),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                              state.nickname.isNotEmpty
                                  ? state.nickname
                                  : (state.username.isNotEmpty
                                      ? state.username
                                      : 'User'),
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                          if (isVerified) const VerifiedBadge(),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text('ID: ${state.uid}',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.muted)),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _statItem('Following', following),
                          Container(
                              width: 1,
                              height: 24,
                              color: AppColors.line),
                          _statItem('Followers', followers),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ---- Wallet / Store / Bag / Reward quick-access row ----
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.gold.withOpacity(.4)),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _quickIcon(
                      icon: Icons.account_balance_wallet,
                      label: 'Wallet',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const WalletScreen()),
                      ),
                    ),
                    _quickIcon(
                      icon: Icons.storefront,
                      label: 'Store',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const StoreScreen()),
                      ),
                    ),
                    _quickIcon(
                      icon: Icons.backpack,
                      label: 'Bag',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const BagScreen()),
                      ),
                    ),
                    _quickIcon(
                      icon: Icons.card_giftcard,
                      label: 'Reward',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const RewardScreen()),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

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
      },
    );
  }

  Widget _statItem(String label, int count) {
    return Column(
      children: [
        Text('$count',
            style:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(fontSize: 11, color: AppColors.muted)),
      ],
    );
  }

  Widget _quickIcon({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: AppColors.gold, size: 26),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
        ],
      ),
    );
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
