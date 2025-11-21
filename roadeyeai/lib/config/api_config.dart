  // lib/config/api_config.dart

  class ApiConfig {
    // ================================
    // 🔧 BASE URL CONFIGURATION
    // ================================
    
    // ✅ FOR REAL DEVICE: Use your computer's IP address
    // Find it using: ipconfig (Windows) or ifconfig (Mac/Linux)
    static const String _realDeviceIP = '10.121.197.110';
    
    // ✅ FOR EMULATOR: Use special localhost address
    static const String _emulatorIP = '10.0.2.2';
    
    // ✅ Set this to true for real device, false for emulator
    static const int _port = 5000;
    static const bool _useRealDevice = true; // ← CHANGE THIS BASED ON YOUR DEVICE
    
    // Base URL (automatically switches based on _useRealDevice)
    static String get baseUrl => _useRealDevice 
        ? 'http://$_realDeviceIP:$_port'
        : 'http://$_emulatorIP:$_port';
    
    // ================================
    // 🔐 AUTHENTICATION ENDPOINTS
    // ================================
    
    static String get signup => '$baseUrl/signup';
    static String get login => '$baseUrl/login';
    static String get signupWithOtp => '$baseUrl/signup-with-otp';
    static String get sendOtp => '$baseUrl/send-otp';
    static String get verifyOtp => '$baseUrl/verify-otp';
    static String checkVerificationStatus(String email) => 
        '$baseUrl/check-verification-status/$email';
    
    // ================================
    // 🗺️ ZONE MANAGEMENT ENDPOINTS
    // ================================
    
    static String get addZone => '$baseUrl/add-zone';
    static String get getZones => '$baseUrl/get-zones';
    static String deleteZone(String zoneId) => '$baseUrl/delete-zone/$zoneId';
    
    // ================================
    // 🚨 VIOLATION ENDPOINTS
    // ================================
    
    static String get vehicleDetected => '$baseUrl/vehicle-detected';
    static String get getViolations => '$baseUrl/get-violations';
    static String getSessionViolations(String sessionId) => 
        '$baseUrl/get-session-violations/$sessionId';
    static String get testViolations => '$baseUrl/test-violations';
    
    // ================================
    // 🎥 VIDEO PROCESSING ENDPOINTS
    // ================================
    
    static String get uploadVideo => '$baseUrl/upload-video';
    static String get processVideo => '$baseUrl/process-video';
    static String get processCamera => '$baseUrl/process-camera';
    static String get processYoutube => '$baseUrl/process-youtube';
    static String sessionStatus(String sessionId) => 
        '$baseUrl/session-status/$sessionId';
    static String debugSession(String sessionId) => 
        '$baseUrl/debug-session/$sessionId';
    static String get testCameraConnection => '$baseUrl/test-camera-connection';
    
    // ================================
    // ⚙️ CONFIGURATION SETTINGS
    // ================================
    
    // HTTP Timeout Settings
    static const Duration timeout = Duration(seconds: 30);
    static const Duration connectionTimeout = Duration(seconds: 10);
    
    // Retry Settings
    static const int maxRetries = 3;
    static const Duration retryDelay = Duration(seconds: 2);
    
    // File Upload Settings
    static const int maxFileSize = 100 * 1024 * 1024; // 100 MB
    static const List<String> allowedVideoFormats = ['mp4', 'avi', 'mov', 'mkv'];
    
    // OTP Settings
    static const int otpLength = 6;
    static const int otpExpiryMinutes = 5;
    static const int otpResendCooldownSeconds = 60;
    static const int maxOtpAttempts = 3;
    
    // ================================
    // 🔧 HELPER METHODS
    // ================================
    
    /// Print current configuration (for debugging)
    static void printConfig() {
      print('\n' + '=' * 60);
      print('📋 API CONFIGURATION');
      print('=' * 60);
      print('🌐 Device Type: ${_useRealDevice ? "Real Device" : "Emulator"}');
      print('🔗 Base URL: $baseUrl');
      print('📱 Real Device IP: $_realDeviceIP');
      print('💻 Emulator IP: $_emulatorIP');
      print('⏱️ Timeout: ${timeout.inSeconds}s');
      print('=' * 60 + '\n');
    }
    
    /// Get configuration as Map (useful for debugging)
    static Map<String, dynamic> getConfigMap() {
      return {
        'baseUrl': baseUrl,
        'deviceType': _useRealDevice ? 'real_device' : 'emulator',
        'realDeviceIP': _realDeviceIP,
        'emulatorIP': _emulatorIP,
        'timeout': timeout.inSeconds,
        'endpoints': {
          'auth': {
            'signup': signup,
            'login': login,
            'signupWithOtp': signupWithOtp,
            'sendOtp': sendOtp,
            'verifyOtp': verifyOtp,
          },
          'zones': {
            'add': addZone,
            'get': getZones,
          },
          'violations': {
            'get': getViolations,
            'vehicleDetected': vehicleDetected,
          },
          'video': {
            'upload': uploadVideo,
            'process': processVideo,
            'processCamera': processCamera,
            'processYoutube': processYoutube,
          },
        },
      };
    }
  }