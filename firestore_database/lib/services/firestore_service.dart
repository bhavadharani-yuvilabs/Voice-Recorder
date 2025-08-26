// lib/services/firestore_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/recording_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'recordings';

  /// Upload recording to Firestore
  Future<String> uploadRecording(File audioFile, String fileName, int? duration) async {
    try {
      // Read audio file and convert to base64
      List<int> audioBytes = await audioFile.readAsBytes();
      String base64Audio = base64Encode(audioBytes);

      // Check if file size is under 1MB (Firestore limit)
      if (audioBytes.length > 1024 * 1024) {
        throw Exception('File size exceeds 1MB limit for Firestore');
      }

      // Get file creation date
      FileStat fileStat = await audioFile.stat();
      DateTime originalCreateDate = fileStat.modified;

      // Create recording document
      DocumentReference docRef = await _firestore.collection(_collection).add({
        'fileName': fileName,
        'audioData': base64Audio,
        'duration': duration ?? 0, // Use provided duration or default to 0
        'createdAt': Timestamp.fromDate(originalCreateDate), // Use original file creation date
        'fileSize': audioBytes.length,
        'metadata': {
          'platform': Platform.operatingSystem,
          'uploadedAt': DateTime.now().toIso8601String(),
          'originalCreatedAt': originalCreateDate.toIso8601String(),
        },
      });

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to upload recording: $e');
    }
  }

  /// Get all recordings from Firestore
  Future<List<Recording>> getAllRecordings() async {
    try {
      QuerySnapshot snapshot = await _firestore.collection(_collection).orderBy('createdAt', descending: true).get();

      return snapshot.docs.map((doc) => Recording.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();
    } catch (e) {
      throw Exception('Failed to fetch recordings: $e');
    }
  }

  /// Get specific recording by ID
  Future<Recording?> getRecording(String recordingId) async {
    try {
      DocumentSnapshot doc = await _firestore.collection(_collection).doc(recordingId).get();

      if (doc.exists) {
        return Recording.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to fetch recording: $e');
    }
  }

  /// Delete recording from Firestore
  Future<void> deleteRecording(String recordingId) async {
    try {
      await _firestore.collection(_collection).doc(recordingId).delete();
    } catch (e) {
      throw Exception('Failed to delete recording: $e');
    }
  }

  /// Delete all recordings from Firestore
  Future<void> deleteAllRecordings() async {
    try {
      // Get all documents in the collection
      QuerySnapshot snapshot = await _firestore.collection(_collection).get();

      // Create a batch to delete all documents
      WriteBatch batch = _firestore.batch();

      // Add each document to the batch for deletion
      for (QueryDocumentSnapshot doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      // Commit the batch
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to delete all recordings: $e');
    }
  }

  /// Update recording duration (call this after you get actual duration)
  Future<void> updateRecordingDuration(String recordingId, int duration) async {
    try {
      await _firestore.collection(_collection).doc(recordingId).update({
        'duration': duration,
      });
    } catch (e) {
      throw Exception('Failed to update recording duration: $e');
    }
  }

  /// Get recordings with real-time updates
  Stream<List<Recording>> getRecordingsStream() {
    return _firestore.collection(_collection).orderBy('createdAt', descending: true).snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => Recording.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList());
  }

  /// Update recording metadata
  Future<void> updateRecordingMetadata(String recordingId, Map<String, dynamic> metadata) async {
    try {
      await _firestore.collection(_collection).doc(recordingId).update({
        'metadata': metadata,
      });
    } catch (e) {
      throw Exception('Failed to update recording metadata: $e');
    }
  }

  /// Updates the fileName of a specific recording document.
  Future<void> updateRecordingFileName(String recordingId, String newName) async {
    try {
      await _firestore.collection(_collection).doc(recordingId).update({
        'fileName': newName,
      });
    } catch (e) {
      // Re-throw the exception to be handled by the UI
      throw Exception('Failed to update recording name: $e');
    }
  }

  // It's also helpful to have a function to find a recording by its old name
  Future<String?> getRecordingIdByFileName(String fileName) async {
    try {
      final query = await _firestore.collection(_collection).where('fileName', isEqualTo: fileName).limit(1).get();

      if (query.docs.isNotEmpty) {
        return query.docs.first.id;
      }
      return null; // Return null if no matching document is found
    } catch (e) {
      throw Exception('Failed to find recording by name: $e');
    }
  }
}
