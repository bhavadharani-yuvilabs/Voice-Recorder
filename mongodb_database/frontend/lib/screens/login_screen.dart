import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/response_model.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/firebase_service.dart';
import 'record_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String userId = '';
  String userEmail = '';
  String? displayName;
  String? photoURL;

  void handleLogin() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    // var start = DateTime.now();
    await FirebaseService.signInWithGoogle();

    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      Navigator.pop(context);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const RecorderScreen(),
        ),
      );

      userEmail = firebaseUser.email ?? '';
      displayName = firebaseUser.displayName;
      photoURL = firebaseUser.photoURL;
      print(await firebaseUser.getIdToken());
      print(firebaseUser.refreshToken);

      ResponseModel response = await ApiService.sendUserData(
        email: userEmail,
        displayName: firebaseUser.displayName,
        photoURL: firebaseUser.photoURL,
      );
      // AppUser user = AppUser.fromJson(response.data);
      print('------------------User API Response: ${response.success}, ${response.message}');

      if (response.success == true && response.data is Map) {
        final data = response.data as Map;
        setState(() {
          userId = data['userId'] ?? '';
          displayName = data['displayName'] ?? firebaseUser.displayName;
          photoURL = data['photoURL'] ?? firebaseUser.photoURL;
        });
        // setState(() {
        //   userId = user.userId ?? "";
        //   displayName = data['displayName'] ?? firebaseUser.displayName;
        //   photoURL = data['photoURL'] ?? firebaseUser.photoURL;
        // });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(child: getBody()),
    );
  }

  Widget getBody() {
    return Container(
      child: Center(
        child: Container(
          width: 500,
          height: 1000,
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: Colors.black,
            boxShadow: [
              BoxShadow(
                color: Colors.white.withOpacity(0.5),
                blurRadius: 20.0,
                spreadRadius: -20.0,
                offset: const Offset(25, 0),
              ),
              BoxShadow(
                color: Colors.white.withOpacity(0.5),
                blurRadius: 20.0,
                spreadRadius: -20.0,
                offset: const Offset(-25, 0),
              ),
            ],
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  'VOICE RECORDER',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 35,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.login,
                        size: 18,
                        color: Colors.black,
                      ),
                      SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          'Sign in with Google',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
