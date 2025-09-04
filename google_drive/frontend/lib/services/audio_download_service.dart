import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'google_drive_service.dart';
import 'api_service.dart'; // Assuming this is your ApiService file

class AudioDownloadService {
  final GoogleDriveService _driveService = GoogleDriveService();

  Future<File?> downloadProcessedAudio(String recordingId) async {
    try {
      // 1. Get metadata from your server
      final recording = await ApiService.getRecordingByEmailAndRecordingId(recordingId);
      if (recording == null || recording.driveFileId == null) {
        throw Exception('No Google Drive file found for this recording');
      }

      // 2. Download from Google Drive
      final audioData = await _driveService.downloadFile(recording.driveFileId!);
      if (audioData == null) {
        throw Exception('Failed to download from Google Drive');
      }

      // 3. Save to device
      final savedFile = await _saveAudioFile(audioData, recording.fileName ?? 'audio.m4a');

      // 4. Update download count
      await ApiService.incrementDownloadCount(recordingId);

      return savedFile;
    } catch (e) {
      print('❌ Error downloading audio: $e');
      return null;
    }
  }

  Future<File> _saveAudioFile(Uint8List audioData, String fileName) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/downloads/processed_$fileName');

    // Create directory if it doesn't exist
    await file.parent.create(recursive: true);

    // Write the file
    await file.writeAsBytes(audioData);

    return file;
  }
}
