import 'package:flutter/material.dart';
import '../models/zone_model.dart';
import '../services/api_service.dart';
import '../utils/app_colors.dart';
import '../widgets/custom_text_field.dart';

class RestrictedZonesScreen extends StatefulWidget {
  const RestrictedZonesScreen({super.key});

  @override
  State<RestrictedZonesScreen> createState() => _RestrictedZonesScreenState();
}

class _RestrictedZonesScreenState extends State<RestrictedZonesScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _latitudeController = TextEditingController();
  final TextEditingController _longitudeController = TextEditingController();
  final TextEditingController _radiusController = TextEditingController();
  final TextEditingController _activeHoursController = TextEditingController();
  final TextEditingController _inactiveHoursController = TextEditingController();

  List<RestrictedZone> zones = [];
  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadZones();
  }

  Future<void> _loadZones() async {
    setState(() => _isLoading = true);
    
    // ⚠️ MOCK API CALL - Load zones from database
    final result = await ApiService.getRestrictedZones();
    
    if (result['success']) {
      setState(() {
        zones = (result['data'] as List)
            .map((json) => RestrictedZone.fromJson(json))
            .toList();
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addZone() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);

    // ⚠️ MOCK API CALL - Save zone to database
    final result = await ApiService.createRestrictedZone(
      zoneName: _idController.text.trim(),
      city: 'Pune',
      latitude: double.parse(_latitudeController.text),
      longitude: double.parse(_longitudeController.text),
      radiusMeters: double.parse(_radiusController.text),
      activeHours: _activeHoursController.text.trim(),
      inactiveHours: _inactiveHoursController.text.trim(),
    );

    setState(() => _isSaving = false);

    if (result['success']) {
      // Add to local list
      final newZone = RestrictedZone(
        id: _idController.text.trim(),
        city: _cityController.text.trim(),
        latitude: double.parse(_latitudeController.text.trim()),
        longitude: double.parse(_longitudeController.text.trim()),
        radiusMeters: double.parse(_radiusController.text.trim()),
        activeHours: _activeHoursController.text.trim(),
        inactiveHours: _inactiveHoursController.text.trim(),
        isActive: true,
      );

      setState(() {
        zones.add(newZone);
      });

      // Clear form
      _clearForm();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _clearForm() {
    _idController.clear();
    _cityController.clear();
    _latitudeController.clear();
    _longitudeController.clear();
    _radiusController.clear();
    _activeHoursController.clear();
    _inactiveHoursController.clear();
  }

  Future<void> _deleteZone(String zoneId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Zone'),
        content: const Text(
          'Are you sure you want to delete this restricted zone?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // ⚠️ MOCK API CALL - Delete from database
      final result = await ApiService.deleteRestrictedZone(zoneId);

      if (result['success']) {
        setState(() {
          zones.removeWhere((zone) => zone.id == zoneId);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  void _toggleZone(RestrictedZone zone) async {
    final updatedZone = zone.copyWith(isActive: !zone.isActive);
    
    // ⚠️ MOCK API CALL - Update in database
    // await ApiService.updateRestrictedZone(
    //   id: zone.id,
    //   data: updatedZone.toJson(),
    // );

    // REPLACE WITH:
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Update feature coming soon')),
    );

    setState(() {
      final index = zones.indexWhere((z) => z.id == zone.id);
      zones[index] = updatedZone;
    });
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Get theme brightness for dark mode
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Restricted Zones'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Add Zone Form
                    Card(
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.add_location,
                                  color: AppColors.error,
                                  size: 28,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Add New Restricted Zone',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    // ✅ FIXED: Dynamic text color
                                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            
                            // Zone ID
                            CustomTextField(
                              controller: _idController,
                              labelText: 'Zone ID *',
                              prefixIcon: Icons.tag,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter zone ID';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            
                            // City
                            CustomTextField(
                              controller: _cityController,
                              labelText: 'City *',
                              prefixIcon: Icons.location_city,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter city name';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            
                            // Latitude & Longitude Row
                            Row(
                              children: [
                                Expanded(
                                  child: CustomTextField(
                                    controller: _latitudeController,
                                    labelText: 'Latitude *',
                                    prefixIcon: Icons.my_location,
                                    keyboardType: const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Required';
                                      }
                                      if (double.tryParse(value) == null) {
                                        return 'Invalid';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: CustomTextField(
                                    controller: _longitudeController,
                                    labelText: 'Longitude *',
                                    prefixIcon: Icons.location_on,
                                    keyboardType: const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Required';
                                      }
                                      if (double.tryParse(value) == null) {
                                        return 'Invalid';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            
                            // Radius
                            CustomTextField(
                              controller: _radiusController,
                              labelText: 'Radius (meters) *',
                              prefixIcon: Icons.radio_button_unchecked,
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter radius';
                                }
                                if (double.tryParse(value) == null) {
                                  return 'Invalid number';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            
                            // Active Hours
                            CustomTextField(
                              controller: _activeHoursController,
                              labelText: 'Active Hours *',
                              hintText: 'e.g., 08:00-11:00, 17:00-21:00',
                              prefixIcon: Icons.access_time,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter active hours';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            
                            // Inactive Hours
                            CustomTextField(
                              controller: _inactiveHoursController,
                              labelText: 'Inactive Hours *',
                              hintText: 'e.g., 21:00-08:00',
                              prefixIcon: Icons.nights_stay,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter inactive hours';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),
                            
                            // Add Button
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton.icon(
                                onPressed: _isSaving ? null : _addZone,
                                icon: _isSaving
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                            Colors.white,
                                          ),
                                        ),
                                      )
                                    : const Icon(Icons.add),
                                label: Text(
                                  _isSaving
                                      ? 'SAVING TO DATABASE...'
                                      : 'ADD TO DATABASE',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.error,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Zones List Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Restricted Zones',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            // ✅ FIXED: Dynamic text color
                            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          '${zones.length} zones',
                          style: TextStyle(
                            fontSize: 14,
                            // ✅ FIXED: Dynamic secondary text color
                            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    zones.isEmpty
                        ? _buildEmptyState()
                        : Column(
                            children: zones.map((zone) => _buildZoneCard(zone)).toList(),
                          ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.location_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No Restricted Zones',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first restricted zone above',
              style: TextStyle(
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildZoneCard(RestrictedZone zone) {
    // ✅ Get theme brightness
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        color: zone.isActive ? AppColors.error : Colors.grey,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              zone.city,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                // ✅ FIXED: Dynamic color based on theme AND active state
                                color: zone.isActive
                                    ? (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary)
                                    : Colors.grey,
                              ),
                            ),
                            Text(
                              'ID: ${zone.id}',
                              style: TextStyle(
                                fontSize: 12,
                                // ✅ FIXED: Dynamic secondary text color
                                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: zone.isActive
                        ? AppColors.success.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    zone.isActive ? 'Active' : 'Inactive',
                    style: TextStyle(
                      color: zone.isActive ? AppColors.success : Colors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildInfoRow(
              Icons.my_location,
              'Coordinates',
              '${zone.latitude.toStringAsFixed(6)}, ${zone.longitude.toStringAsFixed(6)}',
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.radio_button_unchecked,
              'Radius',
              '${zone.radiusMeters.toStringAsFixed(2)} meters',
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.access_time,
              'Active Hours',
              zone.activeHours,
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.nights_stay,
              'Inactive Hours',
              zone.inactiveHours,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.delete),
                  color: AppColors.error,
                  onPressed: () => _deleteZone(zone.id),
                ),
                const SizedBox(width: 8),
                Switch(
                  value: zone.isActive,
                  onChanged: (value) => _toggleZone(zone),
                  activeThumbColor: AppColors.success,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ✅ FIXED: _buildInfoRow with dynamic colors for dark mode
  Widget _buildInfoRow(IconData icon, String label, String value) {
    // ✅ Get theme brightness
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon, 
          size: 18, 
          // ✅ FIXED: Dynamic icon color
          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  // ✅ FIXED: Dynamic label color
                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  // ✅ CRITICAL FIX: Dynamic value color - WHITE in dark mode
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _idController.dispose();
    _cityController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _radiusController.dispose();
    _activeHoursController.dispose();
    _inactiveHoursController.dispose();
    super.dispose();
  }
}