import 'package:flutter/foundation.dart';

/// Small shared cache of the logged-in user's data. The real source of
/// truth is Firestore (see FirestoreService) — this just mirrors the
/// latest snapshot so widgets can read it without a StreamBuilder
/// everywhere. Call [syncFromFirestore] wherever you listen to the
/// user's document (e.g. in HomeScreen's initState).
class AppState extends ChangeNotifier {
  AppState._();
  static final AppState instance = AppState._();
  static const String ownerPhone = '+923289647724'; 
  String uid = '';
  String phone = '';
  String username = '';
  String nickname = '';
  bool profilePublic = true;

  int coins = 500;
  double earningsPKR = 0;
  int giftsSent = 0;
  int giftsReceived = 0;

  bool adminMode = false;
  bool isAdmin = false;
  bool get isOwnerOrAdmin => phone == ownerPhone || isAdmin;
  /// Called from a Firestore snapshot listener to keep local state
  /// in sync with the database.
  void syncFromFirestore(Map<String, dynamic> data) {
    phone = data['phone'] ?? phone;
    username = data['username'] ?? username;
    nickname = data['nickname'] ?? nickname;
    profilePublic = data['profilePublic'] ?? profilePublic;
    profilePublic = data['profilePublic'] ?? profilePublic;
    isAdmin = data['isAdmin'] ?? isAdmin;
    coins = data['coins'] ?? coins;
    earningsPKR = (data['earningsPKR'] ?? earningsPKR).toDouble();
    giftsSent = data['giftsSent'] ?? giftsSent;
    giftsReceived = data['giftsReceived'] ?? giftsReceived;
    notifyListeners();
  }

  void reset() {
    uid = '';
    phone = '';
    username = '';
    nickname = '';
    isAdmin = false;
    coins = 150;
    earningsPKR = 0;
    giftsSent = 0;
    giftsReceived = 0;
    notifyListeners();
  }
}
