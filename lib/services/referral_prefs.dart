import 'package:shared_preferences/shared_preferences.dart';

/// Holds an invite-link uid that arrived before the person had an
/// account yet, so it can be applied once they finish signing up.
class ReferralPrefs {
  static const _key = 'pending_referrer_uid';

  static Future<void> savePending(String inviterUid) async {
    final prefs = await SharedPreferences.getInstance();
    // Never overwrite an existing pending referral with a new one —
    // first link opened wins.
    if (prefs.getString(_key) == null) {
      await prefs.setString(_key, inviterUid);
    }
  }

  static Future<String?> consumePending() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString(_key);
    if (uid != null) await prefs.remove(_key);
    return uid;
  }
}
