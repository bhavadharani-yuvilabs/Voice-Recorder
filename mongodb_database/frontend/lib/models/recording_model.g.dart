// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recording_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Recording _$RecordingFromJson(Map<String, dynamic> json) => Recording()
  ..fileName = json['fileName'] as String?
  ..audioData = json['audioData'] as String?
  ..duration = (json['duration'] as num?)?.toInt()
  ..createdAt = json['createdAt'] as String?
  ..fileSize = (json['fileSize'] as num?)?.toInt();

Map<String, dynamic> _$RecordingToJson(Recording instance) => <String, dynamic>{
      'fileName': instance.fileName,
      'audioData': instance.audioData,
      'duration': instance.duration,
      'createdAt': instance.createdAt,
      'fileSize': instance.fileSize,
    };
