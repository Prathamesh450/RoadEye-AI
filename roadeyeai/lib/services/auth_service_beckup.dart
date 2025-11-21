// lib/services/auth_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../config/api_config.dart'; // ✅ IMPORTANT: This imports your centralized config

class AuthService {
  // ✅ NO hardcoded baseUrl here anymore!
  // All URLs come from ApiConfig which you can change in one place
  
  static const String loginAttemptsKey = 'login_attempts';
  static const String accountLockedKey = 'account_locked';
  static const String lockedUntilKey = 'locked_until';
  static const int maxAttempts = 3;
  static const int lockDurationMinutes = 15;

  // Firebase Auth instance
  static final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  
  // ✅ Google Sign-In configuration
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    clientId: '756502130603-gptc3nq9bu2q49jkl12hrj3te4veb280.apps.googleusercontent.com',
  );

  // ========================================
  // 🆕 REGISTER WITH OTP
  // ========================================
  static Future<Map<String, dynamic>> registerWithOTP(
    String email,
    String password,
  ) async {
    try {
      if (!isValidEmail(email)) {
        return {'success': false, 'message': 'Invalid email format'};
      }

      if (password.length < 6) {
        return {'success': false, 'message': 'Password must be at least 6 characters'};
      }

      print('🚀 Attempting registration with OTP for: $email');
      print('📡 Using URL: ${ApiConfig.signupWithOtp}'); // ✅ Debug log

      // ✅ Use ApiConfig instead of hardcoded URL
      final url = Uri.parse(ApiConfig.signupWithOtp);
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        print('✅ Registration successful - OTP sent');
        return {
          'success': true,
          'message': data['message'] ?? 'Account created! OTP sent to your email.',
          'email': email,
          'uid': data['uid'],
          'idToken': data['idToken'],
          'requires_verification': data['requires_verification'] ?? true,
        };
      } else {
        print('❌ Registration failed: ${data['error']}');
        return {
          'success': false,
          'message': data['error'] ?? 'Registration failed',
        };
      }
    } catch (e) {
      print('❌ Registration error: $e');
      return {
        'success': false,
        'message': 'Connection error. Check if backend is running at ${ApiConfig.baseUrl}',
      };
    }
  }

  // ========================================
  // ✅ GOOGLE SIGN-IN
  // ========================================
  static Future<Map<String, dynamic>> signInWithGoogle() async {
    try {
      print('🔵 Starting Google Sign-In...');
      
      await _googleSignIn.signOut();
      await _firebaseAuth.signOut();
      
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        print('❌ User cancelled Google Sign-In');
        return {'success': false, 'message': 'Sign-in cancelled'};
      }

      print('✅ Google user selected: ${googleUser.email}');

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        print('❌ Missing authentication tokens');
        return {'success': false, 'message': 'Authentication failed - missing tokens'};
      }

      print('✅ Got authentication tokens');

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      print('✅ Firebase credential created');

      final UserCredential userCredential = 
          await _firebaseAuth.signInWithCredential(credential);

      if (userCredential.user == null) {
        print('❌ Firebase sign-in failed - no user');
        return {'success': false, 'message': 'Firebase authentication failed'};
      }

      final user = userCredential.user!;
      print('✅ Firebase sign-in successful: ${user.email}');

      await saveLoginState(user.email ?? '');
      await resetLoginAttempts();

      return {
        'success': true,
        'message': 'Google Sign-In successful',
        'email': user.email,
        'uid': user.uid,
        'displayName': user.displayName,
        'photoURL': user.photoURL,
      };

    } on FirebaseAuthException catch (e) {
      print('❌ Firebase Auth error: ${e.code} - ${e.message}');
      return {'success': false, 'message': 'Firebase error: ${e.message}'};
    } catch (e) {
      print('❌ Google Sign-In error: $e');
      return {'success': false, 'message': 'Google Sign-In failed: ${e.toString()}'};
    }
  }

  // ========================================
  // ✅ FORGOT PASSWORD
  // ========================================
  static Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      print('📧 Sending password reset request for: $email');

      if (!isValidEmail(email)) {
        return {'success': false, 'message': 'Please enter a valid email address'};
      }

      await _firebaseAuth.sendPasswordResetEmail(email: email);

      print('✅ Password reset email sent successfully');

      return {
        'success': true,
        'message': 'Password reset link sent! Check your email.',
      };

    } on FirebaseAuthException catch (e) {
      print('❌ Password reset error: ${e.code}');
      
      String errorMessage = 'Failed to send reset email';
      
      if (e.code == 'user-not-found') {
        errorMessage = 'No account found with this email';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'Invalid email address';
      } else if (e.code == 'too-many-requests') {
        errorMessage = 'Too many attempts. Please try again later.';
      }

      return {'success': false, 'message': errorMessage};
    } catch (e) {
      print('❌ Unexpected error: $e');
      return {'success': false, 'message': 'An error occurred. Please try again.'};
    }
  }

  // ========================================
  // REGULAR LOGIN
  // ========================================
  static Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      if (!isValidEmail(email)) {
        return {'success': false, 'message': 'Invalid email format'};
      }

      if (password.isEmpty) {
        return {'success': false, 'message': 'Password cannot be empty'};
      }

      print('🔐 Attempting login for: $email');
      print('📡 Using URL: ${ApiConfig.login}'); // ✅ Debug log

      // ✅ Use ApiConfig instead of hardcoded URL
      final url = Uri.parse(ApiConfig.login);
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        print('✅ Login successful');
        await saveLoginState(email);
        await resetLoginAttempts();
        
        return {
          'success': true,
          'message': data['message'] ?? 'Login successful',
          'email': email,
          'uid': data['uid'],
          'idToken': data['idToken'],
        };
      } else {
        print('❌ Login failed: ${data['error']}');
        return {'success': false, 'message': data['error'] ?? 'Login failed'};
      }
    } catch (e) {
      print('❌ Login error: $e');
      return {
        'success': false,
        'message': 'Connection error. Check if backend is running at ${ApiConfig.baseUrl}',
      };
    }
  }

  // ========================================
  // OTP VERIFICATION
  // ========================================
  static Future<Map<String, dynamic>> sendOTP(String email) async {
    try {
      print('📧 Sending OTP to: $email');
      print('📡 Using URL: ${ApiConfig.sendOtp}'); // ✅ Debug log

      // ✅ Use ApiConfig instead of hardcoded URL
      final url = Uri.parse(ApiConfig.sendOtp);
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        print('✅ OTP sent successfully');
        return {
          'success': true,
          'message': data['message'] ?? 'OTP sent successfully',
          'cooldown_seconds': data['cooldown_seconds'],
        };
      } else {
        print('❌ OTP send failed: ${data['error']}');
        return {
          'success': false,
          'message': data['error'] ?? 'Failed to send OTP',
          'cooldown': data['cooldown'] ?? false,
          'remaining_seconds': data['remaining_seconds'],
        };
      }
    } catch (e) {
      print('❌ Send OTP error: $e');
      return {
        'success': false,
        'message': 'Connection error. Check if backend is running at ${ApiConfig.baseUrl}',
      };
    }
  }

  static Future<Map<String, dynamic>> verifyOTP(String email, String otp) async {
    try {
      print('🔐 Verifying OTP for: $email');
      print('📡 Using URL: ${ApiConfig.verifyOtp}'); // ✅ Debug log

      // ✅ Use ApiConfig instead of hardcoded URL
      final url = Uri.parse(ApiConfig.verifyOtp);
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'otp': otp,
        }),
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        print('✅ OTP verified successfully');
        return {
          'success': true,
          'message': data['message'] ?? 'Email verified successfully!',
        };
      } else {
        print('❌ OTP verification failed: ${data['error']}');
        return {
          'success': false,
          'message': data['error'] ?? 'Invalid OTP',
          'expired': data['expired'] ?? false,
          'max_attempts_exceeded': data['max_attempts_exceeded'] ?? false,
        };
      }
    } catch (e) {
      print('❌ Verify OTP error: $e');
      return {'success': false, 'message': 'Connection error. Please try again.'};
    }
  }

  // ========================================
  // LOGIN STATE MANAGEMENT
  // ========================================
  static Future<void> saveLoginState(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
    await prefs.setString('userEmail', email);
    await prefs.setString('loginTime', DateTime.now().toIso8601String());
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isLoggedIn') ?? false;
  }

  static Future<String?> getStoredEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('userEmail');
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await _googleSignIn.signOut();
    await _firebaseAuth.signOut();
    print('✅ Logged out successfully');
  }

  // ========================================
  // LOGIN ATTEMPTS MANAGEMENT
  // ========================================
  static Future<int> incrementLoginAttempts() async {
    final prefs = await SharedPreferences.getInstance();
    int attempts = (prefs.getInt(loginAttemptsKey) ?? 0) + 1;
    await prefs.setInt(loginAttemptsKey, attempts);
    
    if (attempts >= maxAttempts) {
      await lockAccount();
    }
    
    return attempts;
  }

  static Future<int> getLoginAttempts() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(loginAttemptsKey) ?? 0;
  }

  static Future<void> resetLoginAttempts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(loginAttemptsKey);
    await prefs.remove(accountLockedKey);
    await prefs.remove(lockedUntilKey);
  }

  static Future<void> lockAccount() async {
    final prefs = await SharedPreferences.getInstance();
    final lockUntil = DateTime.now().add(Duration(minutes: lockDurationMinutes));
    await prefs.setBool(accountLockedKey, true);
    await prefs.setString(lockedUntilKey, lockUntil.toIso8601String());
  }

  static Future<bool> isAccountLocked() async {
    final prefs = await SharedPreferences.getInstance();
    final isLocked = prefs.getBool(accountLockedKey) ?? false;
    
    if (!isLocked) return false;
    
    final lockedUntilStr = prefs.getString(lockedUntilKey);
    if (lockedUntilStr == null) return false;
    
    final lockedUntil = DateTime.parse(lockedUntilStr);
    final now = DateTime.now();
    
    if (now.isAfter(lockedUntil)) {
      await resetLoginAttempts();
      return false;
    }
    
    return true;
  }

  // ========================================
  // VALIDATION
  // ========================================
  static bool isValidEmail(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }
}