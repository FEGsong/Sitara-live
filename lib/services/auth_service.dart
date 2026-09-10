import 'package:firebase_auth/firebase_auth.dart';
import 'firestore_service.dart';

/// Firebase Auth's email/password provider stores the password
/// securely. Signup now collects a REAL email address (in addition
/// to phone + username) so Firebase can send a free, built-in
/// password-reset link straight to the user's inbox — no SMS, no
/// Cloud Function, no paid plan needed.
///
/// Users still log in with PHONE + PASSWORD: on sign-in we look up
/// the account's real email from Firestore (by phone number) and
/// use that to authenticate behind the scenes.
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
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await _firestore.createUserProfile(
      uid: cred.user!.uid,
      phone: phone,
      email: email,
      username: username,
    );
    return cred;
  }

  Future<UserCredential> signIn({
    required String phone,
    required String password,
  }) async {
    final email = await _firestore.getEmailByPhone(phone);
    if (email == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'No account found for this phone number',
      );
    }
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signOut() => _auth.signOut();

  /// Sends Firebase's built-in password-reset email to the address
  /// the user types in the "Forgot Password" screen. Firebase
  /// handles the link, the reset page, and the new-password form —
  /// completely free, no extra setup beyond the template in the
  /// Firebase Console (already configured).
  Future<void> sendPasswordReset(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }
}
