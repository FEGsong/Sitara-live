import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'models/app_state.dart';
import 'services/firestore_service.dart';

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

/// Decides which screen to show first: if Firebase already has a
/// logged-in user (from a previous session), skip straight to
/// HomeScreen instead of asking them to log in again.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

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

        // User is already signed in — load their profile into
        // AppState before showing Home, so nickname/coins/etc. are
        // ready immediately instead of flashing empty values.
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
