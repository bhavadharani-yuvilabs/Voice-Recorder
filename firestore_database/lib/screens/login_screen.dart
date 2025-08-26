import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import 'record_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  void handleLogin() async {
    try {
      Map<String, String>? user = await FirebaseService.signInWithGoogle();
      if (user != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const RecorderScreen(),
          ),
        );
      } else {
        print('Sign-in canceled or failed');
      }
    } catch (e) {
      print('Login error: $e');
      // Optionally show an error message to the user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: getBody(),
    );
  }

  Widget getBody() {
    return Container(
      // color: Colors.white, // Use theme background color
      // color: Theme.of(context).colorScheme.onSurface,// Use theme background color
      child: Center(
        child: Container(
          width: 500,
          height: 1000,
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(40),
          decoration: const BoxDecoration(
            color: Colors.black, // Use theme surface color
            // borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.white, // Use theme onSurface with opacity
                blurRadius: 24,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  'VOICE JOURNALING',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 35,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    // color: Theme.of(context).colorScheme.onSurface, // Use theme onSurface color
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: handleLogin,
                  style: ElevatedButton.styleFrom(
                    // backgroundColor: Theme.of(context).colorScheme.primary, // Use theme primary color
                    backgroundColor: Colors.white, // Use theme primary color
                    foregroundColor: Colors.black, // Use theme onPrimary color
                    // foregroundColor: Theme.of(context).colorScheme.onPrimary, // Use theme onPrimary color
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
                        // color: Theme.of(context).colorScheme.onPrimary, // Use theme onPrimary color
                      ),
                      SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          'Sign in with Google',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            // color: Theme.of(context).colorScheme.onPrimary, // Use theme onPrimary color
                          ),
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
