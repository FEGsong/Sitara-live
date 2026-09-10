import 'package:cloud_firestore/cloud_firestore.dart';

/// All Firestore reads/writes live here so screens never talk to
/// Firestore directly — makes it easy to swap the backend later.
class FirestoreService {
  final _db = FirebaseFirestore.instance;
  CollectionReference get _users => _db.collection('users');
  CollectionReference get _requests => _db.collection('coin_requests');
  CollectionReference get _rooms => _db.collection('rooms');
  CollectionReference _userRecent(String uid) =>
      _users.doc(uid).collection('recent_rooms');

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
      'coins': 150, // starter coins
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

  // ---- Audio rooms (voice-call live rooms with seats) ----

  /// Creates a new live audio room with the given number of seats
  /// (15 / 25 / 50 / 100) and automatically seats the host at seat 0.
  Future<String> createRoom({
    required String hostUid,
    required String hostName,
    required int seatCount,
  }) async {
    final gradient = _randomGradient();
    final doc = await _rooms.add({
      'hostUid': hostUid,
      'hostName': hostName,
      'seatCount': seatCount,
      'seats': List<dynamic>.filled(seatCount, null),
      'status': 'live',
      'viewers': 0,
      'c1': gradient[0],
      'c2': gradient[1],
      'createdAt': FieldValue.serverTimestamp(),
    });
    await takeSeat(doc.id, 0, hostUid, hostName);
    return doc.id;
  }

  List<int> _randomGradient() {
    const options = [
      [0xFFFF2E6B, 0xFF7A1BFF],
      [0xFF2DE8C4, 0xFF12707F],
      [0xFFFFC93C, 0xFFB5641A],
      [0xFF7A1BFF, 0xFFFF2E6B],
    ];
    options.shuffle();
    return options.first;
  }

  /// Live rooms only — used on the Home screen "LIVE NOW" section.
  Stream<List<Map<String, dynamic>>> liveRooms() {
    return _rooms.where('status', isEqualTo: 'live').snapshots().map(
          (snap) => snap.docs
              .map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>})
              .toList(),
        );
  }

  Stream<DocumentSnapshot> roomDoc(String roomId) =>
      _rooms.doc(roomId).snapshots();

  Future<DocumentSnapshot> getRoomOnce(String roomId) =>
      _rooms.doc(roomId).get();

  /// This user's own room, only while it's still live — used to show
  /// the "My Room" shortcut on Home so a host can jump straight back in.
  Stream<Map<String, dynamic>?> myActiveRoom(String uid) {
    return _rooms
        .where('hostUid', isEqualTo: uid)
        .where('status', isEqualTo: 'live')
        .limit(1)
        .snapshots()
        .map((snap) => snap.docs.isEmpty
            ? null
            : {
                'id': snap.docs.first.id,
                ...snap.docs.first.data() as Map<String, dynamic>
              });
  }

  Future<void> takeSeat(
      String roomId, int seatIndex, String uid, String name) async {
    final ref = _rooms.doc(roomId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final data = snap.data() as Map<String, dynamic>;
      final seats = List<dynamic>.from(data['seats'] ?? []);
      if (seatIndex < 0 || seatIndex >= seats.length) return;
      if (seats[seatIndex] != null) return; // already taken
      seats[seatIndex] = {'uid': uid, 'name': name, 'isMuted': false};
      tx.update(ref, {'seats': seats});
    });
  }

  Future<void> leaveSeat(String roomId, int seatIndex) async {
    final ref = _rooms.doc(roomId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final data = snap.data() as Map<String, dynamic>;
      final seats = List<dynamic>.from(data['seats'] ?? []);
      if (seatIndex < 0 || seatIndex >= seats.length) return;
      seats[seatIndex] = null;
      tx.update(ref, {'seats': seats});
    });
  }

  Future<void> toggleSeatMute(
      String roomId, int seatIndex, bool isMuted) async {
    final ref = _rooms.doc(roomId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final data = snap.data() as Map<String, dynamic>;
      final seats = List<dynamic>.from(data['seats'] ?? []);
      if (seatIndex < 0 || seatIndex >= seats.length) return;
      final seat = seats[seatIndex];
      if (seat == null) return;
      seats[seatIndex] = {
        ...Map<String, dynamic>.from(seat),
        'isMuted': isMuted,
      };
      tx.update(ref, {'seats': seats});
    });
  }

  Future<void> incrementViewers(String roomId, int delta) =>
      _rooms.doc(roomId).update({'viewers': FieldValue.increment(delta)});

  Future<void> endRoom(String roomId) =>
      _rooms.doc(roomId).update({'status': 'ended'});

  // ---- Recently visited rooms (per-user history) ----

  /// Called whenever a user joins a room as a listener — remembers it
  /// so it can show up under "Recently" on Home next time.
  Future<void> recordRecentRoom({
    required String uid,
    required String roomId,
    required String hostName,
    required int c1,
    required int c2,
  }) {
    return _userRecent(uid).doc(roomId).set({
      'roomId': roomId,
      'hostName': hostName,
      'c1': c1,
      'c2': c2,
      'visitedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<List<Map<String, dynamic>>> recentRooms(String uid) {
    return _userRecent(uid)
        .orderBy('visitedAt', descending: true)
        .limit(10)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => d.data() as Map<String, dynamic>).toList());
  }
}
