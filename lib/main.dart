import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:app_links/app_links.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'models/app_state.dart';
import 'services/firestore_service.dart';
import 'services/referral_prefs.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const SitaraLiveApp());
}

class SitaraLiveApp extends StatelessWidget {
  const SitaraLiveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sitara Live',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const AuthGate(),
    );
  }
}

/// Decides which screen to show first, and also listens for an
/// "sitaralive://invite/{uid}" link (from a shared invite) so a
/// brand-new user's account can be linked to whoever invited them.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _appLinks = AppLinks();

  @override
  void initState() {
    super.initState();
    _listenForInviteLinks();
  }

  void _listenForInviteLinks() {
    _appLinks.uriLinkStream.listen(_handleUri);
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) _handleUri(uri);
    });
  }

  void _handleUri(Uri uri) {
    // sitaralive://invite/{uid}
    if (uri.host == 'invite' && uri.pathSegments.isNotEmpty) {
      ReferralPrefs.savePending(uri.pathSegments.first);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snap.data;
        if (user == null) {
          return const LoginScreen();
        }

        return FutureBuilder(
          future: _loadAppState(user.uid),
          builder: (context, loadSnap) {
            if (loadSnap.connectionState != ConnectionState.done) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            return const HomeScreen();
          },
        );
      },
    );
  }

  Future<void> _loadAppState(String uid) async {
    AppState.instance.uid = uid;
    final data = await FirestoreService().getUserById(uid);
    if (data != null) {
      AppState.instance.syncFromFirestore(data);
    }
  }
}
