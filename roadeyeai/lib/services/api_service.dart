import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import '../models/violation.dart';
import '../config/api_config.dart';
class ApiService {
  // ✅ BACKEND URL - Update this with your machine's IP
  // IMPORTANT: Use the SAME IP everywhere!
  static final String baseUrl = ApiConfig.baseUrl;

  // Connection timeout - INCREASED for better reliability
  static const Duration timeout = Duration(seconds: 30);

  /// Test backend connection
  static Future<bool> testConnection() async {
    try {
      print('🔍 Testing connection to: $baseUrl');
      final response = await http.get(Uri.parse('$baseUrl/')).timeout(timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ Backend connected: ${data['message']}');
        print('✅ Firebase: ${data['firebase_connected']}');
        print('✅ AI: ${data['ai_enabled']}');
        print('✅ Zones cached: ${data['zones_cached']}');
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Backend connection failed: $e');
      return false;
    }
  }

  /// Handle API errors consistently
  static Map<String, dynamic> _handleError(dynamic error, String operation) {
    String message;

    if (error is SocketException) {
      message =
          'Cannot connect to server.\n'
          'Please check:\n'
          '1. Backend is running (python app.py)\n'
          '2. IP address is correct: $baseUrl\n'
          '3. Phone and PC on same network';
    } else if (error is http.ClientException) {
      message = 'Network error: ${error.message}';
    } else if (error.toString().contains('TimeoutException')) {
      message = 'Connection timeout.\nServer may be busy or unreachable.';
    } else {
      message = 'Error during $operation: ${error.toString()}';
    }

    print('❌ $operation failed: $message');

    return {'success': false, 'error': message};
  }

  // ====================================================================
  // 🔐 AUTHENTICATION APIs
  // ====================================================================

  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    try {
      print('🔐 Attempting login: $email');

      final response = await http
          .post(
            Uri.parse('$baseUrl/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(timeout);

      print('📡 Login response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ Login successful');
        return {
          'success': true,
          'email': data['email'],
          'uid': data['uid'],
          'idToken': data['idToken'],
        };
      } else {
        final error = jsonDecode(response.body);
        return {'success': false, 'error': error['error'] ?? 'Login failed'};
      }
    } catch (e) {
      return _handleError(e, 'Login');
    }
  }

  static Future<Map<String, dynamic>> signup(
    String email,
    String password,
  ) async {
    try {
      print('📝 Attempting signup: $email');

      final response = await http
          .post(
            Uri.parse('$baseUrl/signup'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(timeout);

      print('📡 Signup response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ Signup successful');
        return {
          'success': true,
          'email': data['email'],
          'uid': data['uid'],
          'idToken': data['idToken'],
        };
      } else {
        final error = jsonDecode(response.body);
        return {'success': false, 'error': error['error'] ?? 'Signup failed'};
      }
    } catch (e) {
      return _handleError(e, 'Signup');
    }
  }

  // ====================================================================
  // 🗺️ RESTRICTED ZONES APIs
  // ====================================================================

  static Future<Map<String, dynamic>> getRestrictedZones() async {
    try {
      print('🗺️ Fetching restricted zones from: $baseUrl/get-zones');

      final response = await http
          .get(
            Uri.parse('$baseUrl/get-zones'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(timeout);

      print('📡 Zones response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final zones = data['zones'] ?? data['data'] ?? [];
        print('✅ Fetched ${zones.length} zones');

        // Debug: Print first zone if available
        if (zones.isNotEmpty) {
          print(
            '📍 Sample zone: ${zones[0]['zone_name']} at (${zones[0]['center']['lat']}, ${zones[0]['center']['lon']})',
          );
        }

        return {'success': true, 'data': zones};
      } else {
        print('❌ Failed to fetch zones: ${response.statusCode}');
        print('Response body: ${response.body}');
        return {
          'success': false,
          'message': 'Failed to fetch zones',
          'data': [],
        };
      }
    } catch (e) {
      final error = _handleError(e, 'Get Zones');
      return {...error, 'data': []};
    }
  }

  static Future<Map<String, dynamic>> createRestrictedZone({
    required String zoneName,
    required String city,
    required double latitude,
    required double longitude,
    required double radiusMeters,
    String activeHours = '08:00–11:00, 17:00–21:00',
    String inactiveHours = '21:00–08:00',
  }) async {
    try {
      print('➕ Creating zone: $zoneName at ($latitude, $longitude)');

      final response = await http
          .post(
            Uri.parse('$baseUrl/add-zone'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'zone_name': zoneName,
              'city': city,
              'center': {'lat': latitude, 'lon': longitude},
              'radius_meters': radiusMeters,
              'active_hours': activeHours,
              'inactive_hours': inactiveHours,
            }),
          )
          .timeout(timeout);

      print('📡 Create zone response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ Zone created successfully: ${data['id']}');
        return {
          'success': true,
          'message': data['message'] ?? 'Zone added successfully',
          'data': data['data'],
        };
      } else {
        print('❌ Failed to create zone: ${response.body}');
        return {'success': false, 'message': 'Failed to create zone'};
      }
    } catch (e) {
      return _handleError(e, 'Create Zone');
    }
  }

  static Future<Map<String, dynamic>> deleteRestrictedZone(String id) async {
    try {
      print('🗑️ Deleting zone: $id');

      final response = await http
          .delete(Uri.parse('$baseUrl/delete-zone/$id'))
          .timeout(timeout);

      print('📡 Delete zone response: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('✅ Zone deleted successfully');
        return {'success': true, 'message': 'Zone deleted successfully'};
      } else {
        return {'success': false, 'message': 'Failed to delete zone'};
      }
    } catch (e) {
      return _handleError(e, 'Delete Zone');
    }
  }

  // ====================================================================
  // 🚨 VIOLATIONS APIs
  // ====================================================================

  static Future<List<Violation>> fetchViolations() async {
    try {
      print('🚨 Fetching violations from: $baseUrl/get-violations');

      final response = await http
          .get(
            Uri.parse('$baseUrl/get-violations'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(timeout);

      print('📡 Violations response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = json.decode(response.body);
        final List<dynamic> items = body['violations'] ?? [];

        final violations = items.map((e) {
          final m = Map<String, dynamic>.from(e);
          return Violation.fromJson(m);
        }).toList();

        print('✅ Fetched ${violations.length} violations');

        // Debug: Print first violation if available
        if (violations.isNotEmpty) {
          print(
            '🚨 Sample violation: ${violations[0].numberPlate} in ${violations[0].zoneName}',
          );
        }

        return violations;
      } else {
        print('❌ Failed to fetch violations: ${response.statusCode}');
        print('Response body: ${response.body}');
        throw Exception('Failed to load violations (${response.statusCode})');
      }
    } catch (e) {
      print('❌ Error fetching violations: $e');
      throw Exception('Error loading violations: $e');
    }
  }

  static Future<Map<String, dynamic>> vehicleDetected({
    required String vehicleNumber,
    required String vehicleType,
    required double latitude,
    required double longitude,
    required String cameraId,
    String? accuracyPercentage,
    String? videoPath,
  }) async {
    try {
      print('🚗 Reporting vehicle: $vehicleNumber ($vehicleType)');
      print('📍 Location: ($latitude, $longitude)');

      final response = await http
          .post(
            Uri.parse('$baseUrl/vehicle-detected'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'vehicle_number': vehicleNumber,
              'vehicle_type': vehicleType,
              'zone_location': {'lat': latitude, 'lon': longitude},
              'camera_id': cameraId,
              'accuracy_percentage': accuracyPercentage ?? 'unknown',
              'timestamp': DateTime.now().toUtc().toIso8601String(),
              'video_path': videoPath,
            }),
          )
          .timeout(timeout);

      print('📡 Vehicle detection response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ Vehicle reported: ${data['status']}');
        if (data['status'] == 'violation') {
          print('🚨 Violation created: ${data['violation_id']}');
        }
        return data;
      } else {
        print('❌ Failed to report vehicle: ${response.body}');
        return {
          'success': false,
          'message': 'Failed to report vehicle detection',
        };
      }
    } catch (e) {
      return _handleError(e, 'Vehicle Detection');
    }
  }

  // ====================================================================
  // 📹 VIDEO PROCESSING (Helper for multipart uploads)
  // ====================================================================

  static Future<http.StreamedResponse> uploadVideo({
    required File videoFile,
    required double cameraLat,
    required double cameraLon,
    required String cameraId,
  }) async {
    try {
      print('📤 Uploading video: ${videoFile.path.split('/').last}');
      print('📍 Camera location: ($cameraLat, $cameraLon)');

      final uri = Uri.parse('$baseUrl/process-video');
      final request = http.MultipartRequest('POST', uri);

      // Add video file
      request.files.add(
        await http.MultipartFile.fromPath('video', videoFile.path),
      );

      // Add camera location
      request.fields['camera_lat'] = cameraLat.toString();
      request.fields['camera_lon'] = cameraLon.toString();
      request.fields['camera_id'] = cameraId;

      print('📡 Sending request to: $uri');
      final streamedResponse = await request.send().timeout(
        const Duration(minutes: 10),
      );

      print('📡 Upload response: ${streamedResponse.statusCode}');
      return streamedResponse;
    } catch (e) {
      print('❌ Video upload failed: $e');
      rethrow;
    }
  }

  // ====================================================================
  // 🔍 UTILITY METHODS
  // ====================================================================

  /// Get backend info
  static Future<Map<String, dynamic>> getBackendInfo() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/')).timeout(timeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {};
    } catch (e) {
      print('❌ Failed to get backend info: $e');
      return {};
    }
  }

  /// Check AI status
  static Future<Map<String, dynamic>> getAIStatus() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/ai-status'))
          .timeout(timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('🤖 AI Status: ${data['ai_available']}');
        return data;
      }
      return {'ai_available': false};
    } catch (e) {
      print('❌ Failed to check AI status: $e');
      return {'ai_available': false};
    }
  }
}
