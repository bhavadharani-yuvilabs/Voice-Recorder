import 'package:json_annotation/json_annotation.dart';

part 'user_model.g.dart';

@JsonSerializable()
class AppUser {
  String? userId;
  String? email;
  String? displayName;
  String? photoURL;
  String? createdAt;
  String? lastLoginAt;
  String? token;

  AppUser();

  factory AppUser.fromJson(Map<String, dynamic> json) => _$AppUserFromJson(json);

  Map<String, dynamic> toJson() => _$AppUserToJson(this);
}
