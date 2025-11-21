
import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

class FeatureCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;
  final int notificationCount;

  const FeatureCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.iconColor,
    required this.onTap,
    this.notificationCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    // FIXED: Dark mode detection
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // FIXED: Responsive sizing
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 600;
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      // FIXED: Card color adapts to theme
      color: isDark ? AppColors.darkSurface : AppColors.surface,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: isSmallScreen ? 50 : 60,
                    height: isSmallScreen ? 50 : 60,
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      size: isSmallScreen ? 25 : 30,
                      color: iconColor,
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 12 : 16),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: isSmallScreen ? 16 : 18,
                      fontWeight: FontWeight.bold,
                      // FIXED: Text color adapts to theme
                      color: isDark 
                          ? AppColors.darkTextPrimary 
                          : AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 4 : 8),
                  Text(
                    description,
                    style: TextStyle(
                      // FIXED: Text color adapts to theme
                      color: isDark 
                          ? AppColors.darkTextSecondary 
                          : AppColors.textSecondary,
                      fontSize: isSmallScreen ? 12 : 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              if (notificationCount > 0)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.all(isSmallScreen ? 4 : 6),
                    decoration: const BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      notificationCount > 99 ? '99+' : notificationCount.toString(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isSmallScreen ? 10 : 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}