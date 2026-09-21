import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../models/app_state.dart';
import '../services/firestore_service.dart';
import 'transaction_history_screen.dart';

class WalletScreen extends StatelessWidget {
  final bool embedded;
  const WalletScreen({super.key, this.embedded = false});

  Future<void> _openWhatsApp(BuildContext context, String phone) async {
    final cleaned = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('https://wa.me/$cleaned');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Could not open WhatsApp')));
      }
    }
  }

  Future<void> _openMessage(BuildContext context, String phone) async {
    final uri = Uri.parse('sms:$phone');
    if (!await launchUrl(uri)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Could not open messages')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();
    final state = AppState.instance;

    final body = ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        // ---- Balance card ----
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF241534), Color(0xFF120B1C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: AppColors.gold.withOpacity(.5)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Gold Coins Balance',
                        style: TextStyle(fontSize: 11.5, color: AppColors.muted)),
                    const SizedBox(height: 8),
                    Text('${state.coins}',
                        style: const TextStyle(
                            fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.gold)),
                  ],
                ),
              ),
              const Text('🪙', style: TextStyle(fontSize: 44)),
            ],
          ),
        ),

        // ---- Section title ----
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: Text('COIN SELLERS',
              style: TextStyle(
                  fontSize: 12, color: AppColors.gold, fontWeight: FontWeight.bold, letterSpacing: .6)),
        ),

        StreamBuilder<List<Map<String, dynamic>>>(
          stream: fs.allCoinSellers(),
          builder: (context, snap) {
            final sellers = snap.data ?? [];
            if (!snap.hasData) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (sellers.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Text('No coin sellers available right now',
                    style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
              );
            }
            return Column(
              children: sellers.map((s) {
                final name = s['nickname'] ?? s['username'] ?? 'Seller';
                final phone = s['phone'] ?? '';
                return Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border.all(color: AppColors.line),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: AppColors.gold,
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name,
                                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
                                Text('ID: ${s['uid']}',
                                    style: const TextStyle(fontSize: 10.5, color: AppColors.muted)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _openMessage(context, phone),
                              child: const Text('Message'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
                              onPressed: () => _openWhatsApp(context, phone),
                              child: const Text('WhatsApp',
                                  style: TextStyle(color: Colors.black)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );

    if (embedded) return body;

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        title: const Text('Wallet'),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const TransactionHistoryScreen()),
            ),
          ),
        ],
      ),
      body: body,
    );
  }
}
