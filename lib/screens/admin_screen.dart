import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/firestore_service.dart';
import 'wallet_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final _firestore = FirestoreService();
  final _newAdminCtrl = TextEditingController();

  Future<void> _addAdmin() async {
    final val = _newAdminCtrl.text.trim();
    if (val.isEmpty) return;
    final ok = await _firestore.makeAdminByPhone(val);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No account found for this number — they must sign up first')),
      );
      return;
    }
    _newAdminCtrl.clear();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ $val is now an admin')));
  }

  Future<void> _approve(Map<String, dynamic> req) async {
    await _firestore.approveRequest(req['id'], req['uid'], req['coins'] as int);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('✅ ${req['coins']} coins added for ${req['phone']}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Panel'), backgroundColor: AppColors.bgDeep),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _box(
            title: 'App Users',
            subtitle: 'Everyone currently registered on the app',
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _firestore.allUsers(),
              builder: (context, snap) {
                final users = snap.data ?? [];
                if (!snap.hasData) return const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()));
                if (users.isEmpty) return const Text('No users yet', style: TextStyle(color: AppColors.muted, fontSize: 12));
                return Column(
                  children: users.map((u) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: AppColors.surface2, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(10)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('@${u['username']}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                              Text('${u['coins']} 🪙', style: const TextStyle(fontSize: 12.5, color: AppColors.gold)),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text('${u['phone']}${u['isAdmin'] == true ? '  ·  👑 admin' : ''}', style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
          _box(
            title: 'Admins',
            subtitle: 'These numbers trigger the "Admin watching" effect automatically whenever they join any live stream',
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: TextField(controller: _newAdminCtrl, decoration: const InputDecoration(hintText: '+92 3XX XXXXXXX'))),
                    const SizedBox(width: 8),
                    ElevatedButton(onPressed: _addAdmin, child: const Text('Add')),
                  ],
                ),
                const SizedBox(height: 10),
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _firestore.allAdmins(),
                  builder: (context, snap) {
                    final admins = snap.data ?? [];
                    if (admins.isEmpty) {
                      return const Align(alignment: Alignment.centerLeft, child: Text('No admins added yet', style: TextStyle(color: AppColors.muted, fontSize: 12)));
                    }
                    return Column(
                      children: admins.map((a) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                            decoration: BoxDecoration(color: AppColors.surface2, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(10)),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('👑 ${a['phone']}', style: const TextStyle(fontSize: 12.5)),
                                GestureDetector(
                                  onTap: () => _firestore.removeAdmin(a['uid']),
                                  child: const Text('Remove', style: TextStyle(color: AppColors.hot, fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          )).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('PENDING COIN REQUESTS', style: TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.bold, letterSpacing: .6)),
          ),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _firestore.pendingRequests(),
            builder: (context, snap) {
              final requests = snap.data ?? [];
              if (!snap.hasData) return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
              if (requests.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 30),
                  child: Center(child: Text('No pending requests', style: TextStyle(color: AppColors.muted))),
                );
              }
              return Column(
                children: requests.map((r) {
                  final method = kPayMethods.firstWhere((m) => m['id'] == r['method'], orElse: () => {'name': r['method']});
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: AppColors.surface, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(14)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${r['phone']}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            Text('${r['coins']} 🪙', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.gold)),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text('Amount: ${r['price']} · Method: ${method['name']}\nReference: ${r['ref']}',
                            style: const TextStyle(fontSize: 11.5, color: AppColors.muted, height: 1.5)),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(onPressed: () => _approve(r), child: const Text('✅ Confirm Payment — Add Coins')),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _box({required String title, required String subtitle, required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 3),
          Text(subtitle, style: const TextStyle(fontSize: 10.5, color: AppColors.muted)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
