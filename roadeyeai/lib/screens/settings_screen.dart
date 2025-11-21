import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../services/notification_service.dart';
import '../utils/app_colors.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _vibrationEnabled = true;
  bool _soundEnabled = true;
  bool _autoRefresh = true;
  int _refreshInterval = 30; // seconds
  
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _requestNotificationPermissions();
  }

  Future<void> _requestNotificationPermissions() async {
    final granted = await NotificationService.requestPermissions();
    if (!granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Notification permissions denied'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _vibrationEnabled = prefs.getBool('vibration_enabled') ?? true;
      _soundEnabled = prefs.getBool('sound_enabled') ?? true;
      _autoRefresh = prefs.getBool('auto_refresh') ?? true;
      _refreshInterval = prefs.getInt('refresh_interval') ?? 30;
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', _notificationsEnabled);
    await prefs.setBool('vibration_enabled', _vibrationEnabled);
    await prefs.setBool('sound_enabled', _soundEnabled);
    await prefs.setBool('auto_refresh', _autoRefresh);
    await prefs.setInt('refresh_interval', _refreshInterval);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Settings saved'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userModel = Provider.of<UserModel>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Profile Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    child: Icon(
                      Icons.person,
                      size: 40,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    userModel.email,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'User Account',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Notifications Section
          _buildSectionTitle('🔔 Notification Settings'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Enable Notifications'),
                  subtitle: const Text('Receive violation alerts'),
                  value: _notificationsEnabled,
                  onChanged: (value) {
                    setState(() => _notificationsEnabled = value);
                    _saveSettings();
                  },
                  secondary: const Icon(Icons.notifications),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Vibration'),
                  subtitle: const Text('Vibrate on new violations'),
                  value: _vibrationEnabled,
                  onChanged: _notificationsEnabled
                      ? (value) {
                          setState(() => _vibrationEnabled = value);
                          _saveSettings();
                        }
                      : null,
                  secondary: const Icon(Icons.vibration),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Sound'),
                  subtitle: const Text('Play alert sound'),
                  value: _soundEnabled,
                  onChanged: _notificationsEnabled
                      ? (value) {
                          setState(() => _soundEnabled = value);
                          _saveSettings();
                        }
                      : null,
                  secondary: const Icon(Icons.volume_up),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Auto Refresh Settings
          _buildSectionTitle('🔄 Auto Refresh'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Auto Refresh'),
                  subtitle: const Text('Automatically check for new violations'),
                  value: _autoRefresh,
                  onChanged: (value) {
                    setState(() => _autoRefresh = value);
                    _saveSettings();
                  },
                  secondary: const Icon(Icons.refresh),
                ),
                if (_autoRefresh) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.timer),
                    title: const Text('Refresh Interval'),
                    subtitle: Text('Check every $_refreshInterval seconds'),
                    trailing: DropdownButton<int>(
                      value: _refreshInterval,
                      items: const [
                        DropdownMenuItem(value: 15, child: Text('15s')),
                        DropdownMenuItem(value: 30, child: Text('30s')),
                        DropdownMenuItem(value: 60, child: Text('1m')),
                        DropdownMenuItem(value: 300, child: Text('5m')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _refreshInterval = value);
                          _saveSettings();
                        }
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Theme Settings
          _buildSectionTitle('🎨 Appearance'),
          Card(
            child: SwitchListTile(
              title: const Text('Dark Mode'),
              subtitle: const Text('Use dark theme'),
              value: userModel.darkMode,
              onChanged: (value) {
                userModel.toggleDarkMode();
                _saveSettings();
              },
              secondary: Icon(
                userModel.darkMode ? Icons.dark_mode : Icons.light_mode,
              ),
            ),
          ),

          const SizedBox(height: 24),

          // About Section
          _buildSectionTitle('ℹ️ About'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info),
                  title: const Text('Version'),
                  trailing: const Text('2.0.0'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.privacy_tip),
                  title: const Text('Privacy Policy'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Privacy Policy - Coming Soon')),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.description),
                  title: const Text('Terms of Service'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Terms of Service - Coming Soon')),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}