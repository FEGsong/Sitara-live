import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/app_state.dart';
import '../services/firestore_service.dart';

const List<Map<String, dynamic>> kPackages = [
  {'coins': 240, 'price': 'Rs 400'},
  {'coins': 480, 'price': 'Rs 800'},
  {'coins': 900, 'price': 'Rs 1,500'},
  {'coins': 1800, 'price': 'Rs 3,000'},
];

const List<Map<String, String>> kPayMethods = [
  {
    'id': 'jazzcash',
    'name': 'JazzCash',
    'sub': 'Mobile wallet',
    'account': '0300-1234567 (Owner Account)'
  },
  {
    'id': 'easypaisa',
    'name': 'Easypaisa',
    'sub': 'Mobile wallet',
    'account': '0345-7654321 (Owner Account)'
  },
  {
    'id': 'bank',
    'name': 'Bank Transfer',
    'sub': 'Direct account transfer',
    'account': 'HBL — 1234 5678 9012 (Owner Account)'
  },
];

class WalletScreen extends StatefulWidget {
  final bool embedded;
  const WalletScreen({super.key, this.embedded = false});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final _firestore = FirestoreService();

  void _openBuyCoins(int coins, String price) {
    _openPaymentSheet(
      title: 'Buy $coins Coins',
      subtitle: 'Total: $price — choose a payment method',
      confirmLabel: "I've Paid — Submit Request",
      onConfirm: (method, ref) async {
        await _firestore.submitCoinRequest(
          uid: AppState.instance.uid,
          phone: AppState.instance.phone,
          coins: coins,
          price: price,
          method: method,
          ref: ref,
        );
        _snack(
            '✅ Request submitted — the owner will verify and add your coins');
      },
      showAccountInstructions: true,
    );
  }

  void _openWithdraw() {
    if (AppState.instance.earningsPKR < 1000) {
      _snack(
          'Minimum withdrawal is Rs 1,000 (you have Rs ${AppState.instance.earningsPKR.toStringAsFixed(0)})');
      return;
    }
    _openPaymentSheet(
      title: 'Withdraw Rs ${AppState.instance.earningsPKR.toStringAsFixed(0)}',
      subtitle: 'Choose where to receive the payment',
      confirmLabel: 'Submit Withdrawal Request',
      onConfirm: (method, ref) {
        _snack(
            '✅ Withdrawal request for Rs ${AppState.instance.earningsPKR.toStringAsFixed(0)} submitted');
      },
      showAccountInstructions: false,
    );
  }

  void _openPaymentSheet({
    required String title,
    required String subtitle,
    required String confirmLabel,
    required void Function(String method, String ref) onConfirm,
    required bool showAccountInstructions,
  }) {
    String? selectedMethod;
    final refCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final method = selectedMethod != null
                ? kPayMethods.firstWhere((m) => m['id'] == selectedMethod)
                : null;
            return Padding(
              padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 22,
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 26),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: const TextStyle(
                            color: AppColors.muted, fontSize: 12)),
                    const SizedBox(height: 16),
                    ...kPayMethods.map((m) {
                      final selected = selectedMethod == m['id'];
                      return GestureDetector(
                        onTap: () =>
                            setSheetState(() => selectedMethod = m['id']),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(
                                color:
                                    selected ? AppColors.cyan : AppColors.line),
                            borderRadius: BorderRadius.circular(12),
                            color: selected
                                ? AppColors.cyan.withOpacity(.06)
                                : null,
                          ),
                          child: Row(
                            children: [
                              Text(m['name']!,
                                  style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(width: 8),
                              Text(m['sub']!,
                                  style: const TextStyle(
                                      fontSize: 10.5, color: AppColors.muted)),
                            ],
                          ),
                        ),
                      );
                    }),
                    if (showAccountInstructions && method != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withOpacity(.08),
                          border: Border.all(
                              color: AppColors.gold.withOpacity(.35)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Send your payment to:\n${method['account']}\n\nAfter paying, enter your Transaction ID below.',
                          style: const TextStyle(fontSize: 12, height: 1.5),
                        ),
                      ),
                    TextField(
                      controller: refCtrl,
                      decoration: const InputDecoration(
                          hintText: 'Transaction ID / account number'),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          if (selectedMethod == null) {
                            _snack('Please select a payment method');
                            return;
                          }
                          if (refCtrl.text.trim().isEmpty) {
                            _snack('Enter your account/transaction reference');
                            return;
                          }
                          Navigator.pop(ctx);
                          onConfirm(selectedMethod!, refCtrl.text.trim());
                          setState(() {});
                        },
                        child: Text(confirmLabel),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
                onPressed: _openWithdraw,
                child: const Text('Withdraw Earnings')),
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
