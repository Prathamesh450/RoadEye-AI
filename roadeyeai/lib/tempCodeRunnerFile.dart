// lib/main.dart

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/otp_verification_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'models/user_model.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'firebase_options.dart';
import 'utils/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Initialize Firebase only if not already initialized
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  // Initialize notification service
  await NotificationService.initialize();
  await NotificationService.requestPermissions();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => UserModel(),
      child: Consumer<UserModel>(
        builder: (context, userModel, child) {
          return MaterialApp(
            title: 'RoadEye AI',
            debugShowCheckedModeBanner: false,

            // Dark mode tied to UserModel.darkMode
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: userModel.darkMode ? ThemeMode.dark : ThemeMode.light,

            // Route management
            initialRoute: '/',
            routes: {
              '/': (context) => const AuthWrapper(),
              '/login': (context) => const LoginScreen(),
              '/home': (context) => const HomeScreen(),
            },

            // ✅ Handle routes with required parameters
            onGenerateRoute: (settings) {
              // Handle OTP Verification Screen (requires email parameter)
              if (settings.name == '/otp-verification') {
                final args = settings.arguments as Map<String, dynamic>?;
                return MaterialPageRoute(
                  builder: (context) => OTPVerificationScreen(
                    email: args?['email'] ?? '',
                    idToken: args?['idToken'],
                  ),
                );
              }
              return null;
            },
          );
        },
      ),
    );
  }
}

/// Authentication wrapper to check login status on app start
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: AuthService.isLoggedIn(),
      builder: (context, snapshot) {
        // Show loading while checking auth status
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF4361EE),
                    Color(0xFF3A0CA3),
                  ],
                ),
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo
                    Icon(
                      Icons.visibility,
                      size: 80,
                      color: Colors.white,
                    ),
                    SizedBox(height: 24),
                    // App name
                    Text(
                      'RoadEye AI',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 32),
                    // Loading indicator
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // If user is logged in, show home screen and update UserModel
        if (snapshot.hasData && snapshot.data == true) {
          // Auto-login: Get stored email and update user model
          AuthService.getStoredEmail().then((email) {
            if (email != null) {
              Provider.of<UserModel>(context, listen: false).login(email);
            }
          });

          return const HomeScreen();
        }

        // If not logged in, show login screen
        return const LoginScreen();
      },
    );
  }
}
