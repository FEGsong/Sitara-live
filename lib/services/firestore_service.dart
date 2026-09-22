import 'package:cloud_firestore/cloud_firestore.dart';

/// All Firestore reads/writes live here so screens never talk to
/// Firestore directly — makes it easy to swap the backend later.
class FirestoreService {
  final _db = FirebaseFirestore.instance;
  CollectionReference get _users => _db.collection('users');
  CollectionReference get _requests => _db.collection('coin_requests');
  CollectionReference get _rooms => _db.collection('rooms');
  CollectionReference get _follows => _db.collection('follows');
  CollectionReference get _announcements => _db.collection('announcements');
  CollectionReference get _posts => _db.collection('posts');

  /// Normalizes a Pakistani phone number to the stored format
  /// (+92XXXXXXXXXX) regardless of how the admin typed it —
  /// accepts "03XX...", "3XX...", or "+923XX..." forms.
  String _normalizePhone(String input) {
    var digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('92')) {
      digits = digits.substring(2);
    } else if (digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    return '+92$digits';
  }

  // ---- User profile ----

  Future<void> createUserProfile({
    required String uid,
    required String phone,
    required String email,
    required String username,
  }) async {
    await _users.doc(uid).set({
      'phone': phone,
      'email': email,
      'username': username,
      'nickname': username,
      'profilePublic': true,
      'coins': 150,
      'earningsPKR': 0,
      'giftsSent': 0,
      'giftsReceived': 0,
      'isAdmin': false,
      'isCoinSeller': false,
      'isVerified': false,
      'followersCount': 0,
      'followingCount': 0,
      'profileViews': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<DocumentSnapshot> userDoc(String uid) => _users.doc(uid).snapshots();

  Future<String?> getEmailByPhone(String phone) async {
    final q = await _users.where('phone', isEqualTo: phone).limit(1).get();
    if (q.docs.isEmpty) return null;
    final data = q.docs.first.data() as Map<String, dynamic>;
    return data['email'] as String?;
  }

  Future<void> updateProfile(String uid,
      {String? username, String? nickname, bool? profilePublic}) {
    final data = <String, dynamic>{};
    if (username != null) data['username'] = username;
    if (nickname != null) data['nickname'] = nickname;
    if (profilePublic != null) data['profilePublic'] = profilePublic;
    return _users.doc(uid).update(data);
  }

  Future<void> spendCoins(String uid, int amount, {String reason = 'Coins spent'}) async {
    await _users.doc(uid).update({'coins': FieldValue.increment(-amount)});
    await _logTransaction(uid, title: reason, amount: -amount);
  }

  Future<void> addCoins(String uid, int amount, {String reason = 'Coins added'}) async {
    await _users.doc(uid).update({'coins': FieldValue.increment(amount)});
    await _logTransaction(uid, title: reason, amount: amount);
  }

  Future<void> addEarnings(String uid, double amount) {
    return _users.doc(uid).update({
      'earningsPKR': FieldValue.increment(amount),
      'giftsReceived': FieldValue.increment(1),
    });
  }

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

  Future<bool> makeAdminByPhone(String phone) async {
    final normalized = _normalizePhone(phone);
    final q = await _users.where('phone', isEqualTo: normalized).limit(1).get();
    if (q.docs.isEmpty) return false;
    await q.docs.first.reference.update({'isAdmin': true});
    return true;
  }

  Future<void> removeAdmin(String uid) =>
      _users.doc(uid).update({'isAdmin': false});

  // ---- Coin sellers ----

  Future<bool> makeCoinSellerByPhone(String phone) async {
    final normalized = _normalizePhone(phone);
    final q = await _users.where('phone', isEqualTo: normalized).limit(1).get();
    if (q.docs.isEmpty) return false;
    await q.docs.first.reference.update({'isCoinSeller': true});
    return true;
  }

  Future<void> removeCoinSeller(String uid) =>
      _users.doc(uid).update({'isCoinSeller': false});

  Stream<List<Map<String, dynamic>>> allCoinSellers() {
    return _users.where('isCoinSeller', isEqualTo: true).snapshots().map(
          (snap) => snap.docs
              .map((d) => {'uid': d.id, ...d.data() as Map<String, dynamic>})
              .toList(),
        );
  }

  // ---- Verified / official accounts ----

  Future<bool> makeVerifiedByPhone(String phone) async {
    final normalized = _normalizePhone(phone);
    final q = await _users.where('phone', isEqualTo: normalized).limit(1).get();
    if (q.docs.isEmpty) return false;
    await q.docs.first.reference.update({'isVerified': true});
    return true;
  }

  Future<void> removeVerified(String uid) =>
      _users.doc(uid).update({'isVerified': false});

  Stream<List<Map<String, dynamic>>> allVerified() {
    return _users.where('isVerified', isEqualTo: true).snapshots().map(
          (snap) => snap.docs
              .map((d) => {'uid': d.id, ...d.data() as Map<String, dynamic>})
              .toList(),
        );
  }

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
    await _logTransaction(uid, title: 'Coins purchased', amount: coins);
  }

  // ---- Audio rooms ----

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
      'seats': List<dynamic>.filled(seatCount, null, growable: true),
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
    final options = [
      [0xFFFF2E6B, 0xFF7A1BFF],
      [0xFF2DE8C4, 0xFF12707F],
      [0xFFFFC93C, 0xFFB5641A],
      [0xFF7A1BFF, 0xFFFF2E6B],
    ];
    options.shuffle();
    return options.first;
  }

  Stream<List<Map<String, dynamic>>> liveRooms() {
    return _rooms.where('status', isEqualTo: 'live').snapshots().map(
          (snap) => snap.docs
              .map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>})
              .toList(),
        );
  }

  Stream<List<Map<String, dynamic>>> topLiveRooms({int limit = 10}) {
    return _rooms
        .where('status', isEqualTo: 'live')
        .snapshots()
        .map((snap) {
      final rooms = snap.docs
          .map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>})
          .toList();
      rooms.sort((a, b) =>
          ((b['viewers'] ?? 0) as int).compareTo((a['viewers'] ?? 0) as int));
      return rooms.take(limit).toList();
    });
  }

  Stream<DocumentSnapshot> roomDoc(String roomId) =>
      _rooms.doc(roomId).snapshots();

  Future<DocumentSnapshot> getRoomOnce(String roomId) =>
      _rooms.doc(roomId).get();

  Stream<Map<String, dynamic>?> myActiveRoom(String uid) {
    return _rooms
        .where('hostUid', isEqualTo: uid)
        .where('status', isEqualTo: 'live')
        .limit(1)
        .snapshots()
        .map((snap) {
      if (snap.docs.isEmpty) return null;
      final d = snap.docs.first;
      return {'id': d.id, ...d.data() as Map<String, dynamic>};
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
      if (seats[seatIndex] != null) return;
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

  // ---- Recently visited rooms (per user) ----

  CollectionReference _recentRoomsCol(String uid) =>
      _users.doc(uid).collection('recent_rooms');

  Future<void> recordRecentRoom({
    required String uid,
    required String roomId,
    required String hostName,
    required int c1,
    required int c2,
  }) {
    return _recentRoomsCol(uid).doc(roomId).set({
      'roomId': roomId,
      'hostName': hostName,
      'c1': c1,
      'c2': c2,
      'visitedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<Map<String, dynamic>>> recentRooms(String uid) {
    return _recentRoomsCol(uid)
        .orderBy('visitedAt', descending: true)
        .limit(10)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => d.data() as Map<String, dynamic>)
            .toList());
  }

  // ---- Follow / Following system ----

  String _followDocId(String followerId, String followingId) =>
      '${followerId}_$followingId';

  Future<void> followUser(String followerId, String targetId) async {
    if (followerId == targetId) return;
    final docId = _followDocId(followerId, targetId);
    final batch = _db.batch();
    batch.set(_follows.doc(docId), {
      'followerId': followerId,
      'followingId': targetId,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(
        _users.doc(followerId), {'followingCount': FieldValue.increment(1)});
    batch.update(
        _users.doc(targetId), {'followersCount': FieldValue.increment(1)});
    await batch.commit();
  }

  Future<void> unfollowUser(String followerId, String targetId) async {
    final docId = _followDocId(followerId, targetId);
    final batch = _db.batch();
    batch.delete(_follows.doc(docId));
    batch.update(
        _users.doc(followerId), {'followingCount': FieldValue.increment(-1)});
    batch.update(
        _users.doc(targetId), {'followersCount': FieldValue.increment(-1)});
    await batch.commit();
  }

  Stream<bool> isFollowing(String followerId, String targetId) {
    final docId = _followDocId(followerId, targetId);
    return _follows.doc(docId).snapshots().map((snap) => snap.exists);
  }

  Future<Map<String, dynamic>?> getUserById(String uid) async {
    final snap = await _users.doc(uid).get();
    if (!snap.exists) return null;
    return {'uid': snap.id, ...snap.data() as Map<String, dynamic>};
  }

  Future<Map<String, dynamic>?> findUserByUsername(String username) async {
    final q =
        await _users.where('username', isEqualTo: username).limit(1).get();
    if (q.docs.isEmpty) return null;
    final d = q.docs.first;
    return {'uid': d.id, ...d.data() as Map<String, dynamic>};
  }

  Stream<List<Map<String, dynamic>>> followersOf(String uid) {
    return _follows
        .where('followingId', isEqualTo: uid)
        .snapshots()
        .asyncMap((snap) async {
      final followerIds = snap.docs
          .map((d) => (d.data() as Map<String, dynamic>)['followerId'] as String)
          .toList();
      if (followerIds.isEmpty) return <Map<String, dynamic>>[];
      final docs = await Future.wait(followerIds.map((id) => _users.doc(id).get()));
      return docs
          .where((d) => d.exists)
          .map((d) => {'uid': d.id, ...d.data() as Map<String, dynamic>})
          .toList();
    });
  }

  Stream<List<Map<String, dynamic>>> newFaces({int limit = 30}) {
    return _users
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => {'uid': d.id, ...d.data() as Map<String, dynamic>})
            .toList());
  }

  Stream<List<Map<String, dynamic>>> topHosts({int limit = 10}) {
    return _users
        .orderBy('followersCount', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => {'uid': d.id, ...d.data() as Map<String, dynamic>})
            .toList());
  }

  Future<void> incrementProfileViews(String uid) {
    return _users.doc(uid).update({'profileViews': FieldValue.increment(1)});
  }

  // ---- Announcements ----

  Stream<List<Map<String, dynamic>>> announcements() {
    return _announcements
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>})
            .toList());
  }

  // ---- Posts ----

  Future<void> createPost({
    required String uid,
    required String authorName,
    required String text,
    String? mediaUrl,
    String? mediaType,
  }) {
    return _posts.add({
      'uid': uid,
      'authorName': authorName,
      'text': text,
      'mediaUrl': mediaUrl,
      'mediaType': mediaType,
      'likesCount': 0,
      'commentsCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<Map<String, dynamic>>> latestPosts({int limit = 50}) {
    return _posts
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>})
            .toList());
  }

  CollectionReference _postLikes(String postId) =>
      _posts.doc(postId).collection('likes');

  Future<void> likePost(String postId, String uid) async {
    final batch = _db.batch();
    batch.set(_postLikes(postId).doc(uid), {'likedAt': FieldValue.serverTimestamp()});
    batch.update(_posts.doc(postId), {'likesCount': FieldValue.increment(1)});
    await batch.commit();
  }

  Future<void> unlikePost(String postId, String uid) async {
    final batch = _db.batch();
    batch.delete(_postLikes(postId).doc(uid));
    batch.update(_posts.doc(postId), {'likesCount': FieldValue.increment(-1)});
    await batch.commit();
  }

  Stream<bool> isPostLiked(String postId, String uid) {
    return _postLikes(postId).doc(uid).snapshots().map((snap) => snap.exists);
  }

  // ---- Post comments ----

  CollectionReference _postComments(String postId) =>
      _posts.doc(postId).collection('comments');

  Future<void> addComment({
    required String postId,
    required String uid,
    required String authorName,
    required String text,
  }) async {
    final batch = _db.batch();
    batch.set(_postComments(postId).doc(), {
      'uid': uid,
      'authorName': authorName,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(_posts.doc(postId), {'commentsCount': FieldValue.increment(1)});
    await batch.commit();
  }

  Stream<List<Map<String, dynamic>>> commentsOf(String postId) {
    return _postComments(postId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>})
            .toList());
  }

  // ---- Transaction history (per user) ----

  CollectionReference _transactionsCol(String uid) =>
      _users.doc(uid).collection('transactions');

  Future<void> _logTransaction(String uid,
      {required String title, required int amount}) {
    return _transactionsCol(uid).add({
      'title': title,
      'amount': amount,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<Map<String, dynamic>>> transactionsOf(String uid, {int limit = 100}) {
    return _transactionsCol(uid)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>})
            .toList());
      /// Prefix search on username — powers live suggestions as the user
  /// types in the search bar. Firestore doesn't support "contains",
  /// so this matches usernames starting with [prefix].
  Future<List<Map<String, dynamic>>> searchUsersByPrefix(String prefix, {int limit = 10}) async {
    if (prefix.isEmpty) return [];
    final q = await _users
        .orderBy('username')
        .startAt([prefix])
        .endAt(['$prefix\uf8ff'])
        .limit(limit)
        .get();
    return q.docs
        .map((d) => {'uid': d.id, ...d.data() as Map<String, dynamic>})
        .toList();
  }
  
}
