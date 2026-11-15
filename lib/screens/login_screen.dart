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
  static const gold = Color(0xFFFFD36A);
  static const brightGold = Color(0xFFFFE7A0);
  static const purple = Color(0xFF9B35FF);
  static const bg = Color(0xFF050208);

  final _auth = AuthService();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  bool _isSignup = true, _loading = false, _obscurePassword = true;
  String _countryDialCode = '+92';

  String _fullPhone() {
    final phone = _phoneCtrl.text.trim().replaceAll(RegExp(r'[\s()-]'), '');
    return phone.startsWith('+') ? phone : '$_countryDialCode$phone';
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: const Color(0xFF321044)),
    );
  }

  Future<void> _submit() async {
    final phone = _phoneCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (_isSignup) {
      if (phone.isEmpty || email.isEmpty || _usernameCtrl.text.trim().isEmpty) {
        _toast('Phone number, email and username are required');
        return;
      }
      if (password.length < 6) {
        _toast('Password should be at least 6 characters');
        return;
      }
    } else {
      if (phone.isEmpty && email.isEmpty) {
        _toast('Enter your phone number or email address');
        return;
      }
      if (password.isEmpty) {
        _toast('Password is required');
        return;
      }
    }

    setState(() => _loading = true);
    try {
      final credential = _isSignup
          ? await _auth.signUp(
              phone: _fullPhone(), email: email, password: password,
              username: _usernameCtrl.text.trim(),
            ).timeout(const Duration(seconds: 30),
              onTimeout: () => throw Exception('Request timed out. Check your internet connection.'))
          : await _auth.signIn(
              phone: phone.isEmpty ? '' : _fullPhone(),
              email: email, password: password,
            );

      if (credential.user == null) throw Exception('Authentication failed.');
      AppState.instance.uid = credential.user!.uid;
      await _auth.ensureSupabaseRole();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } on FirebaseAuthException catch (e) {
      if (mounted) _showError('Authentication Error', _friendlyError(e));
    } catch (e) {
      if (mounted) _showError('Error', e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use': return 'This email already exists. Try logging in.';
      case 'weak-password': return 'Password should be at least 6 characters.';
      case 'invalid-email': return 'Please enter a valid email address.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential': return 'Incorrect phone/email or password.';
      case 'network-request-failed': return 'Network error. Check your internet connection.';
      default: return e.message ?? 'Authentication failed.';
    }
  }

  void _showError(String title, String message) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1B1024),
        title: Text(title, style: const TextStyle(color: brightGold)),
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx),
          child: const Text('OK', style: TextStyle(color: gold)))],
      ),
    );
  }

  Future<void> _forgotPassword() async {
    final controller = TextEditingController(text: _emailCtrl.text.trim());
    bool sending = false, sent = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF160B20),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: gold),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(22, 24, 22, MediaQuery.of(ctx).viewInsets.bottom + 28),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Forgot Password?', style: TextStyle(color: brightGold, fontSize: 21, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(sent ? 'If an account exists for this email, a reset link has been sent.' : 'Enter your registered email address to receive a reset link.', style: const TextStyle(color: Colors.white70, height: 1.5)),
              const SizedBox(height: 18),
              if (!sent) ...[
                _input(controller, 'Email Address', Icons.mail_outline, keyboard: TextInputType.emailAddress),
                const SizedBox(height: 16),
                _goldButton(sending ? 'SENDING...' : 'SEND RESET LINK', sending ? null : () async {
                  if (controller.text.trim().isEmpty) { _toast('Enter your email address'); return; }
                  setSheet(() => sending = true);
                  try {
                    await _auth.sendPasswordReset(controller.text.trim());
                    setSheet(() { sending = false; sent = true; });
                  } on FirebaseAuthException catch (e) {
                    setSheet(() => sending = false);
                    _toast(e.message ?? 'Could not send reset email.');
                  } catch (_) {
                    setSheet(() => sending = false);
                    _toast('Could not send reset email.');
                  }
                }),
              ] else
                _goldButton('DONE', () => Navigator.pop(sheetCtx)),
            ],
          ),
        ),
      ),
    );
    controller.dispose();
  }

  @override
  void dispose() {
    _phoneCtrl.dispose(); _emailCtrl.dispose(); _passwordCtrl.dispose(); _usernameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: Stack(children: [
        const Positioned.fill(child: _GalaxyBackdrop()),
        SafeArea(child: LayoutBuilder(builder: (context, constraints) =>
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight - 44),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const SizedBox(height: 8),
                Image.asset('assets/images/logo.png', width: 220, height: 185, fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(Icons.auto_awesome, size: 112, color: gold)),
                const Text('SITARA', style: TextStyle(fontFamily: 'serif', fontSize: 43, letterSpacing: 8, fontWeight: FontWeight.w700, color: brightGold, shadows: [Shadow(color: gold, blurRadius: 18)])),
                const Text('L I V E', style: TextStyle(color: purple, fontSize: 21, letterSpacing: 8, fontWeight: FontWeight.bold, shadows: [Shadow(color: purple, blurRadius: 12)])),
                const SizedBox(height: 7),
                const Text('LIVE YOUR MOMENT', style: TextStyle(color: gold, fontSize: 10, letterSpacing: 5)),
                const SizedBox(height: 28),
                if (!_isSignup) ...[
                  const Text('WELCOME BACK', style: TextStyle(color: brightGold, fontSize: 20, letterSpacing: 3, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 18),
                ],
                _phoneField(),
                const SizedBox(height: 14),
                _input(_emailCtrl, 'Email Address', Icons.mail_outline, keyboard: TextInputType.emailAddress),
                const SizedBox(height: 14),
                _input(_passwordCtrl, 'Password', Icons.lock_outline, obscure: _obscurePassword,
                  suffix: IconButton(
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: gold),
                  )),
                if (_isSignup) ...[
                  const SizedBox(height: 14),
                  _input(_usernameCtrl, 'Username', Icons.person_outline, keyboard: TextInputType.name),
                ] else ...[
                  const SizedBox(height: 8),
                  Align(alignment: Alignment.centerRight,
                    child: TextButton(onPressed: _forgotPassword,
                      child: const Text('Forgot Password?', style: TextStyle(color: brightGold, decoration: TextDecoration.underline)))),
                ],
                const SizedBox(height: 18),
                _goldButton(_loading ? 'PLEASE WAIT...' : (_isSignup ? '♛   SIGN UP   ➜' : '♛   LOGIN   ➜'),
                  _loading ? null : _submit),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: _loading ? null : () => setState(() { _isSignup = !_isSignup; _passwordCtrl.clear(); }),
                  child: RichText(textAlign: TextAlign.center, text: TextSpan(
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                    children: [
                      TextSpan(text: _isSignup ? 'Already have an account? ' : "Don't have an account? "),
                      TextSpan(text: _isSignup ? 'Login' : 'Sign Up',
                        style: const TextStyle(color: brightGold, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                    ],
                  )),
                ),
                const SizedBox(height: 24),
                const Text('✦   CONNECT   ✦   LIVE   ✦   GROW   ✦', style: TextStyle(color: gold, fontSize: 10, letterSpacing: 2.5)),
              ]),
            ),
          ),
        )),
      ]),
    );
  }

  Widget _phoneField() => _glowingField(Row(children: [
    CountryCodePicker(
      initialSelection: 'PK', favorite: const ['PK', 'AE', 'SA', 'GB', 'US'],
      showCountryOnly: false, showOnlyCountryWhenClosed: false, showFlag: true,
      showFlagDialog: true, hideSearch: false,
      comparator: (a, b) => (a.name ?? '').compareTo(b.name ?? ''),
      padding: const EdgeInsets.only(left: 5),
      textStyle: const TextStyle(color: brightGold, fontSize: 13),
      searchDecoration: const InputDecoration(hintText: 'Search country or code'),
      onChanged: (country) => setState(() => _countryDialCode = country.dialCode ?? '+92'),
      onInit: (country) => _countryDialCode = country?.dialCode ?? '+92',
    ),
    Container(width: 1, height: 28, color: gold.withOpacity(.65)),
    Expanded(child: TextField(controller: _phoneCtrl, keyboardType: TextInputType.phone,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: const InputDecoration(hintText: 'Phone Number', hintStyle: TextStyle(color: Colors.white70),
        border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none,
        filled: false, contentPadding: EdgeInsets.symmetric(horizontal: 13, vertical: 17)))),
  ]));

  Widget _input(TextEditingController controller, String hint, IconData icon,
      {TextInputType keyboard = TextInputType.text, bool obscure = false, Widget? suffix}) =>
    _glowingField(Row(children: [
      Padding(padding: const EdgeInsets.only(left: 13, right: 12), child: Icon(icon, color: gold, size: 25)),
      Container(width: 1, height: 28, color: gold.withOpacity(.65)),
      Expanded(child: TextField(controller: controller, keyboardType: keyboard, obscureText: obscure,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(hintText: hint, hintStyle: const TextStyle(color: Colors.white70),
          border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none,
          filled: false, contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 17), suffixIcon: suffix))),
    ]));

  Widget _glowingField(Widget child) => Container(
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(40),
      gradient: const LinearGradient(colors: [brightGold, purple, gold, purple, brightGold]),
      boxShadow: [BoxShadow(color: purple.withOpacity(.30), blurRadius: 13), BoxShadow(color: gold.withOpacity(.16), blurRadius: 18)]),
    padding: const EdgeInsets.all(1.7),
    child: Container(decoration: BoxDecoration(color: const Color(0xFF100B18), borderRadius: BorderRadius.circular(38)), child: child),
  );

  Widget _goldButton(String label, VoidCallback? onPressed) => Container(
    width: double.infinity,
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(40),
      gradient: const LinearGradient(colors: [brightGold, Color(0xFFB87918), gold, Color(0xFF8B4B0B)]),
      boxShadow: [BoxShadow(color: gold.withOpacity(.28), blurRadius: 17), BoxShadow(color: purple.withOpacity(.20), blurRadius: 12)]),
    padding: const EdgeInsets.all(2),
    child: ElevatedButton(onPressed: onPressed,
      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF170C20), foregroundColor: brightGold,
        disabledBackgroundColor: const Color(0xFF302034), elevation: 0, shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(vertical: 17)),
      child: Text(label, style: const TextStyle(color: brightGold, fontWeight: FontWeight.bold, letterSpacing: 3, fontSize: 15))),
  );
}

