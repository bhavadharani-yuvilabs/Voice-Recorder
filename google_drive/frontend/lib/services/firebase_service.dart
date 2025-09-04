import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class FirebaseService {
  static User? get currentUser => FirebaseAuth.instance.currentUser;

  static Future<Map<String, String>?> signInWithGoogle() async {
    try {
      // Initialize GoogleSignIn, optionally specify Web Client ID
      final GoogleSignIn googleSignIn = GoogleSignIn(
        clientId: '271109729602-qohvnp1b36er191gf63q93atnqc13amv.apps.googleusercontent.com',
        // clientId: '271109729602-qohvnp1b36er191gf63q93atnqc13amv.apps.googleusercontent.journal.yuvilabs.com',
      );

      // Attempt to sign in with Google
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        // User canceled the sign-in
        return null;
      }

      // Get Google authentication details
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create Firebase credential
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the credential
      final UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        // Return user data
        return {
          'uid': user.uid,
          'displayName': user.displayName ?? '',
          'email': user.email ?? '',
          'photoURL': user.photoURL ?? '',
        };
      }

      return null;
    } catch (e) {
      // Log and handle errors
      print('Google Sign-In error: $e');
      return null;
    }
  }

  static Future<void> signOut() async {
    try {
      await GoogleSignIn().signOut();
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      print('Sign-out error: $e');
    }
  }
}
