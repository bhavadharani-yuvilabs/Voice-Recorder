// import 'package:firebase_auth/firebase_auth.dart' as auth;
// import '../models/recording_model.dart';
// import '../models/user_model.dart';
// import 'firestore_service.dart';
//
// class RecordingAppService {
//   /// Initialize user on first login/signup
//   static Future<void> initializeUser(auth.User firebaseUser) async {
//     try {
//       // Create user model
//       final user = AppUser(
//         uid: firebaseUser.uid,
//         email: firebaseUser.email!,
//         displayName: firebaseUser.displayName,
//         photoURL: firebaseUser.photoURL,
//         createdAt: DateTime.now(),
//         lastLoginAt: DateTime.now(),
//       );
//
//       // Save user to Firestore
//       await FirestoreService.createOrUpdateUser(user);
//
//       // Initialize recordings metadata
//       await FirestoreService.createUserRecordingsMeta(firebaseUser.email!);
//
//       print('User initialized successfully');
//     } catch (e) {
//       print('Error initializing user: $e');
//       rethrow;
//     }
//   }
//
//   /// Save a new recording
//   static Future<String> saveRecording({
//     required String userEmail,
//     required String fileName,
//     required String audioData,
//     required int duration,
//     required int fileSize,
//     Map<String, dynamic>? metadata,
//   }) async {
//     try {
//       final recording = Recording(
//         id: '', // Will be set by Firestore
//         fileName: fileName,
//         audioData: audioData,
//         duration: duration,
//         createdAt: DateTime.now(),
//         fileSize: fileSize,
//         metadata: metadata,
//       );
//
//       final recordingId = await FirestoreService.addRecording(userEmail, recording);
//       print('Recording saved with ID: $recordingId');
//
//       return recordingId;
//     } catch (e) {
//       print('Error saving recording: $e');
//       rethrow;
//     }
//   }
//
//   /// Get all recordings for current user
//   static Future<List<Recording>> getUserRecordings(String userEmail) async {
//     try {
//       return await FirestoreService.getUserRecordings(userEmail);
//     } catch (e) {
//       print('Error getting recordings: $e');
//       rethrow;
//     }
//   }
//
//   /// Delete a recording
//   static Future<void> deleteRecording(String userEmail, String recordingId) async {
//     try {
//       await FirestoreService.deleteRecording(userEmail, recordingId);
//       print('Recording deleted successfully');
//     } catch (e) {
//       print('Error deleting recording: $e');
//       rethrow;
//     }
//   }
//
//   /// Get user storage info
//   static Future<Map<String, dynamic>> getUserStorageInfo(String userEmail) async {
//     try {
//       final meta = await FirestoreService.getUserRecordingsMeta(userEmail);
//
//       if (meta != null) {
//         return {
//           'totalRecordings': meta.totalRecordings,
//           'totalStorageUsed': meta.totalStorageUsed,
//           'formattedStorage': _formatBytes(meta.totalStorageUsed),
//           'lastRecordingAt': meta.lastRecordingAt,
//         };
//       }
//
//       return {
//         'totalRecordings': 0,
//         'totalStorageUsed': 0,
//         'formattedStorage': '0 B',
//         'lastRecordingAt': null,
//       };
//     } catch (e) {
//       print('Error getting storage info: $e');
//       rethrow;
//     }
//   }
//
//   /// Search recordings
//   static Future<List<Recording>> searchUserRecordings(String userEmail, String query) async {
//     try {
//       return await FirestoreService.searchRecordings(userEmail, query);
//     } catch (e) {
//       print('Error searching recordings: $e');
//       rethrow;
//     }
//   }
//
//   /// Helper method to format bytes
//   static String _formatBytes(int bytes) {
//     if (bytes < 1024) return '$bytes B';
//     if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
//     return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
//   }
// }
//
// // Example usage in your app:
// class ExampleUsage {
//   /// Example: User login/signup
//   static Future<void> handleUserAuth(auth.User firebaseUser) async {
//     try {
//       // Check if user exists
//       final existingUser = await FirestoreService.getUserById(firebaseUser.uid);
//
//       if (existingUser == null) {
//         // New user - initialize
//         await RecordingAppService.initializeUser(firebaseUser);
//       } else {
//         // Existing user - update last login
//         await FirestoreService.updateUserLastLogin(firebaseUser.uid);
//       }
//     } catch (e) {
//       print('Error handling user auth: $e');
//     }
//   }
//
//   /// Example: Save recording after recording is complete
//   static Future<void> handleRecordingSave(String userEmail, String audioBase64) async {
//     try {
//       final recordingId = await RecordingAppService.saveRecording(
//         userEmail: userEmail,
//         fileName: 'Recording_${DateTime.now().millisecondsSinceEpoch}.m4a',
//         audioData: audioBase64,
//         duration: 120000, // 2 minutes in milliseconds
//         fileSize: audioBase64.length, // Approximate file size
//         metadata: {
//           'quality': 'high',
//           'format': 'm4a',
//           'device': 'mobile',
//         },
//       );
//
//       print('Recording saved successfully with ID: $recordingId');
//     } catch (e) {
//       print('Failed to save recording: $e');
//     }
//   }
//
//   /// Example: Load recordings for display
//   static Future<void> loadUserRecordings(String userEmail) async {
//     try {
//       final recordings = await RecordingAppService.getUserRecordings(userEmail);
//
//       print('Found ${recordings.length} recordings');
//       for (final recording in recordings) {
//         print('Recording: ${recording.fileName} - ${recording.formattedDuration}');
//       }
//     } catch (e) {
//       print('Failed to load recordings: $e');
//     }
//   }
//
//   /// Example: Real-time updates with streams
//   static void setupRealTimeUpdates(String userEmail) {
//     // Listen to recordings changes
//     FirestoreService.streamUserRecordings(userEmail).listen(
//       (recordings) {
//         print('Recordings updated: ${recordings.length} total');
//         // Update your UI here
//       },
//       onError: (error) {
//         print('Error in recordings stream: $error');
//       },
//     );
//
//     // Listen to metadata changes
//     FirestoreService.streamUserRecordingsMeta(userEmail).listen(
//       (meta) {
//         if (meta != null) {
//           print('Storage: ${meta.totalStorageUsed} bytes, ${meta.totalRecordings} recordings');
//           // Update your UI here
//         }
//       },
//       onError: (error) {
//         print('Error in metadata stream: $error');
//       },
//     );
//   }
// }
