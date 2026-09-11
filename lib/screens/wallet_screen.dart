import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/app_state.dart';

const List<Map<String, dynamic>> kPackages = [
  {'coins': 240, 'price': 'Rs 400'},
  {'coins': 480, 'price': 'Rs 800'},
  {'coins': 900, 'price': 'Rs 1,500'},
  {'coins': 1800, 'price': 'Rs 3,000'},
];

class WalletScreen extends StatefulWidget {
  final bool embedded;
  const WalletScreen({super.key, this.embedded = false});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  void _openBuyCoins(int coins, String price) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Contact Coin Seller'),
        content: Text(
          'To buy $coins coins ($price), please contact the coin seller directly to arrange payment.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
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
            child: Text('Wallet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFF241238), Color(0xFF3A0F2E)]),
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('COIN BALANCE',
                  style: TextStyle(
                      fontSize: 11, color: AppColors.muted, letterSpacing: .6)),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Container(
                        width: 22,
                        height: 22,
                        decoration: const BoxDecoration(
                            color: AppColors.gold, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Text('${state.coins}',
                        style: const TextStyle(
                            fontSize: 34, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Row(
                children: [
                  Expanded(
                      child: _earnBox('Total Earnings',
                          'Rs ${state.earningsPKR.toStringAsFixed(0)}')),
                  const SizedBox(width: 10),
                  Expanded(
                      child:
                          _earnBox('Gifts Received', '${state.giftsReceived}')),
                ],
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text('BUY COINS',
              style: TextStyle(
                  fontSize: 12,
                  color: AppColors.muted,
                  fontWeight: FontWeight.bold,
                  letterSpacing: .6)),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.6,
            children: kPackages.map((p) {
              return GestureDetector(
                onTap: () =>
                    _openBuyCoins(p['coins'] as int, p['price'] as String),
                child: Container(
                  decoration: BoxDecoration(
                      color: AppColors.surface,
                      border: Border.all(color: AppColors.line),
                      borderRadius: BorderRadius.circular(14)),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('🪙 ${p['coins']}',
                          style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: AppColors.gold)),
                      const SizedBox(height: 3),
                      Text(p['price'] as String,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.muted)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );

    return widget.embedded ? body : Scaffold(body: SafeArea(child: body));
  }

  Widget _earnBox(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
          color: Colors.white.withOpacity(.05),
          borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 10.5, color: AppColors.muted)),
          const SizedBox(height: 2),
          Text(value,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}