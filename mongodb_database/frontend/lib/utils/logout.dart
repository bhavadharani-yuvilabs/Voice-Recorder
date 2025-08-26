import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../screens/login_screen.dart';

class Logout {
  static Future<void> handleLogout(BuildContext context) async {
    await FirebaseService.signOut();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) {
          return const LoginScreen();
        },
      ),
    );
  }
}
