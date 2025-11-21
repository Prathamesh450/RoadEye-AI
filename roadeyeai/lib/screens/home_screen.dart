import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/violation_service.dart';
import '../widgets/feature_card.dart';
import '../utils/app_colors.dart';
import 'video_processing_screen.dart';  // NEW: AI Processing Screen
import 'violations_screen.dart';
import 'settings_screen.dart';
import 'restricted_zones_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _violationCount = 0;
  bool _isLoadingViolations = false;

  @override
  void initState() {
    super.initState();
    _loadViolationCount();
  }

  Future<void> _loadViolationCount() async {
    setState(() => _isLoadingViolations = true);
    try {
      final count = await ViolationService.getViolationsCount();
      if (mounted) {
        setState(() {
          _violationCount = count;
          _isLoadingViolations = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingViolations = false);
      }
      debugPrint('Error loading violation count: $e');
    }
  }

  void _handleLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await AuthService.logout();
      if (context.mounted) {
        Provider.of<UserModel>(context, listen: false).logout();
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/login',
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userModel = Provider.of<UserModel>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('RoadEye AI'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          // Refresh Button
          IconButton(
            icon: _isLoadingViolations
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.refresh),
            tooltip: 'Refresh Violations',
            onPressed: _isLoadingViolations ? null : _loadViolationCount,
          ),
          // Logout Button
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => _handleLogout(context),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primary.withOpacity(0.05),
              isDark ? AppColors.darkBackground : Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _loadViolationCount,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 👤 Welcome Card
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: isSmallScreen ? 25 : 30,
                            backgroundColor: AppColors.primary.withOpacity(0.1),
                            child: Icon(
                              Icons.person,
                              color: AppColors.primary,
                              size: isSmallScreen ? 25 : 30,
                            ),
                          ),
                          SizedBox(width: isSmallScreen ? 12 : 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Welcome back!',
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 14 : 16,
                                    color: isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  userModel.email,
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 16 : 18,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? AppColors.darkTextPrimary
                                        : AppColors.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 16 : 24),

                  // 🧭 Feature Section
                  Text(
                    'Features',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 18 : 20,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 12 : 16),

                  // 🧩 Feature Grid
                  LayoutBuilder(
                    builder: (context, constraints) {
                      int crossAxisCount = 2;
                      double childAspectRatio = 1.0;

                      if (size.width < 360) {
                        crossAxisCount = 1;
                        childAspectRatio = 2.5;
                      } else if (size.width < 600) {
                        crossAxisCount = 2;
                        childAspectRatio = 0.85;
                      } else {
                        crossAxisCount = 3;
                        childAspectRatio = 1.0;
                      }

                      return GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: isSmallScreen ? 12 : 16,
                        mainAxisSpacing: isSmallScreen ? 12 : 16,
                        childAspectRatio: childAspectRatio,
                        children: [
                          // NEW: AI Video Processing (Primary Feature)
                          FeatureCard(
                            title: '🤖 AI Processing',
                            description: 'Process video with AI detection',
                            icon: Icons.auto_awesome,
                            iconColor: Colors.deepPurple,
                            onTap: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const VideoProcessingScreen(),
                                ),
                              );
                              if (result == true) {
                                _loadViolationCount();
                              }
                            },
                          ),
                          
                          // Violations
                          FeatureCard(
                            title: 'Violations',
                            description: 'View HMV violation records',
                            icon: Icons.warning_amber_rounded,
                            iconColor: AppColors.error,
                            notificationCount: _violationCount > 0 ? _violationCount : 0,
                            onTap: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const ViolationsScreen(),
                                ),
                              );
                              if (result == true) {
                                _loadViolationCount();
                              }
                            },
                          ),
                          
                          // Restricted Zones
                          FeatureCard(
                            title: 'Restricted Zones',
                            description: 'Manage restricted areas',
                            icon: Icons.location_on,
                            iconColor: AppColors.warning,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const RestrictedZonesScreen(),
                              ),
                            ),
                          ),
                          
                          // Settings
                          FeatureCard(
                            title: 'Settings',
                            description: 'App configuration & alerts',
                            icon: Icons.settings,
                            iconColor: AppColors.textSecondary,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SettingsScreen(),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}