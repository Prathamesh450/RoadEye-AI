// lib/services/violation_service.dart
// FIXED VERSION - Proper error handling and network debugging

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/violation_model.dart';
import '../config/api_config.dart';
class ViolationService {
  // ⚠️ IMPORTANT: Update this with YOUR computer's IP address
  // Find your IP: Windows (ipconfig) / Mac (ifconfig) / Linux (ip addr)
  static final String baseUrl = ApiConfig.baseUrl;

  // Timeout duration
  static const Duration timeout = Duration(seconds: 60);

  /// Fetch all violations from backend with detailed logging
  static Future<List<Violation>> getViolations() async {
    print('\n🔍 === FETCHING VIOLATIONS DEBUG ===');
    print('📡 Base URL: $baseUrl');
    print('🌐 Full URL: $baseUrl/get-violations');

    try {
      final uri = Uri.parse("$baseUrl/get-violations");
      print('✅ URI parsed successfully: $uri');

      print('⏳ Sending HTTP GET request...');
      final response = await http
          .get(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          )
          .timeout(
            timeout,
            onTimeout: () {
              print('⏰ REQUEST TIMEOUT after ${timeout.inSeconds} seconds');
              throw Exception(
                'Connection timeout - Backend not reachable at $baseUrl',
              );
            },
          );

      print('📥 Response received!');
      print('📊 Status Code: ${response.statusCode}');
      print('📝 Response Headers: ${response.headers}');
      print('📄 Response Body Length: ${response.body.length} bytes');

      if (response.statusCode == 200) {
        print('✅ HTTP 200 OK - Parsing JSON...');

        try {
          final Map<String, dynamic> body = json.decode(response.body);
          print('✅ JSON decoded successfully');
          print('📦 Response structure: ${body.keys.toList()}');
          print('📊 Status: ${body['status']}');

          if (body['status'] == 'success') {
            final List<dynamic> items = body['violations'] ?? [];
            print('📋 Violations array length: ${items.length}');

            if (items.isEmpty) {
              print('⚠️ No violations in database');
              print(
                '💡 TIP: Process a video with HMV in restricted zone to create violations',
              );
              return [];
            }

            // Print first violation as sample
            if (items.isNotEmpty) {
              print('📝 Sample violation (first item):');
              print(json.encode(items[0]));
            }

            final violations = items.map((e) {
              final m = Map<String, dynamic>.from(e);
              return Violation.fromJson(m);
            }).toList();

            print('✅ Successfully parsed ${violations.length} violations');
            print('=== DEBUG END ===\n');

            return violations;
          } else {
            print('❌ Backend returned error status');
            print('📄 Full response: ${response.body}');
            throw Exception(
              'Backend error: ${body['message'] ?? 'Unknown error'}',
            );
          }
        } catch (e) {
          print('❌ JSON parsing error: $e');
          print('📄 Raw response: ${response.body.substring(0, 200)}...');
          throw Exception('Invalid JSON response from server');
        }
      } else if (response.statusCode == 404) {
        print('❌ HTTP 404 - Endpoint not found');
        print('🔍 Check if backend is running: curl $baseUrl');
        print('🔍 Check if /get-violations endpoint exists');
        throw Exception('Endpoint not found (404) - Is backend running?');
      } else {
        print('❌ HTTP Error: ${response.statusCode}');
        print('📄 Response body: ${response.body}');
        throw Exception('Server error: ${response.statusCode}');
      }
    } on http.ClientException catch (e) {
      print('❌ CLIENT EXCEPTION: $e');
      print('');
      print('🔧 TROUBLESHOOTING STEPS:');
      print('1. Check backend is running: python app.py');
      print('2. Check IP address is correct: $baseUrl');
      print('3. Check phone and computer on same WiFi');
      print('4. Try in browser: $baseUrl/get-violations');
      print('5. Check firewall settings');
      print('');
      throw Exception('Cannot connect to backend - Check connection');
    } catch (e) {
      print('❌ UNEXPECTED ERROR: $e');
      print('Error Type: ${e.runtimeType}');
      rethrow;
    }
  }

  /// Get violations count
  static Future<int> getViolationsCount() async {
    try {
      final violations = await getViolations();
      return violations.length;
    } catch (e) {
      print('⚠️ Error getting violations count: $e');
      return 0; // Return 0 instead of throwing error
    }
  }

  /// Get recent violations (last N items)
  static Future<List<Violation>> getRecentViolations(int limit) async {
    try {
      final violations = await getViolations();
      return violations.take(limit).toList();
    } catch (e) {
      print('⚠️ Error getting recent violations: $e');
      return [];
    }
  }

  /// Filter violations by zone
  static Future<List<Violation>> getViolationsByZone(String zoneName) async {
    try {
      final violations = await getViolations();
      return violations
          .where(
            (v) => v.zoneName.toLowerCase().contains(zoneName.toLowerCase()),
          )
          .toList();
    } catch (e) {
      print('⚠️ Error filtering by zone: $e');
      return [];
    }
  }

  /// Filter violations by city
  static Future<List<Violation>> getViolationsByCity(String city) async {
    try {
      final violations = await getViolations();
      return violations
          .where((v) => v.city.toLowerCase().contains(city.toLowerCase()))
          .toList();
    } catch (e) {
      print('⚠️ Error filtering by city: $e');
      return [];
    }
  }

  /// Filter violations by date range
  static Future<List<Violation>> getViolationsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final violations = await getViolations();
      return violations.where((v) {
        try {
          final violationDate = DateTime.parse(v.timestamp);
          return violationDate.isAfter(startDate) &&
              violationDate.isBefore(endDate);
        } catch (e) {
          return false;
        }
      }).toList();
    } catch (e) {
      print('⚠️ Error filtering by date: $e');
      return [];
    }
  }

  /// Get violations statistics
  static Future<Map<String, dynamic>> getViolationStats() async {
    try {
      final violations = await getViolations();

      // Count by city
      Map<String, int> cityCount = {};
      for (var v in violations) {
        cityCount[v.city] = (cityCount[v.city] ?? 0) + 1;
      }

      // Count by zone
      Map<String, int> zoneCount = {};
      for (var v in violations) {
        zoneCount[v.zoneName] = (zoneCount[v.zoneName] ?? 0) + 1;
      }

      // Get today's violations
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);
      final todayViolations = violations.where((v) {
        try {
          final violationDate = DateTime.parse(v.timestamp);
          return violationDate.isAfter(todayStart);
        } catch (e) {
          return false;
        }
      }).length;

      return {
        'total': violations.length,
        'today': todayViolations,
        'byCity': cityCount,
        'byZone': zoneCount,
      };
    } catch (e) {
      print('⚠️ Error getting stats: $e');
      return {'total': 0, 'today': 0, 'byCity': {}, 'byZone': {}};
    }
  }

  /// Test backend connection
  static Future<bool> testConnection() async {
    print('\n🔌 Testing backend connection...');
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 5));

      print('✅ Backend reachable: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Backend not reachable: $e');
      return false;
    }
  }
}
