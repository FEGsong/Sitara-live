import 'package:flutter/foundation.dart';

class AppState extends ChangeNotifier {
  AppState._();
  static final AppState instance = AppState._();
  static const String ownerPhone = '+923289647724';
  String uid = '';
  String phone = '';
  String username = '';
  String nickname = '';
  String bio = '';
  String avatarUrl = '';
  bool profilePublic = true;

  int coins = 500;
  double earningsPKR = 0;
  int giftsSent = 0;
  int giftsReceived = 0;

  bool adminMode = false;
  bool isAdmin = false;
  bool get isOwnerOrAdmin => phone == ownerPhone || isAdmin;

  void syncFromFirestore(Map<String, dynamic> data) {
    phone = data['phone'] ?? phone;
    username = data['username'] ?? username;
    nickname = data['nickname'] ?? nickname;
    bio = data['bio'] ?? bio;
    avatarUrl = data['avatarUrl'] ?? avatarUrl;
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
    bio = '';
    avatarUrl = '';
    isAdmin = false;
    coins = 150;
    earningsPKR = 0;
    giftsSent = 0;
    giftsReceived = 0;
    notifyListeners();
  }
}
