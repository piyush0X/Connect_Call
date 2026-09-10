import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../services/calling_service.dart';
import '../auth/login_screen.dart';
import '../home/home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final CallingService _callingService = CallingService();

  @override
  void initState() {
    super.initState();

    _checkAuthentication();
  }

  Future<void> _checkAuthentication() async {
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      try {
        // ==========================================
        // INITIALIZE ZEGOCLOUD
        // ==========================================

        await _callingService.initialize(
          userId: user.uid,
          userName: user.displayName ?? 'User',
        );

        debugPrint(
          'ZEGOCLOUD initialized for user: ${user.uid}',
        );
      } catch (e) {
        debugPrint(
          'ZEGOCLOUD initialization failed: $e',
        );
      }

      if (!mounted) return;

      // ==========================================
      // GO TO HOME
      // ==========================================

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const HomeScreen(),
        ),
      );
    } else {
      // ==========================================
      // NO USER → LOGIN
      // ==========================================

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const LoginScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.phone_in_talk,
              size: 90,
            ),

            const SizedBox(height: 20),

            const Text(
              'ConnectCall',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Connect with anyone, anywhere.',
              style: TextStyle(
                fontSize: 16,
              ),
            ),

            const SizedBox(height: 30),

            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}