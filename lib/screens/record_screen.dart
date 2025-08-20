import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'dart:io';
import 'dart:async';
import 'package:path/path.dart' as p;
import 'dart:convert';

// FIXED IMPORTS FOR BACKGROUND RECORDING
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:audio_session/audio_session.dart';

// NEW: Firebase imports
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/recording_model.dart'; // Your existing recording model
import '../services/firebase_service.dart';
import '../services/firestore_service.dart';
import 'login_screen.dart';

class RecordingItem {
  final String filePath;
  final String fileName;
  final DateTime createdAt;
  final int fileSizeBytes;

  RecordingItem({
    required this.filePath,
    required this.fileName,
    required this.createdAt,
    required this.fileSizeBytes,
  });
}

class RecorderScreen extends StatefulWidget {
  const RecorderScreen({super.key});

  @override
  _RecorderScreenState createState() => _RecorderScreenState();
}

class _RecorderScreenState extends State<RecorderScreen> with WidgetsBindingObserver {
  void handleLogout() async {
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

  bool isRecording = false;
  bool isPlaying = false;
  bool isPaused = false;
  bool isPermissionGranted = false;
  bool isBackgroundServiceRunning = false;

  FlutterSoundRecorder? _recorder;
  FlutterSoundPlayer? _player;

  StreamSubscription<RecordingDisposition>? _recordingSubscription;
  StreamSubscription<PlaybackDisposition>? _playbackSubscription;

  String? _currentRecordingPath;
  String? _currentPlayingPath;

  List<RecordingItem> _allRecordings = [];

  Duration _recordingDuration = Duration.zero;
  Duration _playbackPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;

  // FIXED BACKGROUND VARIABLES
  late FlutterLocalNotificationsPlugin _notificationsPlugin;
  final FlutterBackgroundService _backgroundService = FlutterBackgroundService();

  // NEW: Firebase variables (simplified)
  final FirestoreService _firestoreService = FirestoreService();
  // Removed upload UI variables - auto-upload is silent

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _onInit();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recordingSubscription?.cancel();
    _playbackSubscription?.cancel();
    _recorder?.closeRecorder();
    _player?.closePlayer();
    _stopBackgroundService();
    super.dispose();
  }

  // FIXED: Initialize everything in correct order
  Future<void> _onInit() async {
    //onInit - rename as
    await _initializeNotifications();
    await _initializeBackgroundService();
    await _configureAudioSession();
    await _initializeAudio();
  }

