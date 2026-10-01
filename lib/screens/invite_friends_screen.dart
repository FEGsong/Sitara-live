import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../models/app_state.dart';
import '../services/firestore_service.dart';

class InviteFriendsScreen extends StatefulWidget {
  const InviteFriendsScreen({super.key});

  @override
  State<InviteFriendsScreen> createState() => _InviteFriendsScreenState();
}

class _InviteFriendsScreenState extends State<InviteFriendsScreen> {
  final _fs = FirestoreService();
  bool _claiming = false;

  String get _inviteLink => 'sitaralive://invite/${AppState.instance.uid}';

  Future<void> _openWhatsApp() async {
    final text = Uri.encodeComponent(
        'Join me on Sitara Live! 🎙 Download the app and use my invite link:\n$_inviteLink');
    final uri = Uri.parse('whatsapp://send?text=$text');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      Share.share(
          'Join me on Sitara Live! 🎙 Download the app and use my invite link:\n$_inviteLink');
    }
  }

  void _copyLink() {
    // Uses Share as a portable "copy" fallback across platforms.
    Share.share(_inviteLink);
  }

  Future<void> _claim(int claimable) async {
    if (claimable <= 0 || _claiming) return;
    setState(() => _claiming = true);
    final claimed = await _fs.claimReferralCoins(AppState.instance.uid);
    if (!mounted) return;
    setState(() => _claiming = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('✅ $claimed coins added to your wallet')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = AppState.instance.uid;

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(title: const Text('Invite Friends')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _fs.userDoc(uid),
        builder: (context, snap) {
          final data = snap.data?.data() as Map<String, dynamic>?;
          final invitedByName = data?['invitedByName'] as String?;
          final referralCount = (data?['referralCount'] ?? 0) as int;
          final claimable = (data?['referralClaimable'] ?? 0) as int;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3A0F5C), Color(0xFF6B1BB5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    const Text('🎁', style: TextStyle(fontSize: 40)),
                    const SizedBox(height: 8),
                    const Text('Invite Friends, Earn Gold',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 6),
                    Text('$referralCount friends invited so far',
                        style: const TextStyle(fontSize: 12, color: Colors.white70)),
                  ],
                ),
              ),

              if (invitedByName != null && invitedByName.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border.all(color: AppColors.gold.withOpacity(.4)),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Text('You were invited by 🦋 $invitedByName 🦋',
                      style: const TextStyle(fontSize: 12.5, color: AppColors.gold)),
                ),
              ],

              const SizedBox(height: 20),
              const Text('AWARD RULES',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.bold, letterSpacing: .6)),
              const SizedBox(height: 10),
              _ruleRow('Invite a friend', 'GET 300000 🪙'),
              _ruleRow('Friend Top-up', 'GET 60%'),
              _ruleRow('Friend invited a friend to recharge', 'GET 15%'),

              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.line),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Gold coins to be claimed',
                              style: TextStyle(fontSize: 12, color: AppColors.muted)),
                          const SizedBox(height: 4),
                          Text('$claimable',
                              style: const TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.gold)),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: claimable > 0 && !_claiming ? () => _claim(claimable) : null,
                      child: _claiming
                          ? const SizedBox(
                              width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Claim'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              const Text('MY INVITED FRIENDS',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.bold, letterSpacing: .6)),
              const SizedBox(height: 10),
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: _fs.invitedFriendsOf(uid),
                builder: (context, friendSnap) {
                  final friends = friendSnap.data ?? [];
                  if (friends.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: Text('No friends invited yet',
                            style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
                      ),
                    );
                  }
                  return Column(
                    children: friends.map((f) {
                      final name = (f['nickname'] ?? f['username'] ?? 'User') as String;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: AppColors.hot,
                              child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(name,
                                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              ),

              const SizedBox(height: 24),
              const Text('SHARE TO',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.bold, letterSpacing: .6)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
                      onPressed: _openWhatsApp,
                      icon: const Icon(Icons.chat, color: Colors.white),
                      label: const Text('WhatsApp', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _copyLink,
                      icon: const Icon(Icons.link),
                      label: const Text('Copy Link'),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _ruleRow(String label, String reward) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 13)),
          ),
          Text(reward,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.gold)),
        ],
      ),
    );
  }
}
