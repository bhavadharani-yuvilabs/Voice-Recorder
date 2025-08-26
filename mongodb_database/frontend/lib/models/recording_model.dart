import 'package:json_annotation/json_annotation.dart';

part 'recording_model.g.dart';

@JsonSerializable()
class Recording {
  String? fileName;
  String? audioData;
  int? duration;
  String? createdAt;
  int? fileSize;

  Recording();

  factory Recording.fromJson(Map<String, dynamic> json) => _$RecordingFromJson(json);

  Map<String, dynamic> toJson() => _$RecordingToJson(this);
}
