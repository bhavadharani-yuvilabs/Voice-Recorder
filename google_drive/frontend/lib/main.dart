import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:journal/screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(VoiceRecorderApp());
}

class VoiceRecorderApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Voice Recorder',
      theme: myBlackWhiteTheme,
      home: const LoginScreen(),
    );
  }
}

ThemeData myBlackWhiteTheme = ThemeData(
  fontFamily: 'SFProDisplay',
  scaffoldBackgroundColor: Colors.white,
// Define your primary color scheme - BLACK AND WHITE
  primarySwatch: Colors.grey,
  primaryColor: Colors.black,
  colorScheme: const ColorScheme.light(
    primary: Colors.black, // For the Save button and highlights (changed from green to black)
    secondary: Colors.grey, // For accents (changed from purple to grey)
    surface: Colors.white, // Background surfaces
    onSurface: Colors.black, // Text on surfaces
    onPrimary: Colors.white, // Text on primary color
  ),

  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.black,
    foregroundColor: Colors.white,
    titleTextStyle: TextStyle(
      fontFamily: 'SFProDisplay',
      fontWeight: FontWeight.w600,
      fontSize: 20,
      color: Colors.white,
    ),
  ),

  textTheme: const TextTheme(
    titleMedium: TextStyle(
      fontFamily: 'SFProDisplay',
      fontWeight: FontWeight.bold,
      fontSize: 20,
      color: Colors.white,
    ),
    bodyLarge: TextStyle(
      fontFamily: 'SFProDisplay',
      fontWeight: FontWeight.w400,
      fontSize: 16,
      color: Colors.black,
    ),
    bodyMedium: TextStyle(
      fontFamily: 'SFProDisplay',
      fontWeight: FontWeight.w400,
      fontSize: 14,
      color: Colors.black,
    ),
  ),

// Updated InputDecorationTheme to use theme colors

  inputDecorationTheme: const InputDecorationTheme(
    border: OutlineInputBorder(
      borderSide: BorderSide(color: Colors.black),
    ),
    enabledBorder: OutlineInputBorder(
      borderSide: BorderSide(color: Colors.black),
    ),
    focusedBorder: OutlineInputBorder(
      borderSide: BorderSide(color: Colors.black, width: 2.0), // Changed from green to black
    ),
    labelStyle: TextStyle(color: Colors.black),
  ),

// Updated TextButtonTheme for Cancel button

  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: Colors.black,
      textStyle: const TextStyle(
        fontFamily: 'SFProDisplay',
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
    ),
  ),

// ElevatedButtonTheme for Save button

  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.black, // Changed from green to black

      foregroundColor: Colors.white, // Text color

      textStyle: const TextStyle(
        fontFamily: 'SFProDisplay',
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),

      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    ),
  ),

// FloatingActionButtonTheme for the main record button

  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: Colors.black, // Changed from green to black
    foregroundColor: Colors.white, // Icon color
  ),

  // ProgressIndicator that is visible on a black background
  progressIndicatorTheme: const ProgressIndicatorThemeData(
    color: Colors.white,
  ),
);
