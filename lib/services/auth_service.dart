import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import 'firestore_service.dart';

/// Firebase Auth's email/password provider stores the password securely.
class AuthService {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirestoreService();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signUp({
    required String phone,
    required String email,
    required String password,
    required String username,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    await _firestore.createUserProfile(
      uid: cred.user!.uid, phone: phone, email: email, username: username,
    );
    return cred;
  }

  /// Sign in with either the registered email or registered phone number.
  Future<UserCredential> signIn({
    required String phone,
    String? email,
    required String password,
  }) async {
    final emailAddress = (email ?? '').trim();
    if (emailAddress.isNotEmpty) {
      return _auth.signInWithEmailAndPassword(email: emailAddress, password: password);
    }
    final normalizedPhone = phone.trim();
    if (normalizedPhone.isEmpty) {
      throw FirebaseAuthException(code: 'invalid-credential',
        message: 'Enter your phone number or email address.');
    }
    final accountEmail = await _firestore.getEmailByPhone(normalizedPhone);
    if (accountEmail == null) {
      throw FirebaseAuthException(code: 'user-not-found',
        message: 'No account found for this phone number');
    }
    return _auth.signInWithEmailAndPassword(email: accountEmail, password: password);
  }

  /// Requests the trusted server to add Supabase's required custom role.
  Future<void> ensureSupabaseRole() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Please sign in again.');
    final idToken = await user.getIdToken(true);
    final uri = Uri.parse('${AppConfig.tokenServerUrl}/ensure-supabase-role');
    final response = await http.post(uri,
      headers: {'Authorization': 'Bearer $idToken', 'Content-Type': 'application/json'},
      body: jsonEncode({}),
    ).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw Exception('Server role setup failed (${response.statusCode}). Please try again later.');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['success'] != true) throw Exception('Could not enable secure storage access.');
    if (data['tokenRefreshRequired'] == true) await user.getIdToken(true);
  }

  Future<void> signOut() => _auth.signOut();
  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());
}
