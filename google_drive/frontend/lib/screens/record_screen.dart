import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/recording_model.dart';
import '../services/api_service.dart';
import '../services/audio_service.dart';
import '../services/background_service.dart';
import '../services/firebase_service.dart';
import '../utils/dialog_utils.dart';
import '../utils/formatters.dart';
import '../utils/logout.dart';

class RecorderScreen extends StatefulWidget {
  const RecorderScreen({super.key});

  @override
  RecorderScreenState createState() => RecorderScreenState();
}

class RecorderScreenState extends State<RecorderScreen> with WidgetsBindingObserver {
  String? _currentPlayingId;

  bool isLoading = false;

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

  List<Recording> _allRecordings = [];

  Duration _recordingDuration = Duration.zero;
  Duration _playbackPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;

  FlutterLocalNotificationsPlugin? _notificationsPlugin;
  final FlutterBackgroundService _backgroundService = FlutterBackgroundService();

  String? get _currentUserEmail => FirebaseService.currentUser?.email;

  @override
  // void initState() {
  //   super.initState();
  //   WidgetsBinding.instance.addObserver(this);
  //   _onInit();
  // }
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Show loading dialog when the screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DialogUtils.showLoadingDialog(context, 'Initializing Recorder...');
      _onInit().then((_) {
        if (mounted) {
          Navigator.pop(context); // Close the loading dialog
        }
      }).catchError((e) {
        if (mounted) {
          Navigator.pop(context); // Close the loading dialog on error
          _showMessage('Initialization error: $e');
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: getAppBar(),
      // body: getBody(context),
      body: isLoading ? const Center(child: CircularProgressIndicator()) : getBody(context),
    );
  }

  Widget getBody(BuildContext context) {
    return Column(
      children: [
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
        Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              if (isRecording)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.fiber_manual_record, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      Formatters.formatDuration(_recordingDuration),
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              if (isPlaying || isPaused) const Column(),
              const SizedBox(height: 20),
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
                ),
              if (isPermissionGranted)
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
                  ],
                ),
            ],
          ),
        ),
        Expanded(
          child: getRecordingsList(),
        ),
      ],
    );
  }

  AppBar getAppBar() {
    return AppBar(
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          const Text('Voice Recorder'),
          if (isBackgroundServiceRunning)
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
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.logout),
          onPressed: () => Logout.handleLogout(context),
        ),
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
          Expanded(
            child: getMyRecordingsList(),
          ),
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
          const Spacer(),
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
    // Add debug print
    // print("**********🔍 _allRecordings.length: ${_allRecordings.length}");

    if (_allRecordings.isEmpty) {
      return Center(
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
      );
    }

    return ListView.builder(
      itemCount: _allRecordings.length,
      itemBuilder: (context, index) {
        final recording = _allRecordings[index];
        final recordingId = recording.recordingId;
        // print('==================recordingId initial: $recordingId');
        final fileName = recording.fileName;
        final createdAt = recording.createdAt;
        final duration = recording.duration;

        // Add debug prints
        // print("**********🔍 Recording $index: fileName=$fileName, createdAt=$createdAt, duration=$duration");

        if (fileName == null) {
          // print("**********🔍 Recording $index has null fileName, skipping");
          return const SizedBox.shrink();
        }

        final isCurrentlyPlayingOrPaused = _currentPlayingId != null && _currentPlayingId == recordingId;
        final isThisPlaying = _currentPlayingId == recordingId;

        return Dismissible(
          key: Key("${recording.recordingId}_${recording.createdAt}"),
          direction: DismissDirection.endToStart,
          background: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: const Icon(Icons.delete_outline_outlined, color: Colors.white),
          ),
          confirmDismiss: (direction) async {
            return await showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: const Text('Delete Recording?'),
                  content: const Text(
                    'This action cannot be undone. Are you sure you want to delete this recording from the device?',
                  ),
                  actions: [
                    TextButton(
                      child: const Text('Cancel'),
                      onPressed: () => Navigator.of(context).pop(false), // Return false to cancel
                    ),
                    TextButton(
                      child: const Text('Delete', style: TextStyle(color: Colors.red)),
                      onPressed: () {
                        Navigator.of(context).pop(true); // Return true to confirm
                      },
                    ),
                  ],
                );
              },
            );
          },
          onDismissed: (direction) {
            setState(() {
              _allRecordings.removeWhere((r) => r.recordingId == recording.recordingId);
            });
            _deleteSpecificRecording(recording);
          },
          child: getRecordingTile(isCurrentlyPlayingOrPaused, fileName, recordingId, isThisPlaying, createdAt, duration,
              recording, context, index),
        );
      },
    );
  }

  Widget getRecordingTile(bool isCurrentlyPlayingOrPaused, String fileName, String? recordingId, bool isThisPlaying,
      String? createdAt, int? duration, Recording recording, BuildContext context, int index) {
    // print('==================recordingId in func1: $recordingId');
    return Container(
      decoration: BoxDecoration(
        color: isCurrentlyPlayingOrPaused ? Colors.grey[100] : Colors.transparent,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade50, width: 1.0),
        ),
      ),
      child: ListTile(
        tileColor: isCurrentlyPlayingOrPaused ? Colors.grey[400] : null,
        minVerticalPadding: 4.0,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 2.0),
        title: Text(
          path.basenameWithoutExtension(fileName),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: isThisPlaying && isPlaying ? _buildDurationSlider() : unknownDateDuration(createdAt!, duration),
        trailing: ClipRect(
          child: SizedBox(
            width: 48,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(
                    isPlaying && isCurrentlyPlayingOrPaused
                        ? Icons.pause_circle_outline_outlined
                        : Icons.play_arrow_rounded,
                    size: 22,
                    color: Colors.grey[800],
                  ),
                  onPressed: () {
                    _playSpecificRecording(recording);
                  },
                ),
              ],
            ),
          ),
        ),
        onLongPress: () {
          _renameRecording(recordingId!, context, recording, index);
        },
      ),
    );
  }

  Widget unknownDateDuration(String? createdAt, int? duration) {
    DateTime utcDate = DateTime.parse(createdAt!); // stored in UTC
    DateTime localDate = utcDate.toLocal(); // convert to device local time
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          createdAt = Formatters.formatDateTime(localDate),
          // createdAt != null ? Formatters.formatDateTime(localDate) : 'Unknown date',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        Text(
          duration != null ? Formatters.formatDuration(Duration(milliseconds: duration)) : 'Unknown duration',
          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  // Future<void> _playSpecificRecording(Recording recording) async {
  //   try {
  //     if (recording.recordingId == null) {
  //       throw Exception('Recording recordingId is null');
  //     }
  //
  //     String? playPath;
  //
  //     // Check if we already have a local file
  //     final tempDir = await getTemporaryDirectory();
  //     final localFile = File('${tempDir.path}/${recording.recordingId}');
  //
  //     if (await localFile.exists()) {
  //       playPath = localFile.path;
  //     } else {
  //       // Check if current recording has audio data
  //       if (recording.audioData != null && recording.audioData!.isNotEmpty) {
  //         playPath = await _createTempFileFromBase64MongoDB(recording);
  //       } else {
  //         // Fetch the recording with audio data from server using your API
  //         final recordingWithAudio = await ApiService.getRecordingByEmailAndRecordingId(recording.recordingId!);
  //         if (recordingWithAudio != null && recordingWithAudio.audioData != null) {
  //           playPath = await _createTempFileFromBase64MongoDB(recordingWithAudio);
  //         } else {
  //           throw Exception('Failed to fetch audio data from server');
  //         }
  //       }
  //     }
  //
  //     if (playPath == null) {
  //       throw Exception('Unable to get audio file path');
  //     }
  //
  //     // Handle play/pause logic using recordingId as identifier
  //     if (isPlaying && _currentPlayingPath == playPath) {
  //       await _player!.pausePlayer();
  //       setState(() {
  //         isPlaying = false;
  //         isPaused = true;
  //       });
  //       return;
  //     }
  //
  //     if (isPaused && _currentPlayingPath == playPath) {
  //       await _player!.resumePlayer();
  //       setState(() {
  //         isPlaying = true;
  //         isPaused = false;
  //       });
  //       return;
  //     }
  //
  //     // Stop current playback if different recording
  //     if (isPlaying || isPaused) {
  //       await _player!.stopPlayer();
  //       _playbackSubscription?.cancel();
  //     }
  //
  //     // Start new playback
  //     _playbackSubscription = _player!.onProgress!.listen((event) {
  //       if (mounted) {
  //         setState(() {
  //           _playbackPosition = event.position;
  //           _totalDuration = event.duration;
  //         });
  //       }
  //     });
  //
  //     await _player!.startPlayer(
  //       fromURI: playPath,
  //       codec: Codec.aacADTS,
  //       whenFinished: () {
  //         _playbackSubscription?.cancel();
  //         if (mounted) {
  //           setState(() {
  //             isPlaying = false;
  //             isPaused = false;
  //             _playbackPosition = Duration.zero;
  //             _totalDuration = Duration.zero;
  //             _currentPlayingPath = null;
  //             _currentPlayingId = null;
  //           });
  //         }
  //       },
  //     );
  //
  //     await _player!.setSubscriptionDuration(const Duration(milliseconds: 100));
  //
  //     setState(() {
  //       isPlaying = true;
  //       isPaused = false;
  //       _currentPlayingPath = playPath;
  //       _currentPlayingId = recording.recordingId;
  //     });
  //   } catch (e) {
  //     _showMessage('Error playing recording: $e');
  //   }
  // }

  Future<void> _playSpecificRecording(Recording recording) async {
    try {
      if (recording.recordingId == null) {
        throw Exception('Recording recordingId is null');
      }

      String? playPath;

      // Check if we already have a local cached file
      final tempDir = await getTemporaryDirectory();
      final localFile = File('${tempDir.path}/${recording.recordingId}_processed.aac');

      if (await localFile.exists()) {
        playPath = localFile.path;
      } else {
        // ✅ Prefer processed audio first
        String? base64Audio = recording.processedAudio ?? recording.audioData;
        // print('******************processedAudio:  $base64Audio');

        if (base64Audio != null && base64Audio.isNotEmpty) {
          playPath = await _createTempFileFromBase64MongoDB(base64Audio, localFile.path);
        } else {
          // Fetch from server (make sure API returns processed audio too)
          final fetchedRecording = await ApiService.getRecordingByEmailAndRecordingId(recording.recordingId!);

          if (fetchedRecording != null && (fetchedRecording.processedAudio?.isNotEmpty ?? false)) {
            playPath = await _createTempFileFromBase64MongoDB(fetchedRecording.processedAudio!, localFile.path);
          } else if (fetchedRecording != null && (fetchedRecording.audioData?.isNotEmpty ?? false)) {
            // fallback to raw audio only if processed missing
            playPath = await _createTempFileFromBase64MongoDB(fetchedRecording.audioData!, localFile.path);
          } else {
            throw Exception('-------------Failed to fetch processed audio from server');
          }
        }
      }

      // if (playPath == null) {
      //   throw Exception('Unable to get processed audio file path');
      // }

      // 🎵 Play logic stays same
      if (isPlaying && _currentPlayingPath == playPath) {
        await _player!.pausePlayer();
        setState(() {
          isPlaying = false;
          isPaused = true;
        });
        return;
      }

      if (isPaused && _currentPlayingPath == playPath) {
        await _player!.resumePlayer();
        setState(() {
          isPlaying = true;
          isPaused = false;
        });
        return;
      }

      if (isPlaying || isPaused) {
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
        fromURI: playPath,
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
              _currentPlayingId = null;
            });
          }
        },
      );

      await _player!.setSubscriptionDuration(const Duration(milliseconds: 100));

      setState(() {
        isPlaying = true;
        isPaused = false;
        _currentPlayingPath = playPath;
        _currentPlayingId = recording.recordingId;
      });
    } catch (e) {
      _showMessage('Error playing processed recording: $e');
    }
  }

  // Future<String> _createTempFileFromBase64MongoDB(Recording recording) async {
  //   try {
  //     if (recording.audioData == null || recording.recordingId == null) {
  //       throw Exception('No audio data or recordingId available');
  //     }
  //
  //     final tempDir = await getTemporaryDirectory();
  //     final tempFile = File('${tempDir.path}/${recording.recordingId}');
  //
  //     // Decode base64 and write to file
  //     final audioBytes = base64Decode(recording.audioData!);
  //     await tempFile.writeAsBytes(audioBytes);
  //
  //     return tempFile.path;
  //   } catch (e) {
  //     throw Exception('Error creating temp file: $e');
  //   }
  // }

  Future<String> _createTempFileFromBase64MongoDB(String base64Data, String filePath) async {
    final bytes = base64Decode(base64Data);
    final file = File(filePath);
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<void> _deleteSpecificRecording(Recording recording) async {
    if (_currentUserEmail == null) return;

    try {
      // Delete from MongoDB using recordingId
      await ApiService.deleteRecording(recording.recordingId!);

      // Delete local cached file if it exists
      final tempDir = await getTemporaryDirectory();
      final localFile = File('${tempDir.path}/${recording.recordingId}');
      if (await localFile.exists()) {
        await localFile.delete();
      }

      // If this recording is currently playing, stop the player
      if (_currentPlayingId != null && _currentPlayingId == recording.recordingId) {
        await _player!.stopPlayer();
        _playbackSubscription?.cancel();
        setState(() {
          isPlaying = false;
          isPaused = false;
          _currentPlayingPath = null;
          _currentPlayingId = null;
          _playbackPosition = Duration.zero;
          _totalDuration = Duration.zero;
        });
      }

      // Reload recordings list
      await _loadExistingRecordings();
      // _showMessage('Recording deleted successfully!');
    } catch (e) {
      _showMessage('Error deleting recording: $e');
    }
  }

  Future<void> _renameRecording(String recordingId, BuildContext context, Recording recording, int index) async {
    // print('==================recordingId in rename: $recordingId');
    final TextEditingController nameController =
        TextEditingController(text: path.basenameWithoutExtension(recording.fileName!));

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
                      String newName = nameController.text.trim();

                      if (newName.isNotEmpty && !newName.endsWith('.aac')) {
                        newName = '$newName.aac';
                      }
                      // print('before');
                      // print('*********filename: $recording.fileName');
                      // print('*********newname: $newName');

                      // Get the current fileName from the recording object
                      String currentFileName = recording.fileName!;

                      if (newName.isNotEmpty && newName != currentFileName) {
                        try {
                          // print("Step 1: Checking for existing recording...");
                          // final existingRecording = await ApiService.getRecordingByEmailAndRecordingId(newName);
                          // print("Step 1 DONE.");
                          //
                          // if (existingRecording != null) {
                          //   _showMessage('A recording with this name already exists!');
                          //   return;
                          // }

                          // print("Step 2: Renaming local file...");
                          final tempDir = await getTemporaryDirectory();
                          final oldLocalFile = File('${tempDir.path}/$currentFileName ');
                          final newLocalFile = File('${tempDir.path}/$newName');

                          if (await oldLocalFile.exists()) {
                            await oldLocalFile.rename(newLocalFile.path);
                          }
                          // print("Step 2 DONE.");

                          // print("Step 3: Calling update API...");
                          // print('==================recordingId before update: $recordingId');
                          await ApiService.updateRecordingFileName(recordingId, newName);
                          // print('==================recordingId after update: $recordingId');
                          // print("Step 3 DONE. API call finished.");

                          // 4. Update local state
                          setState(() {
                            // _loadExistingRecordings();
                            // Create a new recording object for the state with the updated name
                            final updatedRecording = Recording()
                              ..recordingId = recordingId
                              ..fileName = newName
                              ..audioData = null // Don't keep audio data in memory
                              ..duration = recording.duration // Copy old metadata
                              ..createdAt = recording.createdAt
                              ..fileSize = recording.fileSize;

                            _allRecordings[index] = updatedRecording;
                          });

                          // print('after');
                          // print('*********filename: $fileName');
                          // print('*********newname: $newName');

                          // 5. If this recording is playing, update the player's state
                          if (_currentPlayingId == recordingId) {
                            _currentPlayingId = newName;
                            if (await newLocalFile.exists()) {
                              _currentPlayingPath = newLocalFile.path;
                            }
                          }

                          // _showMessage('Recording renamed successfully!');
                          Navigator.pop(context);
                        } catch (e) {
                          _showMessage('Error: The server took too long to respond.');
                          // Rollback local file rename if the API call failed
                          try {
                            final tempDir = await getTemporaryDirectory();
                            final oldLocalFile = File('${tempDir.path}/$currentFileName');
                            final newLocalFile = File('${tempDir.path}/$newName');

                            if (await newLocalFile.exists() && !await oldLocalFile.exists()) {
                              await newLocalFile.rename(oldLocalFile.path);
                            }
                          } catch (cleanupError) {
                            // Silent cleanup failure
                          }

                          _showMessage('Error renaming recording: $e');
                          Navigator.pop(context);
                        }
                      } else {
                        Navigator.pop(context);
                      }
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

  Widget _buildDurationSlider() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(Formatters.formatDuration(_playbackPosition)),
            Text(Formatters.formatDuration(_totalDuration)),
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

  //-----

  Future<void> _toggleRecording() async {
    if (!isPermissionGranted) {
      await _requestPermissions();
      return;
    }

    if (_currentUserEmail == null) {
      _showMessage('User not authenticated!');
      return;
    }

    try {
      if (isRecording) {
        await _recorder!.stopRecorder();
        _recordingSubscription?.cancel();
        await _stopBackgroundService();

        // Define onCancel callback
        onCancel() async {
          // Delete temporary recording file
          if (_currentRecordingPath != null) {
            try {
              final file = File(_currentRecordingPath!);
              if (await file.exists()) {
                await file.delete();
                print('Temporary recording file deleted: $_currentRecordingPath');
              }
            } catch (e) {
              print('Error deleting temporary file: $e');
            }
          }

          // Reset state
          setState(() {
            isRecording = false;
            _recordingDuration = Duration.zero;
            _currentRecordingPath = null;
            _recordingSubscription = null;
          });

          // _showMessage('Recording cancelled');
        }

        // _showMessage('Recording saved!');

        DialogUtils.showLoadingDialog(context, 'Processing recording...');
        final finalDuration = _recordingDuration.inMilliseconds;

        _showNamingBottomSheet(
          context,
          (String recordingName) async {
            // if (_currentRecordingPath != null) {
            //   await _saveRecordingToDatabase(finalDuration, recordingName);
            // }

            if (_currentRecordingPath != null) {
              final recordingId = await _saveRecordingToDatabase(finalDuration, recordingName);
              // print('---------//--id: $recordingId');

              if (recordingId != null) {
                // ✅ Process the recording
                // await ApiService.processRecording(recordingId);
                // print('-----------completed audio process');

                // final processedRecording = await ApiService.getRecordingByEmailAndRecordingId(recordingId);

                // Step 3: Upload processed audio to Drive
                await AudioService().processAndUploadToDrive(recordingId, context);
                // print('===============completed audio process adn drive upload!!!');

                // // ✅ Process the recording
                // await ApiService.processRecording(recordingId);
                // print('-----------completed audio process');
                //
                // await AudioService().processAndUploadToDrive(recordingId, context);
                // print('===============completed drive upload!!!');
              }
            }

            setState(() {
              isRecording = false;
              _recordingDuration = Duration.zero;
              _currentRecordingPath = null;
              _recordingSubscription = null;
            });

            await _loadExistingRecordings();
            Navigator.pop(context); // Close processing dialog
          },
          onCancel,
        );
      }
      if (!isRecording) {
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

        await _startBackgroundRecording(_currentRecordingPath!);

        setState(() {
          isRecording = true;
          isPlaying = false;
          _recordingDuration = Duration.zero;
        });

        // _showMessage('Recording started! You can now minimize the app.');
      }
    } catch (e) {
      print('Recording error: $e');
      _showMessage('Recording error: $e');
    }
  }

  // Future<void> _saveRecordingToDatabase(int duration, String fileName) async {
  //   if (_currentRecordingPath == null || _currentUserEmail == null) return;
  //
  //   try {
  //     File audioFile = File(_currentRecordingPath!);
  //
  //     if (!await audioFile.exists()) {
  //       _showMessage('Recording file not found!');
  //       return;
  //     }
  //
  //     int fileSize = await audioFile.length();
  //
  //     if (fileSize > 10 * 1024 * 1024) {
  //       _showMessage('⚠️ Recording too large for cloud storage (${Formatters.formatFileSize(fileSize)})');
  //       return;
  //     }
  //
  //     List<int> audioBytes = await audioFile.readAsBytes();
  //     String audioData = base64Encode(audioBytes);
  //
  //     if (!fileName.endsWith('.aac')) {
  //       fileName = '$fileName.aac';
  //     }
  //
  //     final recording = Recording()
  //       ..fileName = fileName
  //       ..audioData = audioData
  //       ..duration = duration
  //       ..fileSize = fileSize;
  //     // ..metadata = {
  //     //   'quality': 'high',
  //     //   'format': 'aac',
  //     //   'device': 'mobile',
  //     //   'localPath': _currentRecordingPath,
  //     // };
  //
  //     await ApiService.addRecording(recording);
  //
  //     _showMessage('☁️ Recording saved to cloud successfully!');
  //   } catch (e) {
  //     _showMessage('❌ Failed to save to cloud: $e');
  //     print('Error saving recording to database: $e');
  //   }
  // }

  Future<String?> _saveRecordingToDatabase(int duration, String fileName) async {
    if (_currentRecordingPath == null || _currentUserEmail == null) return null;

    try {
      final audioFile = File(_currentRecordingPath!);

      if (!await audioFile.exists()) {
        _showMessage('Recording file not found!');
        return null;
      }

      final fileSize = await audioFile.length();
      if (fileSize > 10 * 1024 * 1024) {
        _showMessage('⚠️ Recording too large for cloud storage (${Formatters.formatFileSize(fileSize)})');
        return null;
      }

      final audioBytes = await audioFile.readAsBytes();
      final audioData = base64Encode(audioBytes);

      if (!fileName.endsWith('.aac')) {
        fileName = '$fileName.aac';
      }

      final recording = Recording()
        ..fileName = fileName
        ..audioData = audioData
        ..duration = duration
        ..fileSize = fileSize;

      // backend should return { recordingId: "...", ... }
      final savedRecording = await ApiService.addRecording(recording);

      // _showMessage('☁️ Recording saved to cloud successfully!');

      // print('-----------id: $savedRecording.recordingId');
      return savedRecording.recordingId;
    } catch (e) {
      _showMessage('❌ Failed to save to cloud: $e');
      print('Error saving recording to database: $e');
      return null;
    }
  }

  void _showNamingBottomSheet(BuildContext context, Function(String) onNameConfirmed, VoidCallback onCancel) {
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
                  TextButton(
                    onPressed: () {
                      onCancel();
                      Navigator.pop(context);
                    },
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      final name = nameController.text.trim();
                      if (name.isNotEmpty) {
                        onNameConfirmed(name);
                      }
                      if (name.isEmpty) {
                        onNameConfirmed('recording_${DateTime.now().millisecondsSinceEpoch}');
                      }
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

  Future<String> _getRecordingPath() async {
    final directory = await getApplicationDocumentsDirectory();
    final fileName = 'recording_${DateTime.now().millisecondsSinceEpoch}.aac';
    return path.join(directory.path, fileName);
  }

  Future<void> _stopBackgroundService() async {
    try {
      _backgroundService.invoke('stopRecording');

      setState(() {
        isBackgroundServiceRunning = false;
      });
    } catch (e) {
      print('Error stopping background service: $e');
    }
  }

  //---

  Future<void> _deleteAllRecordings() async {
    if (_currentUserEmail == null) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete All Recordings?'),
          content: Text(
              'This action cannot be undone. Are you sure you want to delete all ${_allRecordings.length} recordings from the device?'),
          actions: [
            TextButton(
              child: const Text('Cancel'),
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
    if (_currentUserEmail == null) return;

    try {
      await _stopAll();

      await ApiService.deleteAllUserRecordings();

      await _loadExistingRecordings();
      // _showMessage('All recordings deleted!');
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
      // _showMessage('Everything stopped!');
    } catch (e) {
      _showMessage('Error stopping: $e');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  //onInit------------------------

  Future<void> _onInit() async {
    isLoading = true;
    refresh();
    await _configureAudioSession();
    await _initializeAudio();
    await _initializeNotifications();
    await _initializeBackgroundService();
    isLoading = false;
    refresh();
  }

  void refresh() {
    setState(() {});
  }

  Future<void> _initializeNotifications() async {
    _notificationsPlugin = FlutterLocalNotificationsPlugin();

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'voice_recorder_channel',
      'Voice Recorder Channel',
      description: 'This channel is used for background voice recording notifications.',
      importance: Importance.defaultImportance,
    );

    await _notificationsPlugin
        ?.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _notificationsPlugin?.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.actionId == 'stop_recording') {
          _stopRecordingFromNotification();
        }
      },
    );

    if (Platform.isAndroid) {
      await Permission.notification.request();
      await Permission.systemAlertWindow.request();
      await Permission.ignoreBatteryOptimizations.request();
    }
  }

  void _stopRecordingFromNotification() async {
    if (isRecording) {
      await _toggleRecording();
    }
  }

  Future<void> _startBackgroundRecording(String recordingPath) async {
    try {
      await _backgroundService.startService();
      _backgroundService.invoke('startRecording', {
        'filePath': recordingPath,
      });

      setState(() {
        isBackgroundServiceRunning = true;
      });

      // _showMessage('Background recording started');
    } catch (e) {
      print('Error starting background service: $e');
      _showMessage('Error starting background recording: $e');
    }
  }

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

  Future<void> _configureAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.defaultToSpeaker,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
        avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
        avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.speech,
          flags: AndroidAudioFlags.none,
          usage: AndroidAudioUsage.voiceCommunication,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: false,
      ));
      // print('Audio session configured successfully');
    } catch (e) {
      print('Error configuring audio session: $e');
    }
  }

  Future<void> _initializeAudio() async {
    _recorder = FlutterSoundRecorder();
    _player = FlutterSoundPlayer();

    await _requestPermissions();

    if (isPermissionGranted) {
      try {
        await _recorder!.openRecorder();
        await _player!.openPlayer();
        await _loadExistingRecordings();
        // _showMessage('Audio recorder ready!');
      } catch (e) {
        print('Error initializing audio: $e');
        _showMessage('Error initializing audio: $e');
      }
    }
  }

  Future<void> _loadExistingRecordings() async {
    if (_currentUserEmail == null) {
      setState(() {
        _allRecordings = [];
      });
      return;
    }

    try {
      final recordings = await ApiService.getUserRecordings();
      if (mounted) {
        setState(() {
          _allRecordings = recordings;
          // for (var r in _allRecordings) {
          //   debugPrint("+++++🎵 fileName=${r.fileName}, createdAt=${r.createdAt}");
          // }
        });
      }
    } catch (e) {
      print('Error loading recordings: $e');
      if (mounted) {
        _showMessage('Error loading recordings: $e');
      }
    }
  }

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

    if (permissions[Permission.microphone] == PermissionStatus.granted) {
      setState(() {
        isPermissionGranted = true;
      });
    }

    if (!isPermissionGranted) {
      _showMessage('Microphone permission is required!');
    }
    if (!allGranted) {
      _showMessage('Some permissions missing. Background recording may not work properly.');
      permissions.forEach((permission, status) {
        if (status != PermissionStatus.granted && status != PermissionStatus.limited) {
          print('Missing permission: $permission, Status: $status');
        }
      });
    }
    if (allGranted) {
      // _showMessage('All permissions granted! Background recording enabled.');
    }
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
}
