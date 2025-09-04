// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recording_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Recording _$RecordingFromJson(Map<String, dynamic> json) => Recording()
  ..recordingId = json['recordingId'] as String?
  ..fileName = json['fileName'] as String?
  ..audioData = json['audioData'] as String?
  ..processedAudio = json['processedAudio'] as String?
  ..duration = (json['duration'] as num?)?.toInt()
  ..createdAt = json['createdAt'] as String?
  ..fileSize = (json['fileSize'] as num?)?.toInt();

Map<String, dynamic> _$RecordingToJson(Recording instance) => <String, dynamic>{
      'recordingId': instance.recordingId,
      'fileName': instance.fileName,
      'audioData': instance.audioData,
      'processedAudio': instance.processedAudio,
      'duration': instance.duration,
      'createdAt': instance.createdAt,
      'fileSize': instance.fileSize,
    };
