import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/recording_model.dart';
import '../services/firestore_service.dart';

class UploadedRecordingsScreen extends StatelessWidget {
  final FirestoreService _firestoreService = FirestoreService();

  UploadedRecordingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cloud Recordings'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<Recording>>(
        future: _firestoreService.getAllRecordings(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading cloud recordings...'),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 60, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text('Error loading recordings'),
                  const SizedBox(height: 8),
                  Text('${snapshot.error}', style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      (context as Element).markNeedsBuild();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          List<Recording> recordings = snapshot.data ?? [];

          if (recordings.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.cloud_off, size: 60, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text('No cloud recordings yet', style: TextStyle(color: Colors.grey[600])),
                  const SizedBox(height: 8),
                  Text('Upload recordings from the main screen',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              (context as Element).markNeedsBuild();
            },
            child: ListView.builder(
              itemCount: recordings.length,
              itemBuilder: (context, index) {
                Recording recording = recordings[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.blue,
                      child: Icon(Icons.audiotrack, color: Colors.white),
                    ),
                    title: Text(
                      recording.fileName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            '${_formatFileSize(recording.fileSize)} • ${_formatDuration(Duration(milliseconds: recording.duration))}'),
                        // Text('${_formatFileSize(recording.fileSize)} • ${_formatDuration(recording.duration)}'),
                        Text(_formatDate(recording.createdAt)),
                      ],
                    ),
                    trailing: PopupMenuButton(
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          child: Row(
                            children: [
                              Icon(Icons.play_arrow, size: 20),
                              SizedBox(width: 8),
                              Text('Play'),
                            ],
                          ),
                          value: 'play',
                        ),
                        const PopupMenuItem(
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: Colors.red, size: 20),
                              SizedBox(width: 8),
                              Text('Delete', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                          value: 'delete',
                        ),
                      ],
                      onSelected: (value) {
                        if (value == 'delete') {
                          _deleteRecording(context, recording.id, index);
                        } else if (value == 'play') {
                          _playCloudRecording(context, recording);
                        }
                      },
                    ),
                    onTap: () => _playCloudRecording(context, recording),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  String _formatDate(DateTime date) {
    String period = date.hour < 12 ? 'AM' : 'PM';
    int hour = date.hour == 0 ? 12 : (date.hour > 12 ? date.hour - 12 : date.hour);
    return '${date.day}/${date.month}/${date.year} $hour:${date.minute.toString().padLeft(2, '0')} $period';
  }

  void _deleteRecording(BuildContext context, String recordingId, int index) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Recording'),
        content: const Text('Are you sure you want to delete this cloud recording? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _firestoreService.deleteRecording(recordingId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recording deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        // Refresh the screen
        (context as Element).markNeedsBuild();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete recording: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _playCloudRecording(BuildContext context, Recording recording) {
    // TODO: Implement cloud recording playback
    // You'll need to decode the base64 audioData and play it
    // For now, show a placeholder message
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cloud Playback'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Recording: ${recording.fileName}'),
            const SizedBox(height: 8),
            Text('Duration: ${_formatDuration(Duration(milliseconds: recording.duration))}'),
            // Text('Duration: ${_formatDuration(recording.duration)}'),
            const SizedBox(height: 8),
            Text('Size: ${_formatFileSize(recording.fileSize)}'),
            const SizedBox(height: 16),
            const Text('Cloud playback feature will be implemented in the next update!',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
