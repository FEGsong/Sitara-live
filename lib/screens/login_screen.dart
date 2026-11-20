import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:country_code_picker/country_code_picker.dart';
import '../models/app_state.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const Color _gold = Color(0xFFFFD36A);
  static const Color _lightGold = Color(0xFFFFE9A8);
  static const Color _purple = Color(0xFFB52CFF);
  static const Color _deepPurple = Color(0xFF210B35);
  static const Color _background = Color(0xFF050208);

  final AuthService _auth = AuthService();
  final TextEditingController _identityCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _usernameCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();

  bool _isSignup = false;
  bool _loading = false;
  bool _hidePassword = true;
  String _dialCode = '+92';

  String _normalizedPhone(String value) {
    final cleaned = value.trim().replaceAll(RegExp(r'[\s()-]'), '');
    return cleaned.startsWith('+') ? cleaned : '$_dialCode$cleaned';
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _deepPurple,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _submit() async {
    final identity = _identityCtrl.text.trim();
    final password = _passwordCtrl.text;
    final email = _isSignup ? _emailCtrl.text.trim() : (identity.contains('@') ? identity : '');
    final phone = _isSignup ? _phoneCtrl.text.trim() : (identity.contains('@') ? '' : identity);

    if (_isSignup) {
      if (phone.isEmpty || email.isEmpty || _usernameCtrl.text.trim().isEmpty) {
        _showMessage('Phone, email and username are required.');
        return;
      }
      if (password.length < 6) {
        _showMessage('Password must be at least 6 characters.');
        return;
      }
    } else {
      if (identity.isEmpty || password.isEmpty) {
        _showMessage('Enter your email/phone and password.');
        return;
      }
    }

    setState(() => _loading = true);
    try {
      final credential = _isSignup
          ? await _auth.signUp(
              phone: _normalizedPhone(phone),
              email: email,
              password: password,
              username: _usernameCtrl.text.trim(),
            )
          : await _auth.signIn(
              phone: phone.isEmpty ? '' : _normalizedPhone(phone),
              email: email,
              password: password,
            );

      if (credential.user == null) {
        throw Exception('Authentication could not be completed.');
      }
      AppState.instance.uid = credential.user!.uid;
      await _auth.ensureSupabaseRole();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } on FirebaseAuthException catch (error) {
      _showMessage(_friendlyError(error));
    } catch (error) {
      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyError(FirebaseAuthException error) {
    switch (error.code) {
      case 'email-already-in-use':
        return 'This email is already registered. Please log in.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email/phone or password.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      default:
        return error.message ?? 'Authentication failed.';
    }
  }

  Future<void> _forgotPassword() async {
    final controller = TextEditingController(
      text: _identityCtrl.text.contains('@') ? _identityCtrl.text.trim() : '',
    );
    bool sending = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF160B20),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        side: BorderSide(color: _gold, width: 1),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            22, 25, 22, MediaQuery.of(context).viewInsets.bottom + 25,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Forgot Password?',
                style: TextStyle(
                  color: _lightGold, fontSize: 22, fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 9),
              const Text(
                'Enter your registered email address and we will send you a reset link.',
                style: TextStyle(color: Colors.white70, height: 1.45),
              ),
              const SizedBox(height: 18),
              _field(
                controller: controller,
                hint: 'Email Address',
                icon: Icons.mail_outline,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 17),
              _goldButton(
                label: sending ? 'SENDING...' : 'SEND RESET LINK',
                onPressed: sending
                    ? null
                    : () async {
                        if (controller.text.trim().isEmpty) {
                          _showMessage('Enter your email address.');
                          return;
                        }
                        setSheetState(() => sending = true);
                        try {
                          await _auth.sendPasswordReset(controller.text.trim());
                          if (sheetContext.mounted) {
                            Navigator.pop(sheetContext);
                          }
                          _showMessage('If the account exists, a reset link has been sent.');
                        } on FirebaseAuthException catch (error) {
                          setSheetState(() => sending = false);
                          _showMessage(error.message ?? 'Could not send reset email.');
                        }
                      },
              ),
            ],
          ),
        ),
      ),
    );
    controller.dispose();
  }

  @override
  void dispose() {
    _identityCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                const Positioned.fill(child: _RoyalBackdrop()),
                SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(25, 22, 25, 28),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight - 50),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 15),
                        _brand(),
                        const SizedBox(height: 24),
                        Text(
                          _isSignup ? 'CREATE ACCOUNT' : 'LOGIN',
                          style: const TextStyle(
                            color: _lightGold,
                            fontSize: 25,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 7,
                            shadows: [Shadow(color: _purple, blurRadius: 15)],
                          ),
                        ),
                        const SizedBox(height: 28),
                        if (_isSignup) ...[
                          _field(
                            controller: _phoneCtrl,
                            hint: 'Phone Number',
                            icon: Icons.phone_iphone,
                            keyboardType: TextInputType.phone,
                            prefix: _countryPicker(),
                          ),
                          const SizedBox(height: 17),
                          _field(
                            controller: _emailCtrl,
                            hint: 'Email Address',
                            icon: Icons.mail_outline,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 17),
                          _passwordField(),
                          const SizedBox(height: 17),
                          _field(
                            controller: _usernameCtrl,
                            hint: 'Username',
                            icon: Icons.person_outline,
                          ),
                        ] else ...[
                          _field(
                            controller: _identityCtrl,
                            hint: 'Email / Phone',
                            icon: Icons.mail_outline,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 19),
                          _passwordField(),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _loading ? null : _forgotPassword,
                              child: const Text(
                                'Forgot Password?',
                                style: TextStyle(
                                  color: _lightGold,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        _goldButton(
                          label: _loading
                              ? 'PLEASE WAIT...'
                              : (_isSignup ? 'SIGN UP' : 'LOGIN'),
                          onPressed: _loading ? null : _submit,
                        ),
                        const SizedBox(height: 25),
                        Container(
                          height: 1,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.transparent, _gold, _purple, Colors.transparent],
                            ),
                          ),
                        ),
                        const SizedBox(height: 17),
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              _isSignup ? 'Already have an account? ' : "Don't have an account? ",
                              style: const TextStyle(color: _lightGold, fontSize: 15),
                            ),
                            TextButton(
                              onPressed: _loading
                                  ? null
                                  : () => setState(() {
                                        _isSignup = !_isSignup;
                                        _identityCtrl.clear();
                                        _phoneCtrl.clear();
                                        _emailCtrl.clear();
                                        _usernameCtrl.clear();
                                        _passwordCtrl.clear();
                                      }),
                              child: Text(
                                _isSignup ? 'Login' : 'Sign Up',
                                style: const TextStyle(
                                  color: _purple,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _brand() {
    return Column(
      children: [
        Container(
          width: 132,
          height: 132,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: _gold, width: 1.6),
            boxShadow: const [
              BoxShadow(color: _purple, blurRadius: 24, spreadRadius: 1),
              BoxShadow(color: _gold, blurRadius: 12),
            ],
            gradient: const RadialGradient(
              colors: [Color(0xFF32104A), Color(0xFF08040D)],
            ),
          ),
          child: ClipOval(
            child: Padding(
              padding: const EdgeInsets.all(13),
              child: Image.asset(
                'assets/images/logo.png',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.auto_awesome,
                  color: _gold,
                  size: 70,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'SITARA',
          style: TextStyle(
            color: _lightGold,
            fontSize: 43,
            fontWeight: FontWeight.w700,
            letterSpacing: 8,
            shadows: [Shadow(color: _gold, blurRadius: 18)],
          ),
        ),
        const Text(
          'L I V E',
          style: TextStyle(
            color: _purple,
            fontSize: 21,
            fontWeight: FontWeight.bold,
            letterSpacing: 8,
          ),
        ),
        const SizedBox(height: 7),
        const Text(
          'LIVE YOUR MOMENT',
          style: TextStyle(color: _gold, fontSize: 10, letterSpacing: 4),
        ),
      ],
    );
  }

  Widget _countryPicker() {
    return CountryCodePicker(
      initialSelection: 'PK',
      showCountryOnly: false,
      showOnlyCountryWhenClosed: false,
      showFlag: true,
      showFlagDialog: true,
      hideSearch: false,
      comparator: (a, b) => (a.name ?? '').compareTo(b.name ?? ''),
      favorite: const ['PK', 'AE', 'SA', 'GB', 'US'],
      padding: const EdgeInsets.only(left: 8),
      textStyle: const TextStyle(color: _lightGold, fontSize: 13),
      onChanged: (country) => _dialCode = country.dialCode ?? '+92',
      onInit: (country) => _dialCode = country?.dialCode ?? '+92',
    );
  }

  Widget _passwordField() {
    return _field(
      controller: _passwordCtrl,
      hint: 'Password',
      icon: Icons.lock_outline,
      obscureText: _hidePassword,
      suffix: IconButton(
        onPressed: () => setState(() => _hidePassword = !_hidePassword),
        icon: Icon(
          _hidePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          color: _gold,
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffix,
    Widget? prefix,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(42),
        gradient: const LinearGradient(
          colors: [_lightGold, _purple, _gold, _purple, _lightGold],
        ),
        boxShadow: [
          BoxShadow(color: _purple.withOpacity(.28), blurRadius: 16),
          BoxShadow(color: _gold.withOpacity(.12), blurRadius: 20),
        ],
      ),
      padding: const EdgeInsets.all(1.7),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF100B18),
          borderRadius: BorderRadius.circular(40),
        ),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 15, right: 11),
              child: Icon(icon, color: _gold, size: 24),
            ),
            Container(width: 1, height: 30, color: _gold.withOpacity(.65)),
            if (prefix != null) prefix,
            Expanded(
              child: TextField(
                controller: controller,
                keyboardType: keyboardType,
                obscureText: obscureText,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: const TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 18),
                  suffixIcon: suffix,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _goldButton({required String label, required VoidCallback? onPressed}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(45),
        gradient: const LinearGradient(
          colors: [_lightGold, Color(0xFFB87918), _gold, Color(0xFF8B4B0B)],
        ),
        boxShadow: [
          BoxShadow(color: _gold.withOpacity(.25), blurRadius: 17),
          BoxShadow(color: _purple.withOpacity(.22), blurRadius: 14),
        ],
      ),
      padding: const EdgeInsets.all(2),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF170C20),
          disabledBackgroundColor: const Color(0xFF302034),
          foregroundColor: _lightGold,
          elevation: 0,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(vertical: 17),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: _lightGold,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 4,
          ),
        ),
      ),
    );
  }
}

