import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';

import 'firebase_options.dart';
import 'screens/splash/splash_screen.dart';

/// Global navigator key used by ZEGOCLOUD
/// to show incoming call invitation UI.
final GlobalKey<NavigatorState> navigatorKey =
    GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set navigator key for ZEGOCLOUD call invitations.
  ZegoUIKitPrebuiltCallInvitationService()
      .setNavigatorKey(navigatorKey);

  // Initialize Firebase.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const ConnectCallApp());
}

class ConnectCallApp extends StatelessWidget {
  const ConnectCallApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Required for ZEGOCLOUD incoming call UI.
      navigatorKey: navigatorKey,

      debugShowCheckedModeBanner: false,
      title: 'ConnectCall',

      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
      ),

      home: const SplashScreen(),
    );
  }
}