import 'package:flutter/material.dart';
import '../models/violation_model.dart';

class ViolationCard extends StatelessWidget {
  final Violation violation;
  final VoidCallback onViewDetails;
  final VoidCallback onExport;

  const ViolationCard({
    super.key,
    required this.violation,
    required this.onViewDetails,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.warning,
                      color: violation.vehicleType == 'HMV' ? Colors.red : Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      violation.vehicleNumber,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Chip(
                  label: Text(
                    violation.vehicleType,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                  backgroundColor: violation.vehicleType == 'HMV' ? Colors.red : Colors.blue,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Location: ${violation.location}',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(
              'Time: ${_formatDateTime(violation.dateTime)}',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(
              'Confidence: ${(violation.confidence * 100).toStringAsFixed(1)}%',
              style: TextStyle(
                color: _getConfidenceColor(violation.confidence),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: onExport,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.download, size: 16),
                      SizedBox(width: 4),
                      Text('Export'),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: onViewDetails,
                  child: const Text('View Details'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.9) return Colors.green;
    if (confidence >= 0.7) return Colors.orange;
    return Colors.red;
  }
}