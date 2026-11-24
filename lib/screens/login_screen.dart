
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
  static const Color _background = Color(0xFF050208);

  // Original signup image dimensions.
  static const double _designWidth = 901;
  static const double _designHeight = 1600;

  final AuthService _auth = AuthService();

  final TextEditingController _identityCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _usernameCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();

  bool _isSignup = true;
  bool _loading = false;
  bool _hidePassword = true;

  String _dialCode = '+92';

  String _normalizedPhone(String value) {
    final cleaned = value.trim().replaceAll(
      RegExp(r'[\s()-]'),
      '',
    );

    return cleaned.startsWith('+')
        ? cleaned
        : '$_dialCode$cleaned';
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF210B35),
        behavior: SnackBarBehavior.floating,
      ),
    );
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

  Future<void> _submit() async {
    final password = _passwordCtrl.text;

    final email = _isSignup
        ? _emailCtrl.text.trim()
        : (_identityCtrl.text.trim().contains('@')
            ? _identityCtrl.text.trim()
            : '');

    final phone = _isSignup
        ? _phoneCtrl.text.trim()
        : (email.isEmpty ? _identityCtrl.text.trim() : '');

    if (_isSignup) {
      if (phone.isEmpty ||
          email.isEmpty ||
          _usernameCtrl.text.trim().isEmpty) {
        _showMessage(
          'Phone, email and username are required.',
        );
        return;
      }

      if (password.length < 6) {
        _showMessage(
          'Password must be at least 6 characters.',
        );
        return;
      }
    } else {
      if (_identityCtrl.text.trim().isEmpty ||
          password.isEmpty) {
        _showMessage(
          'Enter your email/phone and password.',
        );
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
              phone: phone.isEmpty
                  ? ''
                  : _normalizedPhone(phone),
              email: email,
              password: password,
            );

      if (credential.user == null) {
        throw Exception(
          'Authentication could not be completed.',
        );
      }

      AppState.instance.uid = credential.user!.uid;

      await _auth.ensureSupabaseRole();

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const HomeScreen(),
        ),
      );
    } on FirebaseAuthException catch (error) {
      _showMessage(_friendlyError(error));
    } catch (error) {
      _showMessage(
        error.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _forgotPassword() async {
    final controller = TextEditingController(
      text: _identityCtrl.text.contains('@')
          ? _identityCtrl.text.trim()
          : '',
    );

    bool sending = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF160B20),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(26),
        ),
        side: BorderSide(color: _gold, width: 1),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                22,
                25,
                22,
                MediaQuery.of(context).viewInsets.bottom + 25,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Forgot Password?',
                    style: TextStyle(
                      color: _lightGold,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 9),
                  const Text(
                    'Enter your registered email address and we will send you a reset link.',
                    style: TextStyle(
                      color: Colors.white70,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Email Address',
                      hintStyle: const TextStyle(
                        color: Colors.white54,
                      ),
                      prefixIcon: const Icon(
                        Icons.email_outlined,
                        color: _gold,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: const BorderSide(color: _gold),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: const BorderSide(
                          color: _purple,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 17),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: sending
                          ? null
                          : () async {
                              if (controller.text.trim().isEmpty) {
                                _showMessage(
                                  'Enter your email address.',
                                );
                                return;
                              }

                              setSheetState(
                                () => sending = true,
                              );

                              try {
                                await _auth.sendPasswordReset(
                                  controller.text.trim(),
                                );

                                if (sheetContext.mounted) {
                                  Navigator.pop(sheetContext);
                                }

                                _showMessage(
                                  'If the account exists, a reset link has been sent.',
                                );
                              } on FirebaseAuthException catch (error) {
                                setSheetState(
                                  () => sending = false,
                                );

                                _showMessage(
                                  error.message ??
                                      'Could not send reset email.',
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF351052),
                        foregroundColor: _lightGold,
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                        ),
                        shape: const StadiumBorder(),
                      ),
                      child: Text(
                        sending
                            ? 'SENDING...'
                            : 'SEND RESET LINK',
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    controller.dispose();
  }

  void _toggleMode() {
    if (_loading) return;

    setState(() {
      _isSignup = !_isSignup;

      _identityCtrl.clear();
      _phoneCtrl.clear();
      _emailCtrl.clear();
      _usernameCtrl.clear();
      _passwordCtrl.clear();

      _hidePassword = true;
    });
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

  // Convert original image coordinates to the current screen.
  Positioned _designPosition({
    required double scale,
    required double cropX,
    required double cropY,
    required double x,
    required double y,
    required double width,
    required double height,
    required Widget child,
  }) {
    return Positioned(
      left: x * scale - cropX,
      top: y * scale - cropY,
      width: width * scale,
      height: height * scale,
      child: child,
    );
  }

  Widget _inputBox({
    required TextEditingController controller,
    required String hint,
    required double scale,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    bool isPhone = false,
    Widget? suffix,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xF2100B18),
        borderRadius: BorderRadius.circular(35 * scale),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: 9 * scale,
      ),
      alignment: Alignment.center,
      child: Row(
        children: [
          if (isPhone)
            SizedBox(
              width: 115 * scale,
              child: CountryCodePicker(
                initialSelection: 'PK',
                showCountryOnly: false,
                showOnlyCountryWhenClosed: false,
                showFlag: true,
                showFlagDialog: true,
                hideSearch: false,
                comparator: (a, b) =>
                    (a.name ?? '').compareTo(b.name ?? ''),
                favorite: const [
                  'PK',
                  'AE',
                  'SA',
                  'GB',
                  'US',
                ],
                padding: EdgeInsets.zero,
                textStyle: TextStyle(
                  color: _lightGold,
                  fontSize: 21 * scale,
                ),
                dialogTextStyle: TextStyle(
                  color: Colors.black,
                  fontSize: 20 * scale,
                ),
                onChanged: (country) {
                  _dialCode = country.dialCode ?? '+92';
                },
                onInit: (country) {
                  _dialCode = country?.dialCode ?? '+92';
                },
              ),
            ),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              obscureText: obscureText,
              textAlignVertical: TextAlignVertical.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 26 * scale,
              ),
              cursorColor: _gold,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(
                  color: Colors.white70,
                  fontSize: 25 * scale,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 8 * scale,
                  vertical: 8 * scale,
                ),
                suffixIcon: suffix,
                suffixIconConstraints: BoxConstraints(
                  minWidth: 42 * scale,
                  minHeight: 42 * scale,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _passwordSuffix(double scale) {
    return IconButton(
      padding: EdgeInsets.zero,
      onPressed: () {
        setState(() {
          _hidePassword = !_hidePassword;
        });
      },
      icon: Icon(
        _hidePassword
            ? Icons.visibility_off
            : Icons.visibility,
        color: _gold,
        size: 27 * scale,
      ),
    );
  }

  Widget _signupButton(double scale) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(60 * scale),
        onTap: _loading ? null : _submit,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (!_isSignup)
              Text(
                'LOG IN',
                style: TextStyle(
                  color: _lightGold,
                  fontSize: 37 * scale,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 8 * scale,
                  shadows: const [
                    Shadow(
                      color: _gold,
                      blurRadius: 12,
                    ),
                  ],
                ),
              ),
            if (_loading)
              SizedBox(
                width: 38 * scale,
                height: 38 * scale,
                child: const CircularProgressIndicator(
                  color: _lightGold,
                  strokeWidth: 3,
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);

    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;

    return Scaffold(
      backgroundColor: _background,

      // The scroll view stays available while the keyboard is open.
      resizeToAvoidBottomInset: false,

      body: SafeArea(
        top: false,
        bottom: false,
        child: SingleChildScrollView(
          keyboardDismissBehavior:
              ScrollViewKeyboardDismissBehavior.onDrag,
          child: SizedBox(
            width: screenWidth,
            height: screenHeight,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                final h = constraints.maxHeight;

                // Cover the screen without stretching the original artwork.
                final scale = [
                  w / _designWidth,
                  h / _designHeight,
                ].reduce((a, b) => a > b ? a : b);

                final renderedWidth = _designWidth * scale;
                final renderedHeight = _designHeight * scale;

                final cropX = (renderedWidth - w) / 2;
                final cropY = (renderedHeight - h) / 2;

                return Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    // Signup artwork.
                    Positioned.fill(
                      child: Image.asset(
                        'assets/images/sitara_live_signup.png',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            decoration: const BoxDecoration(
                              gradient: RadialGradient(
                                colors: [
                                  Color(0xFF351052),
                                  Color(0xFF180923),
                                  Color(0xFF050208),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    if (_isSignup) ...[
                      // Phone number.
                      _designPosition(
                        scale: scale,
                        cropX: cropX,
                        cropY: cropY,
                        x: 208,
                        y: 697,
                        width: 620,
                        height: 85,
                        child: _inputBox(
                          controller: _phoneCtrl,
                          hint: 'Phone Number',
                          keyboardType: TextInputType.phone,
                          isPhone: true,
                          scale: scale,
                        ),
                      ),

                      // Email address.
                      _designPosition(
                        scale: scale,
                        cropX: cropX,
                        cropY: cropY,
                        x: 208,
                        y: 850,
                        width: 620,
                        height: 85,
                        child: _inputBox(
                          controller: _emailCtrl,
                          hint: 'Email Address',
                          keyboardType: TextInputType.emailAddress,
                          scale: scale,
                        ),
                      ),

                      // Password.
                      _designPosition(
                        scale: scale,
                        cropX: cropX,
                        cropY: cropY,
                        x: 208,
                        y: 1000,
                        width: 620,
                        height: 85,
                        child: _inputBox(
                          controller: _passwordCtrl,
                          hint: 'Password',
                          keyboardType: TextInputType.visiblePassword,
                          obscureText: _hidePassword,
                          suffix: _passwordSuffix(scale),
                          scale: scale,
                        ),
                      ),

                      // Username.
                      _designPosition(
                        scale: scale,
                        cropX: cropX,
                        cropY: cropY,
                        x: 208,
                        y: 1150,
                        width: 620,
                        height: 85,
                        child: _inputBox(
                          controller: _usernameCtrl,
                          hint: 'Username',
                          keyboardType: TextInputType.text,
                          scale: scale,
                        ),
                      ),
                    ] else ...[
                      // Hide the phone row in login mode.
                      _designPosition(
                        scale: scale,
                        cropX: cropX,
                        cropY: cropY,
                        x: 208,
                        y: 697,
                        width: 620,
                        height: 85,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xF2100B18),
                            borderRadius: BorderRadius.circular(
                              35 * scale,
                            ),
                          ),
                        ),
                      ),

                      // Login email or phone.
                      _designPosition(
                        scale: scale,
                        cropX: cropX,
                        cropY: cropY,
                        x: 208,
                        y: 850,
                        width: 620,
                        height: 85,
                        child: _inputBox(
                          controller: _identityCtrl,
                          hint: 'Email / Phone',
                          keyboardType: TextInputType.emailAddress,
                          scale: scale,
                        ),
                      ),

                      // Login password.
                      _designPosition(
                        scale: scale,
                        cropX: cropX,
                        cropY: cropY,
                        x: 208,
                        y: 1000,
                        width: 620,
                        height: 85,
                        child: _inputBox(
                          controller: _passwordCtrl,
                          hint: 'Password',
                          keyboardType: TextInputType.visiblePassword,
                          obscureText: _hidePassword,
                          suffix: _passwordSuffix(scale),
                          scale: scale,
                        ),
                      ),

                      // Forgot password replaces the username row.
                      _designPosition(
                        scale: scale,
                        cropX: cropX,
                        cropY: cropY,
                        x: 208,
                        y: 1150,
                        width: 620,
                        height: 85,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xF2100B18),
                            borderRadius: BorderRadius.circular(
                              35 * scale,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: TextButton(
                            onPressed: _loading
                                ? null
                                : _forgotPassword,
                            child: Text(
                              'Forgot Password?',
                              style: TextStyle(
                                color: _lightGold,
                                fontSize: 25 * scale,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],

                    // Signup / Login artwork button is clickable.
                    _designPosition(
                      scale: scale,
                      cropX: cropX,
                      cropY: cropY,
                      x: 94,
                      y: 1285,
                      width: 713,
                      height: 112,
                      child: _signupButton(scale),
                    ),

                    // Switch between signup and login.
                    _designPosition(
                      scale: scale,
                      cropX: cropX,
                      cropY: cropY,
                      x: 145,
                      y: 1420,
                      width: 610,
                      height: 58,
                      child: TextButton(
                        onPressed: _toggleMode,
                        child: Text(
                          _isSignup
                              ? 'Already have an account? Login'
                              : "Don't have an account? Sign Up",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _lightGold,
                            fontSize: 22 * scale,
                            fontWeight: FontWeight.w600,
                            shadows: const [
                              Shadow(
                                color: _purple,
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