  // FIXED: Initialize notifications first
  Future<void> _initializeNotifications() async {
    _notificationsPlugin = FlutterLocalNotificationsPlugin();

    // -- ADD THIS BLOCK TO CREATE THE CHANNEL --
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'voice_recorder_channel', // id
      'Voice Recorder Channel', // title
      description: 'This channel is used for background voice recording notifications.', // description
      importance: Importance.defaultImportance,
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
    // -----------------------------------------

// Android settings
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    // iOS/macOS settings
    const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    // Combine settings
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    // Initialize the plugin
    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.actionId == 'stop_recording') {
          _stopRecordingFromNotification();
        }
      },
    );

    // Request notification permissions
    if (Platform.isAndroid) {
      await Permission.notification.request();
      await Permission.systemAlertWindow.request();
      await Permission.ignoreBatteryOptimizations.request();
    }
  }

  // FIXED: Proper background service initialization
  Future<void> _initializeBackgroundService() async {
    await _backgroundService.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'voice_recorder_channel',
        initialNotificationTitle: 'Voice Recorder',
        initialNotificationContent: 'Ready to record',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  // FIXED: Configure audio session properly
  Future<void> _configureAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration(
        //For iOS (the avAudio... properties):
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.defaultToSpeaker,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
        avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
        avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,

        //For Android (the android... properties):
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.speech,
          flags: AndroidAudioFlags.none,
          usage: AndroidAudioUsage.voiceCommunication,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: false,
      ));
      print('Audio session configured successfully');
    } catch (e) {
      print('Error configuring audio session: $e');
    }
  }

  // Initialize audio recorder and player
  Future<void> _initializeAudio() async {
    _recorder = FlutterSoundRecorder();
    _player = FlutterSoundPlayer();

    await _requestPermissions();

    if (isPermissionGranted) {
      try {
        await _recorder!.openRecorder();
        await _player!.openPlayer();
        await _loadExistingRecordings();
        _showMessage('Audio recorder ready!');
      } catch (e) {
        print('Error initializing audio: $e');
        _showMessage('Error initializing audio: $e');
      }
    }
  }

  //
  // FIXED: Request all necessary permissions
  Future<void> _requestPermissions() async {
    Map<Permission, PermissionStatus> permissions = await [
      Permission.microphone,
      Permission.notification,
      if (Platform.isAndroid) ...[
        Permission.systemAlertWindow,
        Permission.ignoreBatteryOptimizations,
      ],
    ].request();

    bool allGranted =
        permissions.values.every((status) => status == PermissionStatus.granted || status == PermissionStatus.limited);

    setState(() {
      isPermissionGranted = permissions[Permission.microphone] == PermissionStatus.granted;
    });

    if (!isPermissionGranted) {
      _showMessage('Microphone permission is required!');
    } else if (!allGranted) {
      _showMessage('Some permissions missing. Background recording may not work properly.');
    } else {
      _showMessage('All permissions granted! Background recording enabled.');
    }
  }

  // FIXED: Start background service for recording
  Future<void> _startBackgroundRecording(String recordingPath) async {
    try {
      await _backgroundService.startService();
      // Send recording data to background service
      _backgroundService.invoke('startRecording', {
        'filePath': recordingPath,
      });

      setState(() {
        isBackgroundServiceRunning = true;
      });

      _showMessage('Background recording started');
    } catch (e) {
      print('Error starting background service: $e');
      _showMessage('Error starting background recording: $e');
    }
  }

  // FIXED: Stop background service
  Future<void> _stopBackgroundService() async {
    try {
      _backgroundService.invoke('stopRecording');
      // Note: FlutterBackgroundService doesn't have stopService() method
      // The service will stop itself when it receives 'stopRecording' event

      setState(() {
        isBackgroundServiceRunning = false;
      });
    } catch (e) {
      print('Error stopping background service: $e');
    }
  }

  // Load existing recordings
  Future<void> _loadExistingRecordings() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final files =
          directory.listSync().where((item) => item is File && item.path.endsWith('.aac')).cast<File>().toList();

      List<RecordingItem> recordings = [];

      for (File file in files) {
        final stat = await file.stat();
        final fileName = path.basename(file.path);

        recordings.add(RecordingItem(
          filePath: file.path,
          fileName: fileName,
          createdAt: stat.modified,
          fileSizeBytes: stat.size,
        ));
      }

      recordings.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      setState(() {
        _allRecordings = recordings;
      });
    } catch (e) {
      print('Error loading recordings: $e');
    }
  }

  Future<String> _getRecordingPath() async {
    final directory = await getApplicationDocumentsDirectory();
    final fileName = 'recording_${DateTime.now().millisecondsSinceEpoch}.aac';
    return path.join(directory.path, fileName);
  }

  // FIXED: Toggle recording with proper background handling
  Future<void> _toggleRecording() async {
    if (!isPermissionGranted) {
      await _requestPermissions();
      return;
    }

    try {
      if (isRecording) {
        // Stop recording
        await _recorder!.stopRecorder();
        _recordingSubscription?.cancel();
        await _stopBackgroundService();

        _showMessage('Recording saved!');

        // Capture final duration before resetting
        final finalDuration = _recordingDuration.inMilliseconds;

        // INSERT: Show naming bottom sheet
        _showNamingBottomSheet(context, (String recordingName) async {
          // AUTO-UPLOAD: Upload automatically after recording
          if (_currentRecordingPath != null) {
            // INSERT: Rename local file
            try {
              final file = File(_currentRecordingPath!);
              final directory = await getApplicationDocumentsDirectory();
              final newFileName = recordingName.endsWith('.aac') ? recordingName : '$recordingName.aac';
              final newPath = path.join(directory.path, newFileName);
              await file.rename(newPath);
              _currentRecordingPath = newPath; // Update current path
            } catch (e) {
              _showMessage('Failed to rename local recording: $e');
              return;
            }

            _autoUploadRecording(finalDuration, recordingName);
          }

          setState(() {
            isRecording = false;
            _recordingDuration = Duration.zero;
          });

          await _loadExistingRecordings();
        });
      } else {
        // Start recording
        _currentRecordingPath = await _getRecordingPath();

        _recordingSubscription = _recorder!.onProgress!.listen((event) {
          if (mounted) {
            setState(() {
              _recordingDuration = event.duration;
            });
          }
        });

        await _recorder!.startRecorder(
          toFile: _currentRecordingPath,
          codec: Codec.aacADTS,
        );

        await _recorder!.setSubscriptionDuration(const Duration(milliseconds: 500));

        // Start background service immediately
        await _startBackgroundRecording(_currentRecordingPath!);

        setState(() {
          isRecording = true;
          isPlaying = false;
          _recordingDuration = Duration.zero;
        });

        _showMessage('Recording started! You can now minimize the app.');
      }
    } catch (e) {
      print('Recording error: $e');
      _showMessage('Recording error: $e');
    }
  }

  void _showNamingBottomSheet(BuildContext context, Function(String) onNameConfirmed) {
    final TextEditingController nameController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Name Your Recording', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Recording Name', border: OutlineInputBorder()),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                  ElevatedButton(
                    onPressed: () {
                      final name = nameController.text.trim();
                      onNameConfirmed(
                          name.isNotEmpty ? name : 'recording_${DateTime.now().millisecondsSinceEpoch}.aac');
                      Navigator.pop(context);
                    },
                    child: const Text('Save'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  // AUTO-UPLOAD: Silent background upload with snackbar feedback
  Future<void> _autoUploadRecording(int originalDuration, [String? fileName]) async {
    if (_currentRecordingPath == null) return;

    // Don't show upload status in UI, just upload silently
    try {
      File audioFile = File(_currentRecordingPath!);

      // Check file size before upload
      int fileSize = await audioFile.length();
      if (fileSize > 1024 * 1024) {
        // 1MB limit
        _showMessage('⚠️ Recording too large for cloud storage (${_formatFileSize(fileSize)})');
        return;
      }

      // INSERT: Ensure .aac extension
      fileName = fileName != null && !fileName.endsWith('.aac') ? '$fileName.aac' : fileName;
      fileName ??= 'recording_${DateTime.now().millisecondsSinceEpoch}.aac';

      // Upload to Firestore silently with duration
      await _firestoreService.uploadRecording(
        audioFile,
        fileName,
        originalDuration,
      );

      // await _firestoreService.uploadRecording(audioFile, fileName, _totalDuration);
      // String recordingId = await _firestoreService.uploadRecording(audioFile, fileName, _totalDuration.inMilliseconds);

      // Show success snackbar
      _showMessage('☁️ Recording automatically saved to cloud!');
    } catch (e) {
      // Show error snackbar
      _showMessage('❌ Failed to save to cloud: ${e.toString()}');
    }
  }

  // // NEW: Show uploaded recordings
  // void _showUploadedRecordings() {
  //   Navigator.push(
  //     context,
  //     MaterialPageRoute(builder: (context) => UploadedRecordingsScreen()),
  //   );
  // }

  // Stop recording from notification
  void _stopRecordingFromNotification() async {
    if (isRecording) {
      await _toggleRecording();
    }
  }

  // Play specific recording
  Future<void> _playSpecificRecording(String filePath) async {
    try {
      if (isPlaying && _currentPlayingPath == filePath) {
        await _player!.pausePlayer();
        setState(() {
          isPlaying = false;
          isPaused = true;
        });
      } else if (isPaused && _currentPlayingPath == filePath) {
        await _player!.resumePlayer();
        setState(() {
          isPlaying = true;
          isPaused = false;
        });
      } else {
        if (isPlaying) {
          await _player!.stopPlayer();
          _playbackSubscription?.cancel();
        }

        _playbackSubscription = _player!.onProgress!.listen((event) {
          if (mounted) {
            setState(() {
              _playbackPosition = event.position;
              _totalDuration = event.duration;
            });
          }
        });

        await _player!.startPlayer(
          fromURI: filePath,
          codec: Codec.aacADTS,
          whenFinished: () {
            _playbackSubscription?.cancel();
            if (mounted) {
              setState(() {
                isPlaying = false;
                isPaused = false;
                _playbackPosition = Duration.zero;
                _totalDuration = Duration.zero;
                _currentPlayingPath = null;
              });
            }
          },
        );

        await _player!.setSubscriptionDuration(const Duration(milliseconds: 100));

        setState(() {
          isPlaying = true;
          isPaused = false;
          _currentPlayingPath = filePath;
        });
      }
    } catch (e) {
      _showMessage('Error playing recording: $e');
    }
  }

  // Delete specific recording
  // updated in cloud
  Future<void> _deleteSpecificRecording(RecordingItem recording) async {
    try {
      final fileName = recording.fileName; // Get the filename before deleting

      // 1. Find the corresponding document in Firestore by its filename
      final recordingId = await _firestoreService.getRecordingIdByFileName(fileName);

      // 2. Delete the local file
      final file = File(recording.filePath);
      if (await file.exists()) {
        await file.delete();
      }

      // 3. If a cloud document was found, delete it too
      if (recordingId != null) {
        await _firestoreService.deleteRecording(recordingId);
        _showMessage('Recording deleted from device & cloud!');
      } else {
        _showMessage('Recording deleted from device.');
      }

      // 4. Stop the player if the deleted file was playing
      if (_currentPlayingPath == recording.filePath) {
        await _player!.stopPlayer();
        setState(() {
          isPlaying = false;
          isPaused = false;
          _currentPlayingPath = null;
        });
      }

      // 5. Refresh the list from local storage
      await _loadExistingRecordings();
    } catch (e) {
      _showMessage('Error deleting recording: $e');
    }
  }

  //rename the recordings
  // updated in cloud
  Future<void> _renameLocalRecording(BuildContext context, RecordingItem recording, int index) async {
    // The controller is pre-filled with the name WITHOUT the extension
    final TextEditingController nameController =
        TextEditingController(text: p.basenameWithoutExtension(recording.fileName));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Rename Recording', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Recording Name', border: OutlineInputBorder()),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                  ElevatedButton(
                    onPressed: () async {
                      // 1. Get the old and new names
                      final oldFileName = recording.fileName;
                      String newName = nameController.text.trim();

                      // Ensure the new name has the .aac extension
                      if (newName.isNotEmpty && !newName.endsWith('.aac')) {
                        newName = '$newName.aac';
                      }

                      if (newName.isNotEmpty && newName != oldFileName) {
                        // --- Start of Update Logic ---
                        try {
                          // 2. Find the document in Firestore using the OLD name
                          final recordingId = await _firestoreService.getRecordingIdByFileName(oldFileName);

                          // 3. Rename the local file first
                          final file = File(recording.filePath);
                          final directory = await getApplicationDocumentsDirectory();
                          final newPath = path.join(directory.path, newName);
                          await file.rename(newPath);

                          // 4. If the cloud document was found, update it
                          if (recordingId != null) {
                            await _firestoreService.updateRecordingFileName(recordingId, newName);
                            _showMessage('Renamed in local storage & cloud');
                          } else {
                            _showMessage('Renamed locally (not found in cloud)');
                          }

                          // 5. Update the local list in the UI
                          setState(() {
                            _allRecordings[index] = RecordingItem(
                              filePath: newPath,
                              fileName: newName,
                              createdAt: recording.createdAt,
                              fileSizeBytes: recording.fileSizeBytes,
                            );
                          });
                        } catch (e) {
                          _showMessage('An error occurred: $e');
                        }
                        // --- End of Update Logic ---
                      }
                      Navigator.pop(context); // Close the bottom sheet
                    },
                    child: const Text('Save'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  // Seek to position
  Future<void> _seekToPosition(double value) async {
    if (_player != null && _currentPlayingPath != null && _totalDuration.inMilliseconds > 0) {
      try {
        final newPosition = Duration(milliseconds: (_totalDuration.inMilliseconds * value).round());
        await _player!.seekToPlayer(newPosition);
        setState(() {
          _playbackPosition = newPosition;
        });
      } catch (e) {
        print('Seek error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: getAppBar(),
      body: getBody(context),
    );
  }

  Widget getBody(BuildContext context) {
    return Column(
      children: [
        // Status indicator
        if (isBackgroundServiceRunning)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: Colors.green[100],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Background Service Active',
                  style: TextStyle(
                    color: Colors.green[800],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

        // NEW: Upload status indicator (removed - no longer needed)
        // Auto-upload happens silently in background

        // Controls
        Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Duration display
              if (isRecording)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.fiber_manual_record, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      _formatDuration(_recordingDuration),
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ],
                )
              else if (isPlaying || isPaused)
                const Column(),

              const SizedBox(height: 20),

              // Record button
              if (!isPermissionGranted)
                Column(
                  children: [
                    const Icon(Icons.warning, size: 50, color: Colors.orange),
                    const SizedBox(height: 10),
                    const Text('Permissions Required'),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: _requestPermissions,
                      child: const Text('Grant Permissions'),
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    ElevatedButton(
                      onPressed: _toggleRecording,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(15),
                        shape: const CircleBorder(),
                        elevation: 5,
                      ),
                      child: Icon(
                        isRecording ? Icons.stop : Icons.mic,
                        size: 40,
                      ),
                    ),

                    // Upload controls removed - auto-upload is now automatic
                  ],
                ),
            ],
          ),
        ),

        // Recordings list
        // Recordings List Section
        Expanded(
          child: getRecordingsList(),
        ),

        // getMyRecordingsList(),
      ],
    );
  }

  Widget getRecordingsList() {
    if (_allRecordings.isEmpty) {
      return Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.8),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.mic_off, size: 60, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              'No recordings yet',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 10),
            Text(
              'Tap the Record button to create your first recording!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          getMyRecordingsTab(),
          getMyRecordingsList(),
        ],
      ),
    );
  }

  Widget getMyRecordingsTab() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
      ),
      child: Row(
        children: [
          const Icon(Icons.queue_music, color: Colors.white),
          const SizedBox(width: 10),
          Text(
            'My Recordings (${_allRecordings.length})',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 93),
          if (_allRecordings.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              color: Colors.white,
              onPressed: _deleteAllRecordings,
              tooltip: 'Delete All Recordings',
            ),
        ],
      ),
    );
  }

  Widget getMyRecordingsList() {
    if (_allRecordings.isEmpty) {
      // This part for the empty list remains the same
      return Expanded(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.mic_off, size: 60, color: Colors.grey),
              const SizedBox(height: 10),
              Text('No recordings yet', style: TextStyle(color: Colors.grey[600])),
              const SizedBox(height: 5),
              Text('Tap record to start', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
            ],
          ),
        ),
      );
    }

    return Expanded(
      child: ListView.builder(
        itemCount: _allRecordings.length,
        itemBuilder: (context, index) {
          final recording = _allRecordings[index];
          final isCurrentlyPlayingOrPaused = _currentPlayingPath == recording.filePath;

          return Dismissible(
            key: Key(recording.filePath),
            direction: DismissDirection.endToStart,
            background: Container(
              color: Colors.red,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: const Icon(Icons.delete_outline_outlined, color: Colors.white),
            ),
            onDismissed: (direction) {
              _deleteSpecificRecording(recording);
            },
            child: Container(
              decoration: BoxDecoration(
                // 1. Move the color logic here
                color: isCurrentlyPlayingOrPaused ? Colors.grey[100] : Colors.transparent,

                // 2. Add your desired border here
                border: Border(
                  // right: BorderSide(color: Colors.grey.shade300, width: 1.0),
                  bottom: BorderSide(color: Colors.grey.shade50, width: 1.0),
                ),
              ),
              child: ListTile(
                tileColor: isCurrentlyPlayingOrPaused ? Colors.grey[400] : null,

                title: Text(
                  p.basenameWithoutExtension(recording.fileName),
                  // recording.fileName,
                  // 'Recording ${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),

                // Individual upload buttons removed - auto-upload is automatic

                // Conditionally show the duration slider or the file details.
                subtitle: isCurrentlyPlayingOrPaused
                    ? _buildDurationSlider() // Show slider if this item is active
                    : Column(
                        // Otherwise, show the default details
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_formatDateTime(recording.createdAt)),
                          // Text(_formatFileSize(recording.fileSizeBytes)),
                        ],
                      ),

                trailing: IconButton(
                  icon: Icon(
                    isPlaying && isCurrentlyPlayingOrPaused
                        ? Icons.pause_circle_outline_outlined
                        : Icons.play_arrow_rounded,
                  ),
                  onPressed: () => _playSpecificRecording(recording.filePath),
                ),

                onTap: () => _playSpecificRecording(recording.filePath),

                // INSERT: Long press to rename
                onLongPress: () => _renameLocalRecording(context, recording, index),
              ),
            ),
          );
        },
      ),
    );
  }

  AppBar getAppBar() {
    return AppBar(
      title: Row(
        children: [
          const Text('Voice Recorder'),
          if (isBackgroundServiceRunning) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'BACKGROUND',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),

      actions: [
        IconButton(
          icon: Icon(Icons.logout),
          onPressed: handleLogout,
        ),
      ],

      // actions: [
      //   // NEW: Cloud recordings button
      //   IconButton(
      //     icon: Icon(Icons.cloud),
      //     onPressed: _showUploadedRecordings,
      //     tooltip: 'View Cloud Recordings',
      //   ),
      //   if (isRecording)
      //     Icon(
      //       Icons.fiber_manual_record,
      //       color: Colors.red,
      //     ),
      // ],
    );
  }

// New helper method to build the duration display and slider
  Widget _buildDurationSlider() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_formatDuration(_playbackPosition)),
            Text(_formatDuration(_totalDuration)),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: Colors.black,
            inactiveTrackColor: Colors.grey[300],
            thumbColor: Colors.black,
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 0),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
          ),
          child: Slider(
            value: _totalDuration.inMilliseconds > 0
                ? (_playbackPosition.inMilliseconds / _totalDuration.inMilliseconds).clamp(0.0, 1.0)
                : 0.0,
            onChanged: (value) {
              if (_totalDuration.inMilliseconds > 0) {
                final newPosition = Duration(milliseconds: (_totalDuration.inMilliseconds * value).round());
                setState(() {
                  _playbackPosition = newPosition;
                });
              }
            },
            onChangeEnd: _seekToPosition,
          ),
        ),
      ],
    );
  }

  // Delete all recordings
  Future<void> _deleteAllRecordings() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete All Recordings?'),
          content: Text(
              'This action cannot be undone. Are you sure you want to delete all ${_allRecordings.length} recordings?'),
          actions: [
            TextButton(
              child: const Text('Cancel'), //, style: TextStyle(color: Colors.black)),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Delete All', style: TextStyle(color: Colors.red)),
              onPressed: () async {
                Navigator.of(context).pop();
                await _performDeleteAll();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _performDeleteAll() async {
    try {
      for (final recording in _allRecordings) {
        final file = File(recording.filePath);
        if (await file.exists()) {
          await file.delete();
        }
      }

      await _stopAll();
      //deletes all from database tooo!!
      await _firestoreService.deleteAllRecordings();
      await _loadExistingRecordings();
      _showMessage('All recordings deleted!');
    } catch (e) {
      _showMessage('Error deleting recordings: $e');
    }
  }

  Future<void> _stopAll() async {
    try {
      if (isRecording) {
        await _recorder!.stopRecorder();
        _recordingSubscription?.cancel();
      }
      if (isPlaying) {
        await _player!.stopPlayer();
        _playbackSubscription?.cancel();
      }

      setState(() {
        isRecording = false;
        isPlaying = false;
        isPaused = false;
        _recordingDuration = Duration.zero;
        _playbackPosition = Duration.zero;
        _totalDuration = Duration.zero;
        _currentPlayingPath = null;
      });
      _showMessage('Everything stopped!');
    } catch (e) {
      _showMessage('Error stopping: $e');
    }
  }

  // Helper methods
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  String _formatDateTime(DateTime dateTime) {
    List<String> months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    String month = months[dateTime.month - 1];
    String period = dateTime.hour < 12 ? 'am' : 'pm';
    int hour = dateTime.hour == 0 ? 12 : (dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour);
    return '${dateTime.day} $month ${dateTime.year}  $hour:${dateTime.minute.toString().padLeft(2, '0')} $period';
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }
}

// FIXED: Background service entry point
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  print('Background service started');

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
