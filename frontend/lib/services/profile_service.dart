// ignore_for_file: unused_element, avoid_print, prefer_final_locals, require_trailing_commas, unused_import

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/environment.dart';
import 'api_service.dart';
import 'auth_service.dart';

class ProfileService {
  static const String _userIdKey = 'current_user_id';

  static Future<String> _getUserId() async {
try {
      final auth = AuthService();
      final user = await auth.getCurrentUser();
      final id = user?.id;
      if (id != null && id.isNotEmpty) {
        return id;
      }
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString(_userIdKey);
    if (userId == null || userId.isEmpty) {
      throw Exception('No user ID found. Please log in first.');
    }
    return userId;
  }

  static Future<String?> _getAuthToken() async {
    final authService = AuthService();
    return authService.accessToken;
  }

  static Future<Map<String, String>> _getAuthHeaders() async {
    final token = await _getAuthToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<Map<String, dynamic>> getUserProfile() async {
    try {
      final userId = await _getUserId();
      final response = await http.get(
        Uri.parse('${Environment.apiBaseUrl}/profile/$userId'),
        headers: await ApiService.getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load profile: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching profile: $e');
      return await _getLocalProfile();
    }
  }

  static Future<Map<String, dynamic>> saveUserProfile(Map<String, dynamic> profile) async {
    try {
      final userId = await _getUserId();
      
      final existingProfile = await _checkProfileExists(userId);
      
      final response = await (existingProfile
          ? http.put(
              Uri.parse('${Environment.apiBaseUrl}/profile/$userId'),
              headers: await ApiService.getAuthHeaders(),
              body: json.encode(profile),
            )
          : http.post(
              Uri.parse('${Environment.apiBaseUrl}/profile/'),
              headers: await ApiService.getAuthHeaders(),
              body: json.encode({...profile, 'user_id': userId}),
            ));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final savedProfile = json.decode(response.body);
        await _saveLocalProfile(savedProfile);
        return savedProfile;
      } else {
        throw Exception('Failed to save profile: ${response.statusCode}');
      }
    } catch (e) {
      print('Error saving profile: $e');
      await _saveLocalProfile(profile);
      return profile;
    }
  }

  static Future<bool> _checkProfileExists(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('${Environment.apiBaseUrl}/profile/$userId'),
        headers: await ApiService.getAuthHeaders(),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<Map<String, dynamic>> uploadProfilePicture(List<int> imageBytes, String fileName) async {
    try {
      final userId = await _getUserId();
      
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${Environment.apiBaseUrl}/profile/$userId/upload-picture'),
      );
      
// Infer content type from filename extension
      final lower = fileName.toLowerCase();
      MediaType ct;
      if (lower.endsWith('.png')) {
        ct = MediaType('image', 'png');
      } else if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
        ct = MediaType('image', 'jpeg');
      } else if (lower.endsWith('.gif')) {
        ct = MediaType('image', 'gif');
      } else if (lower.endsWith('.webp')) {
        ct = MediaType('image', 'webp');
      } else {
        ct = MediaType('image', 'jpeg');
      }
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        imageBytes,
        filename: fileName,
        contentType: ct,
      ));
      final headers = await ApiService.getAuthHeaders();
      headers.remove('Content-Type');
      request.headers.addAll(headers);

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        // Try to parse as JSON, but handle if it's not JSON
        try {
          return json.decode(responseBody);
        } catch (e) {
          // Response might be image data, not JSON
          // Return a success response with the raw URL if available
          print('Response appears to be image data, not JSON: $responseBody');
          return {
            'success': true,
            'url': 'Image uploaded successfully',
            'message': 'Profile picture updated'
          };
        }
      } else {
        throw Exception('Failed to upload picture: ${response.statusCode}');
      }
    } catch (e) {
      print('Error uploading picture: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> _getLocalProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final profileJson = prefs.getString('user_profile');
    
    if (profileJson != null) {
      return json.decode(profileJson);
    } else {
      return {
        'user_id': '',
        'first_name': '',
        'last_name': '',
        'email': '',
        'phone_number': '',
        'profile_picture': '',
        'bio': '',
        'job_title': '',
        'company': '',
        'location': '',
        'website': '',
        'date_of_birth': null,
      };
    }
  }

  static Future<void> _saveLocalProfile(Map<String, dynamic> profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_profile', json.encode(profile));
  }
}
