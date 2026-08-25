import 'package:flutter/material.dart';

import '../../core/widgets.dart';
import '../../services/auth_service.dart';
import '../home/home_shell.dart';
import 'login_screen.dart';

/// Auth gate (docs/architecture.md section 3):
/// logged-out → login/register; logged-in → home.
class AuthGate extends StatelessWidget {
  final AuthService authService;

  const AuthGate({super.key, required this.authService});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: LoadingView());
        }
        if (snapshot.hasData) {
          return const HomeShell();
        }
        return const LoginScreen();
      },
    );
  }
}
