// import 'package:cloud_firestore/cloud_firestore.dart';
// import '../models/recording_model.dart';
// import '../models/user_model.dart';
// import '../models/user_recordings.dart';
//
// class FirestoreService {
//   static final FirebaseFirestore _db = FirebaseFirestore.instance;
//
//   // Collection references
//   static const String _usersCollection = 'users';
//   static const String _recordingsCollection = 'recordings';
//   static const String _recordingsSubcollection = 'recordings';
//
//   // USER OPERATIONS
//
//   /// Create or update user in Firestore
//   static Future<void> createOrUpdateUser(AppUser user) async {
//     try {
//       await _db.collection(_usersCollection).doc(user.uid).set(user.toMap());
//     } catch (e) {
//       throw Exception('Failed to create/update user: $e');
//     }
//   }
//
//   /// Get user by UID
//   static Future<AppUser?> getUserById(String uid) async {
//     try {
//       final doc = await _db.collection(_usersCollection).doc(uid).get();
//       if (doc.exists && doc.data() != null) {
//         return AppUser.fromMap(doc.data()!, doc.id);
//       }
//       return null;
//     } catch (e) {
//       throw Exception('Failed to get user: $e');
//     }
//   }
//
//   /// Get user by email
//   static Future<AppUser?> getUserByEmail(String email) async {
//     try {
//       final query = await _db.collection(_usersCollection).where('email', isEqualTo: email).limit(1).get();
//
//       if (query.docs.isNotEmpty) {
//         final doc = query.docs.first;
//         return AppUser.fromMap(doc.data(), doc.id);
//       }
//       return null;
//     } catch (e) {
//       throw Exception('Failed to get user by email: $e');
//     }
//   }
//
//   /// Update user last login
//   static Future<void> updateUserLastLogin(String uid) async {
//     try {
//       await _db.collection(_usersCollection).doc(uid).update({
//         'lastLoginAt': FieldValue.serverTimestamp(),
//       });
//     } catch (e) {
//       throw Exception('Failed to update last login: $e');
//     }
//   }
//
//   // USER RECORDINGS META OPERATIONS
//
//   /// Create user recordings metadata
//   static Future<void> createUserRecordingsMeta(String userEmail) async {
//     try {
//       final meta = UserRecordingsMeta(
//         userEmail: userEmail,
//         createdAt: DateTime.now(),
//       );
//
//       await _db.collection(_recordingsCollection).doc(userEmail).set(meta.toMap());
//     } catch (e) {
//       throw Exception('Failed to create user recordings meta: $e');
//     }
//   }
//
//   /// Get user recordings metadata
//   static Future<UserRecordingsMeta?> getUserRecordingsMeta(String userEmail) async {
//     try {
//       final doc = await _db.collection(_recordingsCollection).doc(userEmail).get();
//       if (doc.exists && doc.data() != null) {
//         return UserRecordingsMeta.fromMap(doc.data()!, doc.id);
//       }
//       return null;
//     } catch (e) {
//       throw Exception('Failed to get user recordings meta: $e');
//     }
//   }
//
//   /// Update user recordings metadata
//   static Future<void> updateUserRecordingsMeta({
//     required String userEmail,
//     int? totalRecordings,
//     int? totalStorageUsed,
//     DateTime? lastRecordingAt,
//   }) async {
//     try {
//       Map<String, dynamic> updates = {};
//
//       if (totalRecordings != null) updates['totalRecordings'] = totalRecordings;
//       if (totalStorageUsed != null) updates['totalStorageUsed'] = totalStorageUsed;
//       if (lastRecordingAt != null) updates['lastRecordingAt'] = Timestamp.fromDate(lastRecordingAt);
//
//       if (updates.isNotEmpty) {
//         await _db.collection(_recordingsCollection).doc(userEmail).update(updates);
//       }
//     } catch (e) {
//       throw Exception('Failed to update user recordings meta: $e');
//     }
//   }
//
//   // RECORDING OPERATIONS
//
//   /// Add a new recording
//   static Future<String> addRecording(String userEmail, Recording recording) async {
//     try {
//       // Add recording to subcollection
//       final docRef = await _db
//           .collection(_recordingsCollection)
//           .doc(userEmail)
//           .collection(_recordingsSubcollection)
//           .add(recording.toMap());
//
//       // Update metadata
//       await _updateRecordingsMetaOnAdd(userEmail, recording.fileSize);
//
//       return docRef.id;
//     } catch (e) {
//       throw Exception('Failed to add recording: $e');
//     }
//   }
//
//   /// Get all recordings for a user
//   static Future<List<Recording>> getUserRecordings(String userEmail) async {
//     try {
//       final querySnapshot = await _db
//           .collection(_recordingsCollection)
//           .doc(userEmail)
//           .collection(_recordingsSubcollection)
//           .orderBy('createdAt', descending: true)
//           .get();
//
//       return querySnapshot.docs.map((doc) => Recording.fromMap(doc.data(), doc.id)).toList();
//     } catch (e) {
//       throw Exception('Failed to get user recordings: $e');
//     }
//   }
//
//   /// Get recording by ID
//   static Future<Recording?> getRecording(String userEmail, String recordingId) async {
//     try {
//       final doc = await _db
//           .collection(_recordingsCollection)
//           .doc(userEmail)
//           .collection(_recordingsSubcollection)
//           .doc(recordingId)
//           .get();
//
//       if (doc.exists && doc.data() != null) {
//         return Recording.fromMap(doc.data()!, doc.id);
//       }
//       return null;
//     } catch (e) {
//       throw Exception('Failed to get recording: $e');
//     }
//   }
//
//   /// Update a recording
//   static Future<void> updateRecording(String userEmail, String recordingId, Map<String, dynamic> updates) async {
//     try {
//       await _db
//           .collection(_recordingsCollection)
//           .doc(userEmail)
//           .collection(_recordingsSubcollection)
//           .doc(recordingId)
//           .update(updates);
//     } catch (e) {
//       throw Exception('Failed to update recording: $e');
//     }
//   }
//
//   /// Delete a recording
//   static Future<void> deleteRecording(String userEmail, String recordingId) async {
//     try {
//       // Get recording data first to update metadata
//       final recording = await getRecording(userEmail, recordingId);
//
//       // Delete the recording
//       await _db
//           .collection(_recordingsCollection)
//           .doc(userEmail)
//           .collection(_recordingsSubcollection)
//           .doc(recordingId)
//           .delete();
//
//       // Update metadata if recording existed
//       if (recording != null) {
//         await _updateRecordingsMetaOnDelete(userEmail, recording.fileSize);
//       }
//     } catch (e) {
//       throw Exception('Failed to delete recording: $e');
//     }
//   }
//
//   /// Get recordings with pagination
//   static Future<List<Recording>> getUserRecordingsPaginated({
//     required String userEmail,
//     int limit = 20,
//     DocumentSnapshot? lastDocument,
//   }) async {
//     try {
//       Query query = _db
//           .collection(_recordingsCollection)
//           .doc(userEmail)
//           .collection(_recordingsSubcollection)
//           .orderBy('createdAt', descending: true)
//           .limit(limit);
//
//       if (lastDocument != null) {
//         query = query.startAfterDocument(lastDocument);
//       }
//
//       final querySnapshot = await query.get();
//
//       return querySnapshot.docs.map((doc) => Recording.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();
//     } catch (e) {
//       throw Exception('Failed to get paginated recordings: $e');
//     }
//   }
//
//   /// Search recordings by filename
//   static Future<List<Recording>> searchRecordings(String userEmail, String searchQuery) async {
//     try {
//       final querySnapshot = await _db
//           .collection(_recordingsCollection)
//           .doc(userEmail)
//           .collection(_recordingsSubcollection)
//           .orderBy('fileName')
//           .startAt([searchQuery]).endAt([searchQuery + '\uf8ff']).get();
//
//       return querySnapshot.docs.map((doc) => Recording.fromMap(doc.data(), doc.id)).toList();
//     } catch (e) {
//       throw Exception('Failed to search recordings: $e');
//     }
//   }
//
//   // PRIVATE HELPER METHODS
//
//   /// Update metadata when adding a recording
//   static Future<void> _updateRecordingsMetaOnAdd(String userEmail, int fileSize) async {
//     try {
//       await _db.collection(_recordingsCollection).doc(userEmail).update({
//         'totalRecordings': FieldValue.increment(1),
//         'totalStorageUsed': FieldValue.increment(fileSize),
//         'lastRecordingAt': FieldValue.serverTimestamp(),
//       });
//     } catch (e) {
//       // If document doesn't exist, create it
//       await createUserRecordingsMeta(userEmail);
//       await _updateRecordingsMetaOnAdd(userEmail, fileSize);
//     }
//   }
//
//   /// Update metadata when deleting a recording
//   static Future<void> _updateRecordingsMetaOnDelete(String userEmail, int fileSize) async {
//     try {
//       await _db.collection(_recordingsCollection).doc(userEmail).update({
//         'totalRecordings': FieldValue.increment(-1),
//         'totalStorageUsed': FieldValue.increment(-fileSize),
//       });
//     } catch (e) {
//       throw Exception('Failed to update metadata on delete: $e');
//     }
//   }
//
//   // STREAM METHODS FOR REAL-TIME UPDATES
//
//   /// Stream user recordings
//   static Stream<List<Recording>> streamUserRecordings(String userEmail) {
//     return _db
//         .collection(_recordingsCollection)
//         .doc(userEmail)
//         .collection(_recordingsSubcollection)
//         .orderBy('createdAt', descending: true)
//         .snapshots()
//         .map((snapshot) => snapshot.docs.map((doc) => Recording.fromMap(doc.data(), doc.id)).toList());
//   }
//
//   /// Stream user recordings metadata
//   static Stream<UserRecordingsMeta?> streamUserRecordingsMeta(String userEmail) {
//     return _db.collection(_recordingsCollection).doc(userEmail).snapshots().map((doc) {
//       if (doc.exists && doc.data() != null) {
//         return UserRecordingsMeta.fromMap(doc.data()!, doc.id);
//       }
//       return null;
//     });
//   }
//
//   // BATCH OPERATIONS
//
//   /// Delete all recordings for a user
//   static Future<void> deleteAllUserRecordings(String userEmail) async {
//     try {
//       final batch = _db.batch();
//
//       final recordings =
//           await _db.collection(_recordingsCollection).doc(userEmail).collection(_recordingsSubcollection).get();
//
//       for (final doc in recordings.docs) {
//         batch.delete(doc.reference);
//       }
//
//       // Reset metadata
//       batch.update(_db.collection(_recordingsCollection).doc(userEmail), {
//         'totalRecordings': 0,
//         'totalStorageUsed': 0,
//         'lastRecordingAt': null,
//       });
//
//       await batch.commit();
//     } catch (e) {
//       throw Exception('Failed to delete all recordings: $e');
//     }
//   }
// }
