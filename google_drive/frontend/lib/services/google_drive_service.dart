import 'dart:convert';
import 'dart:typed_data';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/googleapis_auth.dart' as auth;
import 'package:http/http.dart' as http;

class GoogleDriveService {
  static const _scopes = [drive.DriveApi.driveFileScope];
  drive.DriveApi? _driveApi;
  static GoogleDriveService? _instance;

  GoogleDriveService._internal();

  factory GoogleDriveService() {
    _instance ??= GoogleDriveService._internal();
    return _instance!;
  }

  Future<bool> initialize() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(scopes: _scopes);
      GoogleSignInAccount? account = await googleSignIn.signIn();

      account ??= await googleSignIn.signIn();

      if (account != null) {
        final headers = await account.authHeaders;
        final client = auth.authenticatedClient(
          http.Client(),
          auth.AccessCredentials(
            auth.AccessToken(
              'Bearer',
              headers['Authorization']!.split(' ')[1],
              DateTime.now().toUtc().add(const Duration(hours: 1)),
            ),
            null,
            _scopes,
          ),
        );
        _driveApi = drive.DriveApi(client);
        print('✅ Google Drive initialized successfully');
        return true;
      } else {
        print('❌ Google Sign-In failed: No account selected');
        return false;
      }
    } catch (e, stackTrace) {
      print('❌ Error initializing Google Drive: $e\n$stackTrace');
      return false;
    }
  }

  Future<String?> uploadAudioFile({
    required String base64Audio,
    required String fileName,
    String? folderId,
  }) async {
    try {
      if (_driveApi == null) {
        throw Exception('Google Drive API not initialized');
      }

      final audioBytes = base64Decode(base64Audio);

      final driveFile = drive.File()
        ..name = 'processed_$fileName'
        ..description = 'Processed audio - ${DateTime.now().toIso8601String()}';

      if (folderId != null) {
        driveFile.parents = [folderId];
      }

      final media = drive.Media(
        Stream.fromIterable([audioBytes]),
        audioBytes.length,
      );

      final result = await _driveApi!.files.create(
        driveFile,
        uploadMedia: media,
      );

      return result.id;
    } catch (e) {
      print('❌ Error uploading to Google Drive: $e');
      return null;
    }
  }

  Future<Uint8List?> downloadFile(String fileId) async {
    try {
      if (_driveApi == null) {
        throw Exception('Google Drive API not initialized');
      }

      final response = await _driveApi!.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final List<int> bytes = [];
      await for (final chunk in response.stream) {
        bytes.addAll(chunk);
      }

      return Uint8List.fromList(bytes);
    } catch (e) {
      print('❌ Error downloading from Google Drive: $e');
      return null;
    }
  }
}
