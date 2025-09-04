import 'package:flutter/material.dart';
import 'api_service.dart';
import 'google_drive_service.dart';

class AudioService {
  final GoogleDriveService _driveService = GoogleDriveService();

  Future<void> processAndUploadToDrive(String recordingId, BuildContext context) async {
    try {
      // Initialize Google Drive
      if (!await _driveService.initialize()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in with Google to continue')),
        );
        throw Exception('Failed to initialize Google Drive');
      }

      // Process audio via server
      final response = await ApiService.processAndPrepareForDrive(recordingId);
      if (!response['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to process audio: ${response['message']}')),
        );
        throw Exception('Failed to process audio: ${response['message']}');
      }

      final processedAudio = response['processedAudio'] as String;
      print('******************processedAudio:  $processedAudio');

      final fileName = response['metadata']['fileName'] as String? ?? 'audio.m4a';

      // Upload to Google Drive
      final driveFileId = await _driveService.uploadAudioFile(
        base64Audio: processedAudio,
        fileName: fileName,
      );
      if (driveFileId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to upload to Google Drive')),
        );
        throw Exception('Failed to upload to Google Drive');
      }

      // Update server with Drive file ID
      await ApiService.updateRecordingDriveInfo(recordingId, driveFileId, 'uploaded');
      // ScaffoldMessenger.of(context).showSnackBar(
      //   const SnackBar(content: Text('Successfully uploaded to Google Drive')),
      // );
      print('✅ Successfully uploaded to Google Drive and updated server');
    } catch (e, stackTrace) {
      print('❌ Error in processAndUploadToDrive: $e\n$stackTrace');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
}
