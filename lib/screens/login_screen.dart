import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import '../models/app_state.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = AuthService();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();

  bool _isSignup = true;
  bool _loading = false;
  bool _obscurePassword = true;
  String _fullPhone() => '+92${_phoneCtrl.text.trim()}';

  Future<void> _submit() async {
    final phone = _phoneCtrl.text.trim();
    final password = _passwordCtrl.text.trim();

    if (phone.isEmpty) {
      _toast('Phone number is required');
      return;
    }
    if (password.isEmpty) {
      _toast('Password is required');
      return;
    }

    setState(() => _loading = true);
    try {
      if (_isSignup) {
        final cred = await _auth.signUp(
          phone: _fullPhone(),
          password: password,
          username: _usernameCtrl.text.trim(),
        );
        AppState.instance.uid = cred.user!.uid;
      } else {
        final cred =
            await _auth.signIn(phone: _fullPhone(), password: password);
        AppState.instance.uid = cred.user!.uid;
      }

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } on FirebaseAuthException catch (e) {
      _toast(_friendlyError(e));
    } catch (e) {
      _toast('Something went wrong: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'An account with this phone number already exists — try logging in instead';
      case 'weak-password':
        return 'Password should be at least 6 characters';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect phone number or password';
      default:
        return e.message ?? 'Authentication error';
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _openForgotPassword() {
    final resetPhoneCtrl = TextEditingController();
    final otpCtrl = TextEditingController();
    final newPasswordCtrl = TextEditingController();
    bool otpSent = false;
    bool sending = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 22,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 26,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Reset Password',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    otpSent
                        ? 'Enter the code sent to your phone, then set a new password'
                        : 'Enter your phone number — we will send you a verification code',
                    style:
                        const TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  if (!otpSent) ...[
                    TextField(
                      controller: resetPhoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration:
                          const InputDecoration(hintText: '+92 3XX XXXXXXX'),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: sending
                            ? null
                            : () async {
                                if (resetPhoneCtrl.text.trim().isEmpty) return;
                                setSheetState(() => sending = true);
                                await _auth.sendResetOtp(
                                  phone: resetPhoneCtrl.text.trim(),
                                  onCodeSent: () => setSheetState(() {
                                    sending = false;
                                    otpSent = true;
                                  }),
                                  onError: (err) {
                                    setSheetState(() => sending = false);
                                    _toast(err);
                                  },
                                );
                              },
                        child: Text(sending ? 'Sending...' : 'Send Code'),
                      ),
                    ),
                  ] else ...[
                    TextField(
                      controller: otpCtrl,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(hintText: '6-digit code'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: newPasswordCtrl,
                      obscureText: true,
                      decoration:
                          const InputDecoration(hintText: 'New password'),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          final ok = await _auth.confirmOtpAndResetPassword(
                            smsCode: otpCtrl.text.trim(),
                            newPassword: newPasswordCtrl.text.trim(),
                          );
                          Navigator.pop(ctx);
                          _toast(ok
                              ? '✅ Password reset — you can now log in'
                              : 'Could not verify code, please try again');
                        },
                        child: const Text('Reset Password'),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [AppColors.hot, Color(0xFF7A1BFF)]),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  alignment: Alignment.center,
                  child: Image.asset('assets/images/logo.png', width: 60, height: 60),
                ),
                const SizedBox(height: 14),
                const Text('Sitara Live',
                    style:
                        TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text('Go live, connect, and send gifts',
                    style: TextStyle(color: AppColors.muted, fontSize: 13)),
                const SizedBox(height: 20),
                Container(
                  decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      Expanded(
                          child: _tabButton('Sign Up', _isSignup,
                              () => setState(() => _isSignup = true))),
                      Expanded(
                          child: _tabButton('Log In', !_isSignup,
                              () => setState(() => _isSignup = false))),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _label('Phone Number *'),
                Row(
                  children: [
                    Container(
                      width: 64,
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        border: Border.all(color: AppColors.line),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('+92'),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration:
                            const InputDecoration(hintText: '3XX XXXXXXX'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _label('Password *'),
                TextField(
                  controller: _passwordCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(hintText: 'Enter password'),
                ),
                const SizedBox(height: 14),
                if (_isSignup) ...[
                  _label('Username'),
                  TextField(
  controller: _passwordCtrl,
  obscureText: _obscurePassword,
  decoration: InputDecoration(
    hintText: 'Enter password',
    suffixIcon: IconButton(
      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
    ),
  ),
),
                  const SizedBox(height: 14),
                ],
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    child: Text(_loading
                        ? 'Please wait...'
                        : (_isSignup ? 'Sign Up' : 'Log In')),
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _openForgotPassword,
                  child: const Text('Forgot Password?',
                      style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                          decoration: TextDecoration.underline)),
                ),
                const SizedBox(height: 8),
                const Text(
                    'By continuing you agree to our Terms & Privacy Policy',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted, fontSize: 11)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tabButton(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppColors.hot : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        alignment: Alignment.center,
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : AppColors.muted)),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6, top: 2),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(text,
              style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.muted,
                  fontWeight: FontWeight.w600,
                  letterSpacing: .5)),
        ),
      );
}
