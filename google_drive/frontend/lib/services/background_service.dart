// FIXED: Background service entry point
import 'dart:async';
import 'dart:ui';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_sound/public/flutter_sound_recorder.dart';

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  print('Background service started');

  DartPluginRegistrant.ensureInitialized(); // Ensure plugins are available
  final recorder = FlutterSoundRecorder(); // Initialize recorder in background
  await recorder.openRecorder();

  final notificationsPlugin = FlutterLocalNotificationsPlugin();

  // This initialization is correct and necessary
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await notificationsPlugin.initialize(initializationSettings);

  String? currentRecordingPath;
  Timer? notificationTimer;
  int durationSeconds = 0;

  String formatDuration(int totalSeconds) {
    final duration = Duration(seconds: totalSeconds);
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  service.on('startRecording').listen((event) {
    currentRecordingPath = event!['filePath'];
    print('Background recording started: $currentRecordingPath');
    durationSeconds = 0;

    notificationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      durationSeconds++;
      _showBackgroundNotification(
        notificationsPlugin,
        'Recording: ${formatDuration(durationSeconds)}', // Pass the updated content
      );
    });
  });

  service.on('stopRecording').listen((event) {
    print('Background recording stopped');
    notificationTimer?.cancel();
    notificationsPlugin.cancel(888); // Cancel the correct ID
    service.stopSelf();
  });
}

// FIXED: Show background notification by UPDATING it
Future<void> _showBackgroundNotification(FlutterLocalNotificationsPlugin plugin, String content) async {
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'voice_recorder_channel',
    'Voice Recorder',
    channelDescription: 'Background voice recording',
    importance: Importance.low,
    priority: Priority.low,
    ongoing: true,
    autoCancel: false,
    showWhen: false, // Hides the timestamp for a cleaner look
    actions: [
      AndroidNotificationAction(
        'stop_recording',
        'Stop Recording',
        cancelNotification: false,
      ),
    ],
  );

  const NotificationDetails details = NotificationDetails(android: androidDetails);

  await plugin.show(
    888, // <-- CRITICAL FIX: Use the SAME ID as the foreground service
    'Recording in Progress',
    content, // Use the dynamic content
    details,
  );
}

@pragma('vm:entry-point')
bool onIosBackground(ServiceInstance service) {
  print('iOS background mode');
  return true;
}
