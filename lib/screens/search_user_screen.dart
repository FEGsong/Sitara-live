import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../services/firestore_service.dart';
import 'public_profile_screen.dart';

/// TikTok-style search: recent searches saved locally, live
/// suggestions while typing, and Clear All for history.
class SearchUserScreen extends StatefulWidget {
  const SearchUserScreen({super.key});

  @override
  State<SearchUserScreen> createState() => _SearchUserScreenState();
}

class _SearchUserScreenState extends State<SearchUserScreen> {
  final _ctrl = TextEditingController();
  final _fs = FirestoreService();
  static const _prefsKey = 'recent_user_searches';

  List<String> _recent = [];
  List<Map<String, dynamic>> _suggestions = [];
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _loadRecent();
    _ctrl.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onTextChanged);
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _loadRecent() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _recent = prefs.getStringList(_prefsKey) ?? []);
  }

  Future<void> _saveRecent(String term) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_prefsKey) ?? [];
    list.remove(term);
    list.insert(0, term);
    if (list.length > 10) list.removeLast();
    await prefs.setStringList(_prefsKey, list);
    setState(() => _recent = list);
  }

  Future<void> _removeRecent(String term) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_prefsKey) ?? [];
    list.remove(term);
    await prefs.setStringList(_prefsKey, list);
    setState(() => _recent = list);
  }

  Future<void> _clearAllRecent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
    setState(() => _recent = []);
  }

  Future<void> _onTextChanged() async {
    final query = _ctrl.text.trim();
    if (query.isEmpty) {
      setState(() => _suggestions = []);
      return;
    }
    setState(() => _searching = true);
    final results = await _fs.searchUsersByPrefix(query);
    if (!mounted) return;
    setState(() {
      _suggestions = results;
      _searching = false;
    });
  }

  Future<void> _openUser(Map<String, dynamic> user) async {
    await _saveRecent(user['username'] ?? '');
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PublicProfileScreen(targetUid: user['uid'])),
    );
  }

  Future<void> _searchExact() async {
    final query = _ctrl.text.trim();
    if (query.isEmpty) return;
    final user = await _fs.findUserByUsername(query);
    if (!mounted) return;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No user found with that ID/username')),
      );
      return;
    }
    await _openUser(user);
  }

  @override
  Widget build(BuildContext context) {
    final showRecent = _ctrl.text.trim().isEmpty;

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        backgroundColor: AppColors.bgDeep,
        title: Padding(
          padding: const EdgeInsets.only(left: 4, right: 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search, size: 18, color: AppColors.muted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _ctrl,
                          autofocus: true,
                          style: const TextStyle(fontSize: 13.5),
                          decoration: const InputDecoration(
                            hintText: 'Search username or ID',
                            border: InputBorder.none,
                            isDense: true,
                          ),
                          onSubmitted: (_) => _searchExact(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              TextButton(
                onPressed: _searchExact,
                child: const Text('Search',
                    style: TextStyle(color: AppColors.hot, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
      body: showRecent ? _recentSearchesView() : _suggestionsView(),
    );
  }

  Widget _recentSearchesView() {
    if (_recent.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Text('No recent searches',
            style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Recent searches',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              GestureDetector(
                onTap: _clearAllRecent,
                child: const Text('Clear all',
                    style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._recent.map((term) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.history, size: 20, color: AppColors.muted),
                title: Text(term, style: const TextStyle(fontSize: 13.5)),
                trailing: GestureDetector(
                  onTap: () => _removeRecent(term),
                  child: const Icon(Icons.close, size: 18, color: AppColors.muted),
                ),
                onTap: () {
                  _ctrl.text = term;
                  _ctrl.selection = TextSelection.fromPosition(
                    TextPosition(offset: term.length),
                  );
                  _onTextChanged();
                },
              )),
        ],
      ),
    );
  }

  Widget _suggestionsView() {
    if (_searching) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_suggestions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Text('No matching users',
            style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: _suggestions.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.line),
      itemBuilder: (context, i) {
        final u = _suggestions[i];
        final name = u['nickname'] ?? u['username'] ?? 'User';
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: AppColors.hot,
            child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?'),
          ),
          title: Text(name, style: const TextStyle(fontSize: 13.5)),
          subtitle: Text('@${u['username'] ?? ''}',
              style: const TextStyle(color: AppColors.muted, fontSize: 11.5)),
          onTap: () => _openUser(u),
        );
      },
    );
  }
}
