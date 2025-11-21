// lib/screens/violations_screen.dart

import 'package:flutter/material.dart';
import '../models/violation_model.dart';
import '../services/violation_service.dart';
import 'violation_detail_screen.dart';

class ViolationsScreen extends StatefulWidget {
  const ViolationsScreen({super.key});

  @override
  State<ViolationsScreen> createState() => _ViolationsScreenState();
}

class _ViolationsScreenState extends State<ViolationsScreen> {
  List<Violation> _violations = [];
  List<Violation> _filteredViolations = [];
  bool _isLoading = true;
  String _errorMessage = '';
  String _searchQuery = '';
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _loadViolations();
  }

  Future<void> _loadViolations() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final violations = await ViolationService.getViolations();
      setState(() {
        _violations = violations;
        _filteredViolations = violations;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _filterViolations(String query) {
    setState(() {
      _searchQuery = query;
      _filteredViolations = _violations.where((violation) {
        final searchLower = query.toLowerCase();
        return violation.numberPlate.toLowerCase().contains(searchLower) ||
            violation.zoneName.toLowerCase().contains(searchLower) ||
            violation.city.toLowerCase().contains(searchLower);
      }).toList();
    });
  }

  void _applyFilter(String filter) {
    setState(() {
      _selectedFilter = filter;
      
      if (filter == 'All') {
        _filteredViolations = _violations;
      } else if (filter == 'Today') {
        final today = DateTime.now();
        final todayStart = DateTime(today.year, today.month, today.day);
        _filteredViolations = _violations.where((v) {
          try {
            final violationDate = DateTime.parse(v.timestamp);
            return violationDate.isAfter(todayStart);
          } catch (e) {
            return false;
          }
        }).toList();
      } else if (filter == 'This Week') {
        final now = DateTime.now();
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        _filteredViolations = _violations.where((v) {
          try {
            final violationDate = DateTime.parse(v.timestamp);
            return violationDate.isAfter(weekStart);
          } catch (e) {
            return false;
          }
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Violations'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadViolations,
            tooltip: 'Refresh',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: _applyFilter,
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'All', child: Text('All')),
              const PopupMenuItem(value: 'Today', child: Text('Today')),
              const PopupMenuItem(value: 'This Week', child: Text('This Week')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by plate, zone, or city...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
              ),
              onChanged: _filterViolations,
            ),
          ),

          // Stats Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Total',
                    _violations.length.toString(),
                    Icons.list_alt,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Filtered',
                    _filteredViolations.length.toString(),
                    Icons.filter_alt,
                    Colors.orange,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Violations List
          Expanded(
            child: _buildViolationsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViolationsList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Error loading violations',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(_errorMessage, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadViolations,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_filteredViolations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _searchQuery.isEmpty ? Icons.check_circle_outline : Icons.search_off,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty
                  ? 'No violations found'
                  : 'No results for "$_searchQuery"',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadViolations,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredViolations.length,
        itemBuilder: (context, index) {
          final violation = _filteredViolations[index];
          return _buildViolationCard(violation);
        },
      ),
    );
  }

  Widget _buildViolationCard(Violation violation) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ViolationDetailScreen(violation: violation),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            violation.numberPlate,
                            style: TextStyle(
                              color: Colors.red.shade900,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            violation.vehicleType,
                            style: TextStyle(
                              color: Colors.orange.shade900,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    violation.getFormattedTime(),
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Zone Info
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${violation.zoneName} • ${violation.city}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Distance Info
              Row(
                children: [
                  const Icon(Icons.straighten, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    '${violation.distanceFromCenter.toStringAsFixed(1)} m from center',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(width: 16),
                  const Icon(Icons.camera_alt, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    violation.cameraId,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),

              // Accuracy
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle, size: 16, color: Colors.green),
                      const SizedBox(width: 4),
                      Text(
                        'Accuracy: ${violation.accuracyPercentage}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}