class _RoyalBackdrop extends StatelessWidget {
  const _RoyalBackdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -.45),
          radius: 1.25,
          colors: [
            Color(0xFF351052),
            Color(0xFF180923),
            Color(0xFF09040F),
            Color(0xFF030207),
          ],
          stops: [0, .38, .76, 1],
        ),
      ),
      child: CustomPaint(painter: _CornerGlowPainter()),
    );
  }
}

class _CornerGlowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final gold = const Color(0xFFFFD36A);
    final purple = const Color(0xFFB52CFF);

    for (final isRight in [false, true]) {
      final x = isRight ? size.width : 0.0;
      final direction = isRight ? -1.0 : 1.0;
      final topPath = Path()
        ..moveTo(x, 0)
        ..cubicTo(x + direction * 70, 18, x + direction * 45, 80, x + direction * 115, 115);
      paint
        ..color = gold.withOpacity(.72)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawPath(topPath, paint);
      paint
        ..color = purple.withOpacity(.78)
        ..strokeWidth = 5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      canvas.drawPath(topPath, paint);

      final bottomPath = Path()
        ..moveTo(x, size.height)
        ..cubicTo(x + direction * 65, size.height - 25, x + direction * 45, size.height - 85, x + direction * 125, size.height - 120);
      paint
        ..color = gold.withOpacity(.72)
        ..strokeWidth = 2
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawPath(bottomPath, paint);
      paint
        ..color = purple.withOpacity(.78)
        ..strokeWidth = 5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      canvas.drawPath(bottomPath, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
