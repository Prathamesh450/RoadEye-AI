// lib/screens/violation_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/violation_model.dart';

class ViolationDetailScreen extends StatelessWidget {
  final Violation violation;

  const ViolationDetailScreen({
    super.key,
    required this.violation,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Violation Details'),
        // ✅ REMOVED: Export action button
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.red.shade700, Colors.red.shade500],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 64, color: Colors.white),
                  const SizedBox(height: 16),
                  Text(
                    violation.numberPlate,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      violation.status,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Details Section
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle(context, 'Vehicle Information'),
                  const SizedBox(height: 12),
                  _buildInfoCard(context, [
                    _buildInfoRow(Icons.directions_car, 'Vehicle Type', violation.vehicleType, Colors.blue),
                    _buildInfoRow(Icons.check_circle, 'Detection Accuracy', violation.accuracyPercentage, Colors.green),
                    _buildInfoRow(Icons.camera_alt, 'Camera ID', violation.cameraId, Colors.purple),
                  ]),

                  const SizedBox(height: 24),
                  _buildSectionTitle(context, 'Location Details'),
                  const SizedBox(height: 12),
                  _buildInfoCard(context, [
                    _buildInfoRow(Icons.location_city, 'Zone Name', violation.zoneName, Colors.orange),
                    _buildInfoRow(Icons.place, 'City', violation.city, Colors.red),
                    _buildInfoRow(
                      Icons.my_location,
                      'Coordinates',
                      '${violation.latitude.toStringAsFixed(5)}, ${violation.longitude.toStringAsFixed(5)}',
                      Colors.teal,
                    ),
                    _buildInfoRow(
                      Icons.straighten,
                      'Distance from Center',
                      '${violation.distanceFromCenter.toStringAsFixed(2)} meters',
                      Colors.indigo,
                    ),
                    _buildInfoRow(
                      Icons.radio_button_unchecked,
                      'Zone Radius',
                      '${violation.zoneRadius.toStringAsFixed(2)} meters',
                      Colors.brown,
                    ),
                  ]),

                  const SizedBox(height: 24),
                  _buildSectionTitle(context, 'Time Information'),
                  const SizedBox(height: 12),
                  _buildInfoCard(context, [
                    _buildInfoRow(Icons.access_time, 'Detected At', violation.getFormattedDate(), Colors.deepPurple),
                    _buildInfoRow(Icons.schedule, 'Time Ago', violation.getFormattedTime(), Colors.blueGrey),
                  ]),

                  const SizedBox(height: 24),
                  _buildSectionTitle(context, 'Additional Information'),
                  const SizedBox(height: 12),
                  _buildInfoCard(context, [
                    _buildInfoRow(Icons.badge, 'Zone ID', violation.zoneId, Colors.cyan),
                    _buildInfoRow(
                      Icons.videocam,
                      'Video Status',
                      violation.videoPath != 'not_provided' ? 'Available' : 'Not Available',
                      violation.videoPath != 'not_provided' ? Colors.green : Colors.grey,
                    ),
                    _buildInfoRow(Icons.fingerprint, 'Violation ID', violation.id, Colors.pink),
                  ]),

                  const SizedBox(height: 32),
                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _copyToClipboard(context, violation.numberPlate, 'Number plate'),
                          icon: const Icon(Icons.copy),
                          label: const Text('Copy Plate'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showMapLocation(context),
                          icon: const Icon(Icons.map),
                          label: const Text('View Map'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (violation.videoPath != 'not_provided')
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _showVideoPlayer(context),
                        icon: const Icon(Icons.play_circle_filled),
                        label: const Text('Watch Video'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
    );
  }

  Widget _buildInfoCard(BuildContext context, List<Widget> children) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(children: children),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 2),
                Text(
                  value, 
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showMapLocation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(Icons.map, color: Theme.of(context).primaryColor),
            const SizedBox(width: 8),
            const Text('Location'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDialogInfoRow(
              icon: Icons.my_location,
              label: 'Latitude',
              value: violation.latitude.toStringAsFixed(6),
            ),
            const SizedBox(height: 8),
            _buildDialogInfoRow(
              icon: Icons.location_on,
              label: 'Longitude',
              value: violation.longitude.toStringAsFixed(6),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Map integration coming soon!',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showVideoPlayer(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(Icons.videocam, color: Colors.red.shade700),
            const SizedBox(width: 8),
            const Text('Video Player'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.play_circle_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            const Text(
              'Video player integration coming soon!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 8),
            Text(
              'Path: ${violation.videoPath}',
              style: const TextStyle(
                fontSize: 11,
                color: Colors.grey,
                fontFamily: 'monospace',
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}