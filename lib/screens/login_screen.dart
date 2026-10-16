
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:country_code_picker/country_code_picker.dart';

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
  final AuthService _auth = AuthService();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  final TextEditingController _usernameCtrl = TextEditingController();

  bool _isSignup = true;
  bool _loading = false;
  bool _obscurePassword = true;

  String _countryDialCode = '+92';

  String _fullPhone() {
    final phone = _phoneCtrl.text.trim();
    final cleanPhone = phone.replaceAll(RegExp(r'[\s()-]'), '');

    if (cleanPhone.startsWith('+')) {
      return cleanPhone;
    }

    return '$_countryDialCode$cleanPhone';
  }

  Future<void> _submit() async {
    final phone = _phoneCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (phone.isEmpty) {
      _toast('Phone number is required');
      return;
    }

    if (_isSignup && email.isEmpty) {
      _toast('Email is required');
      return;
    }

    if (password.trim().isEmpty) {
      _toast('Password is required');
      return;
    }

    if (_isSignup && password.length < 6) {
      _toast('Password should be at least 6 characters');
      return;
    }

    setState(() => _loading = true);

    try {
      if (_isSignup) {
        final cred = await _auth
            .signUp(
              phone: _fullPhone(),
              email: email,
              password: password,
              username: _usernameCtrl.text.trim(),
            )
            .timeout(
              const Duration(seconds: 30),
              onTimeout: () {
                throw Exception(
                  'Request timed out. Check your internet connection.',
                );
              },
            );

        if (cred.user == null) {
          throw Exception('Account creation failed. Please try again.');
        }

        AppState.instance.uid = cred.user!.uid;
      } else {
        final cred = await _auth.signIn(
          phone: _fullPhone(),
          password: password,
        );

        if (cred.user == null) {
          throw Exception('Login failed. Please try again.');
        }

        AppState.instance.uid = cred.user!.uid;
      }

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const HomeScreen(),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      _showError('Authentication Error', _friendlyError(e));
    } catch (e) {
      if (!mounted) return;

      _showError('Error', e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _friendlyError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'This email already exists. Try logging in.';
      case 'weak-password':
        return 'Password should be at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect phone number or password.';
      case 'network-request-failed':
        return 'Network error. Check your internet connection.';
      default:
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }

  void _showError(String title, String message) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _openForgotPassword() {
    final resetEmailCtrl = TextEditingController();
    bool sending = false;
    bool sent = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 22,
                bottom: MediaQuery.of(context).viewInsets.bottom + 26,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Reset Password',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    sent
                        ? 'Check your inbox for the password reset link.'
                        : 'Enter the email address linked to your account.',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (!sent) ...[
                    TextField(
                      controller: resetEmailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        hintText: 'you@example.com',
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: sending
                            ? null
                            : () async {
                                final email =
                                    resetEmailCtrl.text.trim();

                                if (email.isEmpty) {
                                  _toast('Enter your email address');
                                  return;
                                }

                                setSheetState(() => sending = true);

                                try {
                                  await _auth.sendPasswordReset(email);

                                  if (!context.mounted) return;

                                  setSheetState(() {
                                    sending = false;
                                    sent = true;
                                  });
                                } on FirebaseAuthException catch (e) {
                                  if (!context.mounted) return;

                                  setSheetState(() => sending = false);
                                  _toast(
                                    e.message ??
                                        'Could not send reset email.',
                                  );
                                } catch (_) {
                                  if (!context.mounted) return;

                                  setSheetState(() => sending = false);
                                  _toast('Could not send reset email.');
                                }
                              },
                        child: Text(
                          sending ? 'Sending...' : 'Send Reset Link',
                        ),
                      ),
                    ),
                  ] else
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        child: const Text('Done'),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(resetEmailCtrl.dispose);
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _usernameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 28,
              vertical: 32,
            ),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        AppColors.hot,
                        Color(0xFF7A1BFF),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  alignment: Alignment.center,
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 60,
                    height: 60,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.star,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Sitara Live',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Go live, connect, and send gifts',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 20),

                // Sign Up and Log In tabs
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _tabButton(
                          'Sign Up',
                          _isSignup,
                          () => setState(() => _isSignup = true),
                        ),
                      ),
                      Expanded(
                        child: _tabButton(
                          'Log In',
                          !_isSignup,
                          () => setState(() => _isSignup = false),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                _label('Phone Number *'),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      height: 52,
                      constraints: const BoxConstraints(
                        minWidth: 105,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        border: Border.all(color: AppColors.line),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: CountryCodePicker(
                        initialSelection: 'PK',
                        favorite: const [
                          'PK',
                          'AE',
                          'SA',
                          'GB',
                          'US',
                        ],
                        showCountryOnly: false,
                        showOnlyCountryWhenClosed: false,
                        showFlag: true,
                        showFlagDialog: true,
                        hideSearch: false,
                        comparator: (a, b) =>
                            (a.name ?? '').compareTo(b.name ?? ''),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                        ),
                        textStyle: const TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                        ),
                        searchDecoration: const InputDecoration(
                          hintText: 'Search country or code',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (country) {
                          setState(() {
                            _countryDialCode =
                                country.dialCode ?? '+92';
                          });
                        },
                        onInit: (country) {
                          _countryDialCode =
                              country?.dialCode ?? '+92';
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          hintText: 'Phone number',
                        ),
                      ),
                    ),
                  ],
                ),

                if (_isSignup) ...[
                  const SizedBox(height: 14),
                  _label('Email *'),
                  TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      hintText: 'you@example.com',
                    ),
                  ),
                ],

                const SizedBox(height: 14),
                _label('Password *'),
                TextField(
                  controller: _passwordCtrl,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    hintText: 'Enter password',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                ),

                if (_isSignup) ...[
                  const SizedBox(height: 14),
                  _label('Username'),
                  TextField(
                    controller: _usernameCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Enter username',
                    ),
                  ),
                ],

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    child: Text(
                      _loading
                          ? 'Please wait...'
                          : (_isSignup ? 'Sign Up' : 'Log In'),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _openForgotPassword,
                  child: const Text(
                    'Forgot Password?',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'By continuing you agree to our Terms & Privacy Policy',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tabButton(
    String label,
    bool active,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppColors.hot : Colors.black,
          borderRadius: BorderRadius.circular(9),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 6,
        top: 2,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.muted,
            fontWeight: FontWeight.w600,
            letterSpacing: .5,
          ),
        ),
      ),
    );
  }
}
l
