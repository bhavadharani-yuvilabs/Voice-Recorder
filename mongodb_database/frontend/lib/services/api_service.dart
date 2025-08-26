import 'dart:convert';
import 'dart:core';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../models/recording_model.dart';
import '../models/response_model.dart';
import '../my_const.dart';

class ApiService {
  // Helper to get Firebase Auth token
  static Future<String?> _getAuthToken() async {
    return await FirebaseAuth.instance.currentUser?.getIdToken();
  }

  // Helper for creating authenticated headers
  static Future<Map<String, String>> _getHeaders() async {
    final token = await _getAuthToken();
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  // Send user data (unchanged)
  static Future<ResponseModel> sendUserData({
    String? email,
    String? userId,
    String? displayName,
    String? photoURL,
  }) async {
    String? token = await _getAuthToken();
    // AppUser tmpUser = AppUser();
    // tmpUser.email = email;
    // tmpUser.userId = userId;
    // tmpUser.displayName = displayName;
    // tmpUser.photoURL = photoURL;
    final response = await http.post(
      Uri.parse('$baseUrl/user/create'),
      headers: await _getHeaders(),
      body: jsonEncode({
        // 'user':tmpUser,
        'userId': userId,
        'email': email,
        'displayName': displayName,
        'photoURL': photoURL,
        'token': token,
      }),
    );
    return ResponseModel.fromJson(jsonDecode(response.body));
  }

  static Future<List<Recording>> getUserRecordings() async {
    final response = await http.post(
      Uri.parse('$baseUrl/recordings/get'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Recording.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load recordings: ${response.body}');
    }
  }

  static Future<Recording> addRecording(Recording recording) async {
    final response = await http.post(
      Uri.parse('$baseUrl/recordings/create'),
      headers: await _getHeaders(),
      body: jsonEncode(recording.toJson()),
    );

    if (response.statusCode == 201) {
      return Recording.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to save recording: ${response.body}');
    }
  }

  static Future<void> deleteRecording(String fileName) async {
    final response = await http.post(
      Uri.parse('$baseUrl/recordings/delete'),
      headers: await _getHeaders(),
      body: jsonEncode({'fileName': fileName}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete recording: ${response.body}');
    }
  }

  static Future<void> deleteAllUserRecordings() async {
    final response = await http.post(
      Uri.parse('$baseUrl/recordings/delete_all'),
      headers: await _getHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete all recordings: ${response.body}');
    }
  }

  // static Future<void> updateRecording(String fileName, Map<String, dynamic> updates) async {
  //   final response = await http.post(
  //     Uri.parse('$baseUrl/recordings/update'),
  //     headers: await _getHeaders(),
  //     body: jsonEncode({
  //       'fileName': fileName,
  //       ...updates,
  //     }),
  //   );
  //
  //   if (response.statusCode != 200) {
  //     throw Exception('Failed to update recording: ${response.body}');
  //   }
  // }

  static Future<void> updateRecording(String oldFileName, String newFileName) async {
    final response = await http.post(
      Uri.parse('$baseUrl/recordings/update'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'fileName': oldFileName,
        'newFileName': newFileName,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update recording: ${response.body}');
    }
  }

  static Future<Recording?> getRecordingByEmailAndFileName(String fileName) async {
    final response = await http.post(
      Uri.parse('$baseUrl/recordings/get_one'),
      headers: await _getHeaders(),
      body: jsonEncode({
        "fileName": fileName,
      }),
    );

    if (response.statusCode == 200) {
      return Recording.fromJson(jsonDecode(response.body));
    } else if (response.statusCode == 404) {
      return null; // recording not found
    } else {
      throw Exception('Failed to load recording: ${response.body}');
    }
  }
}
