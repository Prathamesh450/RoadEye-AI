// Path: lib/utils/app_colors.dart

import 'package:flutter/material.dart';

class AppColors {
  // Modern Color Palette
  static const Color primary = Color(0xFF4361EE);
  static const Color secondary = Color(0xFF3A0CA3);
  static const Color accent = Color(0xFF4CC9F0);
  static const Color success = Color(0xFF4ADE80);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF06B6D4);
  
  // Neutral Colors - Light Theme
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textTertiary = Color(0xFF94A3B8);
  static const Color border = Color(0xFFE2E8F0);
  
  // ✅ CRITICAL FIX: Dark Theme Colors - WHITE TEXT for visibility
  static const Color darkBackground = Color(0xFF0F172A);
  static const Color darkSurface = Color(0xFF1E293B);
  static const Color darkTextPrimary = Color(0xFFF1F5F9);      // Almost white
  static const Color darkTextSecondary = Color(0xFFCBD5E1);    // Light gray
  static const Color darkTextTertiary = Color(0xFF94A3B8);     // Medium gray
  static const Color darkBorder = Color(0xFF334155);           // Dark gray border
}