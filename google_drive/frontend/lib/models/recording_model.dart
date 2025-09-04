import 'package:json_annotation/json_annotation.dart';

part 'recording_model.g.dart';

@JsonSerializable()
class Recording {
  String? recordingId;
  String? fileName;
  String? audioData;
  String? processedAudio;
  String? driveFileId;
  String? status; // New
  int? downloadCount;
  int? duration;
  String? createdAt;
  int? fileSize;

  Recording();

  factory Recording.fromJson(Map<String, dynamic> json) => _$RecordingFromJson(json);

  Map<String, dynamic> toJson() => _$RecordingToJson(this);
}
