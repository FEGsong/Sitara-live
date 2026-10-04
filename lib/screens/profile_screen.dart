import 'vip_screen.dart';
import 'svip_screen.dart';
import 'invite_friends_screen.dart';
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
import 'edit_profile_screen.dart';
import 'profile_viewers_screen.dart';

class ProfileScreen extends StatefulWidget {
  final bool embedded;

  const ProfileScreen({
    super.key,
    this.embedded = false,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _firestore = FirestoreService();

  Future<void> _togglePublic(bool value) async {
    setState(() => AppState.instance.profilePublic = value);

    await _firestore.updateProfile(
      AppState.instance.uid,
      profilePublic: value,
    );
  }

  Future<void> _logout() async {
    await AuthService().signOut();
    AppState.instance.reset();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
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

        final nickname = data?['nickname'] ?? state.nickname;
        final username = data?['username'] ?? state.username;
        final bio = data?['bio'] ?? '';
        final avatarUrl = data?['avatarUrl'] ?? '';

        final body = ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            // ------------------------------------------------------------
            // PROFILE TITLE
            // ------------------------------------------------------------
            if (!widget.embedded)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Profile',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

            // ------------------------------------------------------------
            // PROFILE HEADER
            // ------------------------------------------------------------
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(
                  color: AppColors.line,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Stack(
                children: [
                  // Profile views
                  Positioned(
                    top: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ProfileViewersScreen(),
                        ),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(.35),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.remove_red_eye,
                              size: 12,
                              color: AppColors.muted,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$profileViews',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Edit icon
                  Positioned(
                    top: 0,
                    left: 0,
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const EditProfileScreen(),
                        ),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(.35),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Icon(
                          Icons.edit,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                  Column(
                    children: [
                      // Avatar
                      Stack(
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              gradient: avatarUrl.isEmpty
                                  ? const LinearGradient(
                                      colors: [
                                        AppColors.hot,
                                        Color(0xFF7A1BFF),
                                      ],
                                    )
                                  : null,
                              shape: BoxShape.circle,
                              image: avatarUrl.isNotEmpty
                                  ? DecorationImage(
                                      image: NetworkImage(avatarUrl),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            alignment: Alignment.center,
                            child: avatarUrl.isEmpty
                                ? const Icon(
                                    Icons.person,
                                    size: 30,
                                    color: Colors.white,
                                  )
                                : null,
                          ),

                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Stories — coming soon',
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: const BoxDecoration(
                                  color: AppColors.cyan,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.add,
                                  size: 16,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // Name
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            nickname.isNotEmpty ? nickname : 'User',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (isVerified) const VerifiedBadge(),
                        ],
                      ),

                      const SizedBox(height: 2),

                      // Username
                      Text(
                        '@$username',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.muted,
                        ),
                      ),

                      // Bio
                      if (bio.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          bio,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.muted,
                          ),
                        ),
                      ],

                      const SizedBox(height: 14),

                      // Followers / Following
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _statItem(
                            'Following',
                            following,
                          ),
                          Container(
                            width: 1,
                            height: 24,
                            color: AppColors.line,
                          ),
                          _statItem(
                            'Followers',
                            followers,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ------------------------------------------------------------
            // EDIT PROFILE
            // ------------------------------------------------------------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const EditProfileScreen(),
                    ),
                  ),
                  child: const Text('Edit Profile'),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ------------------------------------------------------------
            // INVITE FRIENDS
            // ------------------------------------------------------------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const InviteFriendsScreen(),
                    ),
                  ),
                  icon: const Icon(
                    Icons.card_giftcard,
                    color: AppColors.gold,
                  ),
                  label: const Text(
                    'Invite Friends — Get Gold Coins',
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ------------------------------------------------------------
            // WALLET / STORE / BAG / REWARD
            // ------------------------------------------------------------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(
                    color: AppColors.gold.withOpacity(.4),
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _quickIcon(
                      icon: Icons.account_balance_wallet,
                      label: 'Wallet',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const WalletScreen(),
                        ),
                      ),
                    ),
                    _quickIcon(
                      icon: Icons.storefront,
                      label: 'Store',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const StoreScreen(),
                        ),
                      ),
                    ),
                    _quickIcon(
                      icon: Icons.backpack,
                      label: 'Bag',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const BagScreen(),
                        ),
                      ),
                    ),
                    _quickIcon(
                      icon: Icons.card_giftcard,
                      label: 'Reward',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const RewardScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 22),

            // ============================================================
            // VIP / SVIP SECTION
            // ============================================================
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // VIP
                  Expanded(
                    child: _membershipCard(
                      title: 'VIP',
                      subtitle: 'VIP',
                      icon: Icons.workspace_premium,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const VipScreen(),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(width: 12),

                  // SVIP
                  Expanded(
                    child: _membershipCard(
                      title: 'SVIP',
                      subtitle: 'SUPER VIP',
                      icon: Icons.diamond,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SvipScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ------------------------------------------------------------
            // SETTINGS
            // ------------------------------------------------------------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _toggleRow(
                    'Public Profile',
                    'Turning this off makes your profile private',
                    state.profilePublic,
                    _togglePublic,
                  ),

                  const SizedBox(height: 20),

                  if (AppState.instance.isOwnerOrAdmin) ...[
                    _toggleRow(
                      'Admin Mode (for me)',
                      'Trigger the "Admin watching" effect when you join someone\'s live',
                      state.adminMode,
                      (v) => setState(
                        () => state.adminMode = v,
                      ),
                    ),

                    const SizedBox(height: 12),

                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const AdminScreen(),
                          ),
                        ),
                        child: const Text(
                          '🛠️ Admin Panel — Admins & Coin Requests',
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Logout
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

        return widget.embedded
            ? body
            : Scaffold(
                body: SafeArea(
                  child: body,
                ),
              );
      },
    );
  }

  // ============================================================
  // VIP / SVIP CARD
  // ============================================================

  Widget _membershipCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 125,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.gold,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.gold.withOpacity(.22),
              blurRadius: 12,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Stack(
          children: [
            // Golden glow
            Positioned(
              top: -25,
              left: -20,
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.gold.withOpacity(.08),
                ),
              ),
            ),

            // Card content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFFFE7A0),
                          AppColors.gold,
                          Color(0xFF8A5A00),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.gold.withOpacity(.35),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Icon(
                      icon,
                      size: 30,
                      color: Colors.black,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),

                  const SizedBox(height: 2),

                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      letterSpacing: .8,
                    ),
                  ),
                ],
              ),
            ),

            // Arrow
            const Positioned(
              right: 8,
              bottom: 8,
              child: Icon(
                Icons.chevron_right,
                size: 18,
                color: AppColors.gold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // STATS
  // ============================================================

  Widget _statItem(
    String label,
    int count,
  ) {
    return Column(
      children: [
        Text(
          '$count',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.muted,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // QUICK ICON
  // ============================================================

  Widget _quickIcon({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(
            icon,
            color: AppColors.gold,
            size: 26,
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TOGGLE ROW
  // ============================================================

  Widget _toggleRow(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(
          color: AppColors.line,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.gold,
          ),
        ],
      ),
    );
  }
}
