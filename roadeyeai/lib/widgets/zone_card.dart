import 'package:flutter/material.dart';
import '../models/zone_model.dart';

class ZoneCard extends StatelessWidget {
  final RestrictedZone zone;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggle;

  const ZoneCard({
    super.key,
    required this.zone,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
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
                      Icons.dangerous,
                      color: zone.isActive ? Colors.red : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      zone.name,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: zone.isActive ? Colors.red : Colors.grey,
                      ),
                    ),
                  ],
                ),
                Chip(
                  label: Text(
                    zone.isActive ? 'Active' : 'Inactive',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                  backgroundColor: zone.isActive ? Colors.green : Colors.grey,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Location: ${zone.location}',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              zone.description,
              style: const TextStyle(
                color: Colors.black87,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: onEdit,
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: onDelete,
                ),
                Switch(
                  value: zone.isActive,
                  onChanged: onToggle,
                  activeThumbColor: Colors.red,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}