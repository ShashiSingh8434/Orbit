import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import 'login_page.dart';
import '../../home/views/home_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.instance.authStateChanges,
      builder: (context, snapshot) {
        // Show a loading splash while the auth state is being determined.
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _AuthLoadingSplash();
        }

        // User is signed in → show home.
        if (snapshot.hasData) {
          return const HomePage();
        }

        // User is signed out → show login.
        return const LoginPage();
      },
    );
  }
}

class _AuthLoadingSplash extends StatelessWidget {
  const _AuthLoadingSplash();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
