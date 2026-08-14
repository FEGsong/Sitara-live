import 'package:firebase_auth/firebase_auth.dart';
import 'firestore_service.dart';

/// Firebase Auth's email/password provider is what actually stores
/// the password securely — since we want PHONE + PASSWORD login
/// (not email), each phone number is mapped to a pseudo-email
/// like "923001234567@sitaralive.app". This is a common, safe pattern:
/// the "email" is never shown to the user or used to contact them.
class AuthService {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirestoreService();

  String _pseudoEmail(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    return '$digits@sitaralive.app';
  }

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signUp({
    required String phone,
    required String password,
    required String username,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: _pseudoEmail(phone),
      password: password,
    );
    await _firestore.createUserProfile(
      uid: cred.user!.uid,
      phone: phone,
      username: username,
    );
    return cred;
  }

  Future<UserCredential> signIn({
    required String phone,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(
      email: _pseudoEmail(phone),
      password: password,
    );
  }

  Future<void> signOut() => _auth.signOut();

  // ---- Forgot password (phone OTP → reset) ----
  //
  // Firebase can't email a reset link to a pseudo-address, so instead
  // we verify the phone number itself via SMS OTP (Firebase Phone Auth),
  // then call a Cloud Function that uses the Admin SDK to set the new
  // password on the matching email/password account.
  // See: functions/index.js → resetPasswordWithPhone

  String? _verificationId;

  Future<void> sendResetOtp({
    required String phone,
    required void Function() onCodeSent,
    required void Function(String error) onError,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phone,
      verificationCompleted: (_) {}, // Android auto-retrieval — not needed here
      verificationFailed: (e) => onError(e.message ?? 'Verification failed'),
      codeSent: (verificationId, resendToken) {
        _verificationId = verificationId;
        onCodeSent();
      },
      codeAutoRetrievalTimeout: (verificationId) {
        _verificationId = verificationId;
      },
    );
  }

  /// Verifies the SMS code, then calls the Cloud Function to apply the
  /// new password. Returns true on success.
  Future<bool> confirmOtpAndResetPassword({
    required String smsCode,
    required String newPassword,
  }) async {
    if (_verificationId == null) return false;

    final credential = PhoneAuthProvider.credential(
      verificationId: _verificationId!,
      smsCode: smsCode,
    );

    // Signing in with the phone credential proves the person owns this
    // number. We don't keep this session — we just need its ID token
    // to prove phone ownership to the Cloud Function.
    final phoneAuthResult = await _auth.signInWithCredential(credential);
    final idToken = await phoneAuthResult.user!.getIdToken();

    // TODO: call your deployed Cloud Function, e.g.:
    // final res = await http.post(
    //   Uri.parse('${AppConfig.tokenServerUrl}/resetPasswordWithPhone'),
    //   body: {'idToken': idToken, 'newPassword': newPassword},
    // );
    // return res.statusCode == 200;

    await _auth.signOut(); // clear the temporary phone session
    return idToken.isNotEmpty; // placeholder until the function call above is wired in
  }
}
