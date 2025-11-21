import 'dart:async';
import 'notification_service.dart';

class WebhookListener {
  static Timer? _pollingTimer;
  static bool _isListening = false;

  // ⚠️ MOCK API - Poll for new violations
  // In production, use WebSocket or Firebase Cloud Messaging
  static void startListening({
    Duration interval = const Duration(seconds: 30),
    required Function(Map<String, dynamic>) onViolation,
  }) {
    if (_isListening) return;
    _isListening = true;

    _pollingTimer = Timer.periodic(interval, (timer) async {
      await _checkForNewViolations(onViolation);
    });
  }

  static Future<void> _checkForNewViolations(
    Function(Map<String, dynamic>) onViolation,
  ) async {
    try {
      // TODO: Replace with your actual API endpoint
      /*
      final response = await http.get(
        Uri.parse('https://your-api.com/violations/latest'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['has_new_violations']) {
          for (var violation in data['violations']) {
            onViolation(violation);
            
            // Trigger notification
            await NotificationService.showViolationNotification(
              vehicleNumber: violation['vehicle_number'],
              vehicleType: violation['vehicle_type'],
              location: violation['location'],
            );
          }
        }
      }
      */

      // MOCK: Simulate random violation (for testing)
      if (DateTime.now().second % 60 == 0) {
        final mockViolation = {
          'vehicle_number': 'MH12AB${DateTime.now().millisecond}',
          'vehicle_type': 'HMV',
          'location': 'Test Zone',
          'confidence': 0.95,
        };
        
        onViolation(mockViolation);
        
        await NotificationService.showViolationNotification(
          vehicleNumber: mockViolation['vehicle_number'],
          vehicleType: mockViolation['vehicle_type'],
          location: mockViolation['location'],
        );
      }
    } catch (e) {
      print('Error checking violations: $e');
    }
  }

  static void stopListening() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _isListening = false;
  }
}