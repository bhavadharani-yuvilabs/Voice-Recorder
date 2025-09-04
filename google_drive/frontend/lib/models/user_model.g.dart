// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppUser _$AppUserFromJson(Map<String, dynamic> json) => AppUser()
  ..userId = json['userId'] as String?
  ..email = json['email'] as String?
  ..displayName = json['displayName'] as String?
  ..photoURL = json['photoURL'] as String?
  ..createdAt = json['createdAt'] as String?
  ..lastLoginAt = json['lastLoginAt'] as String?
  ..token = json['token'] as String?;

Map<String, dynamic> _$AppUserToJson(AppUser instance) => <String, dynamic>{
      'userId': instance.userId,
      'email': instance.email,
      'displayName': instance.displayName,
      'photoURL': instance.photoURL,
      'createdAt': instance.createdAt,
      'lastLoginAt': instance.lastLoginAt,
      'token': instance.token,
    };
