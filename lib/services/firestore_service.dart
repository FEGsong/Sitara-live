import 'package:cloud_firestore/cloud_firestore.dart';

/// All Firestore reads/writes live here so screens never talk to
/// Firestore directly — makes it easy to swap the backend later.
class FirestoreService {
  final _db = FirebaseFirestore.instance;

  CollectionReference get _users => _db.collection('users');
  CollectionReference get _requests => _db.collection('coin_requests');

  /// Called right after signup to create the user's profile document.
  Future<void> createUserProfile({
    required String uid,
    required String phone,
    required String username,
  }) async {
    await _users.doc(uid).set({
      'phone': phone,
      'username': username,
      'nickname': username,
      'profilePublic': true,
      'coins': 100, // starter coins
      'earningsPKR': 0,
      'giftsSent': 0,
      'giftsReceived': 0,
      'isAdmin': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<DocumentSnapshot> userDoc(String uid) => _users.doc(uid).snapshots();

  Future<void> updateProfile(String uid,
      {String? username, String? nickname, bool? profilePublic}) {
    final data = <String, dynamic>{};
    if (username != null) data['username'] = username;
    if (nickname != null) data['nickname'] = nickname;
    if (profilePublic != null) data['profilePublic'] = profilePublic;
    return _users.doc(uid).update(data);
  }

  Future<void> spendCoins(String uid, int amount) {
    return _users.doc(uid).update({'coins': FieldValue.increment(-amount)});
  }

  Future<void> addCoins(String uid, int amount) {
    return _users.doc(uid).update({'coins': FieldValue.increment(amount)});
  }

  Future<void> addEarnings(String uid, double amount) {
    return _users.doc(uid).update({
      'earningsPKR': FieldValue.increment(amount),
      'giftsReceived': FieldValue.increment(1),
    });
  }

  /// Every registered user — shown to the owner in the Admin Panel.
  Stream<List<Map<String, dynamic>>> allUsers() {
    return _users.orderBy('createdAt', descending: true).snapshots().map(
          (snap) => snap.docs
              .map((d) => {'uid': d.id, ...d.data() as Map<String, dynamic>})
              .toList(),
        );
  }

  Stream<List<Map<String, dynamic>>> allAdmins() {
    return _users.where('isAdmin', isEqualTo: true).snapshots().map(
          (snap) => snap.docs
              .map((d) => {'uid': d.id, ...d.data() as Map<String, dynamic>})
              .toList(),
        );
  }

  /// Grants admin by phone number — the user must already have an account.
  Future<bool> makeAdminByPhone(String phone) async {
    final q = await _users.where('phone', isEqualTo: phone).limit(1).get();
    if (q.docs.isEmpty) return false;
    await q.docs.first.reference.update({'isAdmin': true});
    return true;
  }

  Future<void> removeAdmin(String uid) =>
      _users.doc(uid).update({'isAdmin': false});

  // ---- Coin purchase requests (manually approved by the owner) ----

  Future<void> submitCoinRequest({
    required String uid,
    required String phone,
    required int coins,
    required String price,
    required String method,
    required String ref,
  }) {
    return _requests.add({
      'uid': uid,
      'phone': phone,
      'coins': coins,
      'price': price,
      'method': method,
      'ref': ref,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<Map<String, dynamic>>> pendingRequests() {
    return _requests.where('status', isEqualTo: 'pending').snapshots().map(
          (snap) => snap.docs
              .map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>})
              .toList(),
        );
  }

  Future<void> approveRequest(String requestId, String uid, int coins) async {
    final batch = _db.batch();
    batch.update(_requests.doc(requestId), {'status': 'approved'});
    batch.update(_users.doc(uid), {'coins': FieldValue.increment(coins)});
    await batch.commit();
  }
}
