import 'package:flutter/material.dart';
import 'package:path/path.dart';

class DialogUtils {
  static void showLoadingDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Align(
        alignment: Alignment.bottomCenter, // bottom middle of the screen
        child: Padding(
          padding: const EdgeInsets.only(bottom: 40), // move it up a little
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                message,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.none, // remove underline
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
