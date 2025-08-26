// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recording_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Recording _$RecordingFromJson(Map<String, dynamic> json) => Recording(
      id: json['id'] as String,
      fileName: json['fileName'] as String,
      audioData: json['audioData'] as String,
      duration: (json['duration'] as num).toInt(),
      createdAt:
          Recording._dateTimeFromTimestamp(json['createdAt'] as Timestamp),
      fileSize: (json['fileSize'] as num).toInt(),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$RecordingToJson(Recording instance) => <String, dynamic>{
      'id': instance.id,
      'fileName': instance.fileName,
      'audioData': instance.audioData,
      'duration': instance.duration,
      'createdAt': Recording._dateTimeToTimestamp(instance.createdAt),
      'fileSize': instance.fileSize,
      'metadata': instance.metadata,
    };