class _GalaxyBackdrop extends StatelessWidget {
  const _GalaxyBackdrop();
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: RadialGradient(
        center: Alignment(0, -.48),
        radius: 1.28,
        colors: [Color(0xFF351052), Color(0xFF180923), Color(0xFF09040F), Color(0xFF030207)],
        stops: [0, .38, .76, 1],
      ),
    ),
    child: CustomPaint(painter: _StarsPainter()),
  );
}

class _StarsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gold = const Color(0xFFFFD36A);
    final purple = const Color(0xFFB45CFF);
    final paint = Paint()..style = PaintingStyle.stroke;

    // Soft nebula haze behind the unchanged login form.
    paint
      ..style = PaintingStyle.fill
      ..color = purple.withOpacity(.075)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 42);
    canvas.drawCircle(Offset(size.width * .12, size.height * .28), size.width * .34, paint);
    canvas.drawCircle(Offset(size.width * .91, size.height * .62), size.width * .30, paint);

    // Fine celestial arcs add a subtle royal-galaxy frame without covering controls.
    paint
      ..style = PaintingStyle.stroke
      ..maskFilter = null
      ..strokeWidth = 1.1
      ..color = gold.withOpacity(.22);
    final arcRect = Rect.fromCenter(
      center: Offset(size.width * .5, size.height * .47),
      width: size.width * 1.42,
      height: size.height * .70,
    );
    canvas.drawArc(arcRect, 3.52, 2.28, false, paint);
    paint
      ..strokeWidth = .7
      ..color = purple.withOpacity(.30);
    canvas.drawArc(arcRect.deflate(13), 3.58, 2.16, false, paint);

    final points = <Offset>[
      Offset(size.width * .08, size.height * .12),
      Offset(size.width * .87, size.height * .10),
      Offset(size.width * .17, size.height * .33),
      Offset(size.width * .92, size.height * .37),
      Offset(size.width * .10, size.height * .67),
      Offset(size.width * .88, size.height * .72),
      Offset(size.width * .23, size.height * .88),
      Offset(size.width * .78, size.height * .91),
      Offset(size.width * .50, size.height * .06),
      Offset(size.width * .42, size.height * .96),
    ];
    for (var i = 0; i < points.length; i++) {
      final point = points[i];
      paint
        ..style = PaintingStyle.fill
        ..color = gold.withOpacity(i.isEven ? .78 : .48);
      canvas.drawCircle(point, i.isEven ? 1.7 : 1.1, paint);
      paint.color = purple.withOpacity(.16);
      canvas.drawCircle(point, i.isEven ? 6 : 4.5, paint);
    }

    // A few small four-point star glints near the outer edges.
    for (final point in [Offset(size.width * .06, size.height * .48), Offset(size.width * .94, size.height * .22), Offset(size.width * .83, size.height * .84)]) {
      paint
        ..color = gold.withOpacity(.55)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;
      canvas.drawLine(point.translate(-4, 0), point.translate(4, 0), paint);
      canvas.drawLine(point.translate(0, -4), point.translate(0, 4), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
