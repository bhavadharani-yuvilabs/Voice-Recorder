import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:json_annotation/json_annotation.dart';

part 'recording_model.g.dart';

@JsonSerializable()
class Recording {
  final String id;
  final String fileName;
  final String audioData; // Base64 encoded audio
  final int duration;
  // final Duration duration; // in milliseconds
  @JsonKey(fromJson: _dateTimeFromTimestamp, toJson: _dateTimeToTimestamp)
  final DateTime createdAt;
  final int fileSize; // in bytes
  final Map<String, dynamic>? metadata;

  Recording({
    required this.id,
    required this.fileName,
    required this.audioData,
    required this.duration,
    required this.createdAt,
    required this.fileSize,
    this.metadata,
  });

  factory Recording.fromJson(Map<String, dynamic> json) => _$RecordingFromJson(json);

  Map<String, dynamic> toJson() => _$RecordingToJson(this);

  // Convert to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fileName': fileName,
      'audioData': audioData,
      'duration': duration,
      'createdAt': Timestamp.fromDate(createdAt),
      'fileSize': fileSize,
      'metadata': metadata ?? {},
    };
  }

  // Create from Firestore document
  factory Recording.fromMap(Map<String, dynamic> map, String documentId) {
    return Recording(
      id: documentId,
      fileName: map['fileName'] ?? '',
      audioData: map['audioData'] ?? '',
      // duration: Duration(milliseconds: map['duration'] ?? 0),
      duration: map['duration'] ?? 0,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      fileSize: map['fileSize'] ?? 0,
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }

  // Helper methods for DateTime conversion
  static DateTime _dateTimeFromTimestamp(Timestamp timestamp) => timestamp.toDate();

  static Timestamp _dateTimeToTimestamp(DateTime dateTime) => Timestamp.fromDate(dateTime);
}
