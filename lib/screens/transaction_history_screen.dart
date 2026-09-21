import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/app_state.dart';
import '../services/firestore_service.dart';

class TransactionHistoryScreen extends StatelessWidget {
  const TransactionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();
    final uid = AppState.instance.uid;

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(title: const Text('Transaction History')),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: fs.transactionsOf(uid),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final txns = snap.data!;
          if (txns.isEmpty) {
            return const Center(
              child: Text('No transactions yet', style: TextStyle(color: AppColors.muted)),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(14),
            itemCount: txns.length,
            separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.line),
            itemBuilder: (context, i) {
              final t = txns[i];
              final amount = t['amount'] ?? 0;
              final isCredit = amount > 0;
              final ts = t['createdAt'];
              String dateStr = '';
              if (ts != null) {
                final date = ts.toDate();
                dateStr = '${date.day}/${date.month}/${date.year}';
              }
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isCredit
                            ? AppColors.cyan.withOpacity(.15)
                            : AppColors.hot.withOpacity(.15),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                        size: 16,
                        color: isCredit ? AppColors.cyan : AppColors.hot,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t['title'] ?? '',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(dateStr,
                              style: const TextStyle(fontSize: 10.5, color: AppColors.muted)),
                        ],
                      ),
                    ),
                    Text(
                      '${isCredit ? '+' : ''}$amount 🪙',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isCredit ? AppColors.cyan : AppColors.hot,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
