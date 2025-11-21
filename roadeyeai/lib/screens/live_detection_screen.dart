// import 'package:flutter/material.dart';
// import 'dart:async';
// import 'dart:convert';
// import 'package:http/http.dart' as http;
// import '../models/violation_model.dart';
// import '../services/notification_service.dart';
// import 'violation_detail_screen.dart';
// import '../config/api_config.dart';
// class LiveDetectionScreen extends StatefulWidget {
//   final String processingId; // Session ID
//   final String cameraId;
//   final Map<String, double> cameraLocation;

//   const LiveDetectionScreen({
//     super.key,
//     required this.processingId,
//     required this.cameraId,
//     required this.cameraLocation,
//   });

//   @override
//   State<LiveDetectionScreen> createState() => _LiveDetectionScreenState();
// }

// class _LiveDetectionScreenState extends State<LiveDetectionScreen> {
//   final String baseUrl = ApiConfig.baseUrl;

//   List<Violation> _violations = [];
//   Set<String> _notifiedViolationIds =
//       {}; // Track which violations we've notified
//   Timer? _pollTimer;
//   bool _isLoading = true;
//   String? _errorMessage;
//   String _processingStatus = 'processing';

//   @override
//   void initState() {
//     super.initState();
//     print("🎬 Live Detection started for session: ${widget.processingId}");
//     _startPolling();
//   }

//   @override
//   void dispose() {
//     _pollTimer?.cancel();
//     super.dispose();
//   }

//   // Start polling for new violations
//   void _startPolling() {
//     // Initial fetch
//     _fetchSessionViolations();

//     // Poll every 2 seconds
//     _pollTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
//       _fetchSessionViolations();
//     });
//   }

//   // Fetch violations for this specific session
//   Future<void> _fetchSessionViolations() async {
//     try {
//       final url = '$baseUrl/get-session-violations/${widget.processingId}';
//       print("📡 Polling: $url");

//       final response = await http
//           .get(Uri.parse(url))
//           .timeout(
//             const Duration(seconds: 10),
//             onTimeout: () {
//               throw TimeoutException('Request timeout');
//             },
//           );

//       if (response.statusCode == 200) {
//         final jsonResponse = jsonDecode(response.body);

//         if (jsonResponse['status'] == 'success') {
//           final List<dynamic> violationsJson = jsonResponse['violations'] ?? [];

//           final newProcessingStatus =
//               jsonResponse['processing_status'] ?? 'processing';

//           setState(() {
//             _processingStatus = newProcessingStatus;

//             // Parse violations
//             final newViolations = violationsJson
//                 .map((json) => Violation.fromJson(json))
//                 .toList();

//             // Check for NEW violations and send notifications
//             for (var violation in newViolations) {
//               if (!_notifiedViolationIds.contains(violation.id)) {
//                 // NEW VIOLATION - Send notification!
//                 _sendViolationNotification(violation);
//                 _notifiedViolationIds.add(violation.id);
//               }
//             }

//             _violations = newViolations;
//             _isLoading = false;
//             _errorMessage = null;
//           });

//           print(
//             "✅ Fetched ${_violations.length} violations from session ${widget.processingId}",
//           );
//           print("📊 Processing status: $_processingStatus");

//           // Stop polling if processing is complete
//           if (_processingStatus == 'completed' ||
//               _processingStatus == 'failed') {
//             print("🏁 Processing completed. Stopping poll.");
//             _pollTimer?.cancel();
//           }
//         }
//       } else if (response.statusCode == 404) {
//         // Session not found yet - keep trying
//         print("⏳ Session not ready yet...");
//       } else {
//         throw Exception('Failed to fetch violations: ${response.statusCode}');
//       }
//     } catch (e) {
//       print("❌ Error fetching session violations: $e");
//       setState(() {
//         if (_violations.isEmpty) {
//           _errorMessage = "Unable to connect: $e";
//         }
//         _isLoading = false;
//       });
//     }
//   }

//   // Send notification for new violation
//   Future<void> _sendViolationNotification(Violation violation) async {
//     try {
//       print("🔔 Sending notification for: ${violation.numberPlate}");

//       await NotificationService.showNotification(
//         title: '🚨 HMV Violation Detected!',
//         body: '${violation.numberPlate} detected in ${violation.zoneName}',
//       );

//       print("✅ Notification sent for: ${violation.numberPlate}");
//     } catch (e) {
//       print("❌ Failed to send notification: $e");
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const Text('Live Detection', style: TextStyle(fontSize: 18)),
//             Text(
//               'Session: ${widget.processingId.substring(widget.processingId.length - 8)}',
//               style: const TextStyle(
//                 fontSize: 12,
//                 fontWeight: FontWeight.normal,
//               ),
//             ),
//           ],
//         ),
//         backgroundColor: Colors.blue,
//         foregroundColor: Colors.white,
//         actions: [
//           // Processing status indicator
//           Padding(
//             padding: const EdgeInsets.all(12.0),
//             child: Row(
//               children: [
//                 if (_processingStatus == 'processing')
//                   const SizedBox(
//                     width: 16,
//                     height: 16,
//                     child: CircularProgressIndicator(
//                       strokeWidth: 2,
//                       valueColor: AlwaysStoppedAnimation(Colors.white),
//                     ),
//                   )
//                 else if (_processingStatus == 'completed')
//                   const Icon(Icons.check_circle, color: Colors.green)
//                 else if (_processingStatus == 'failed')
//                   const Icon(Icons.error, color: Colors.red),
//                 const SizedBox(width: 8),
//                 Text(
//                   _processingStatus.toUpperCase(),
//                   style: const TextStyle(fontSize: 12),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//       body: Column(
//         children: [
//           // Status Card
//           Container(
//             width: double.infinity,
//             padding: const EdgeInsets.all(16),
//             decoration: BoxDecoration(
//               gradient: LinearGradient(
//                 colors: [Colors.blue.shade700, Colors.blue.shade500],
//                 begin: Alignment.topLeft,
//                 end: Alignment.bottomRight,
//               ),
//             ),
//             child: Column(
//               children: [
//                 const Icon(Icons.radar, size: 48, color: Colors.white),
//                 const SizedBox(height: 8),
//                 const Text(
//                   'AI Detection Active',
//                   style: TextStyle(
//                     fontSize: 20,
//                     fontWeight: FontWeight.bold,
//                     color: Colors.white,
//                   ),
//                 ),
//                 const SizedBox(height: 4),
//                 Text(
//                   'Camera: ${widget.cameraId}',
//                   style: const TextStyle(color: Colors.white70),
//                 ),
//                 Text(
//                   'Location: ${widget.cameraLocation['lat']}, ${widget.cameraLocation['lon']}',
//                   style: const TextStyle(color: Colors.white70, fontSize: 12),
//                 ),
//               ],
//             ),
//           ),

//           // Violations Counter
//           Container(
//             padding: const EdgeInsets.all(16),
//             color: Colors.red.shade50,
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceAround,
//               children: [
//                 _buildStatCard(
//                   Icons.warning_amber_rounded,
//                   'Violations',
//                   '${_violations.length}',
//                   Colors.red,
//                 ),
//                 _buildStatCard(
//                   Icons.access_time,
//                   'Status',
//                   _processingStatus == 'processing' ? 'Active' : 'Done',
//                   Colors.green,
//                 ),
//               ],
//             ),
//           ),

//           // Violations List
//           Expanded(
//             child: _isLoading
//                 ? const Center(
//                     child: Column(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: [
//                         CircularProgressIndicator(),
//                         SizedBox(height: 16),
//                         Text('Initializing AI detection...'),
//                         SizedBox(height: 8),
//                         Text(
//                           'Waiting for violations...',
//                           style: TextStyle(color: Colors.grey),
//                         ),
//                       ],
//                     ),
//                   )
//                 : _errorMessage != null
//                 ? Center(
//                     child: Column(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: [
//                         const Icon(
//                           Icons.error_outline,
//                           size: 64,
//                           color: Colors.red,
//                         ),
//                         const SizedBox(height: 16),
//                         Text(_errorMessage!),
//                         const SizedBox(height: 16),
//                         ElevatedButton(
//                           onPressed: _fetchSessionViolations,
//                           child: const Text('Retry'),
//                         ),
//                       ],
//                     ),
//                   )
//                 : _violations.isEmpty
//                 ? Center(
//                     child: Column(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: [
//                         Icon(
//                           Icons.check_circle_outline,
//                           size: 64,
//                           color: Colors.green.shade300,
//                         ),
//                         const SizedBox(height: 16),
//                         const Text(
//                           'No Violations Detected',
//                           style: TextStyle(
//                             fontSize: 18,
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                         const SizedBox(height: 8),
//                         Text(
//                           _processingStatus == 'processing'
//                               ? 'AI is analyzing video...'
//                               : 'Processing complete - All clear!',
//                           style: const TextStyle(color: Colors.grey),
//                         ),
//                       ],
//                     ),
//                   )
//                 : RefreshIndicator(
//                     onRefresh: _fetchSessionViolations,
//                     child: ListView.builder(
//                       padding: const EdgeInsets.all(16),
//                       itemCount: _violations.length,
//                       itemBuilder: (context, index) {
//                         final violation = _violations[index];
//                         return _buildViolationCard(violation);
//                       },
//                     ),
//                   ),
//           ),
//         ],
//       ),
//       floatingActionButton: _violations.isNotEmpty
//           ? FloatingActionButton.extended(
//               onPressed: () {
//                 showDialog(
//                   context: context,
//                   builder: (context) => AlertDialog(
//                     title: const Text('Export Report'),
//                     content: const Text(
//                       'Export functionality will be available soon.',
//                     ),
//                     actions: [
//                       TextButton(
//                         onPressed: () => Navigator.pop(context),
//                         child: const Text('OK'),
//                       ),
//                     ],
//                   ),
//                 );
//               },
//               icon: const Icon(Icons.file_download),
//               label: const Text('Export'),
//               backgroundColor: Colors.blue,
//             )
//           : null,
//     );
//   }

//   Widget _buildStatCard(
//     IconData icon,
//     String label,
//     String value,
//     Color color,
//   ) {
//     return Column(
//       children: [
//         Icon(icon, size: 32, color: color),
//         const SizedBox(height: 4),
//         Text(
//           value,
//           style: TextStyle(
//             fontSize: 24,
//             fontWeight: FontWeight.bold,
//             color: color,
//           ),
//         ),
//         Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
//       ],
//     );
//   }

//   Widget _buildViolationCard(Violation violation) {
//     return Card(
//       margin: const EdgeInsets.only(bottom: 12),
//       elevation: 2,
//       child: InkWell(
//         onTap: () {
//           Navigator.push(
//             context,
//             MaterialPageRoute(
//               builder: (context) => ViolationDetailScreen(violation: violation),
//             ),
//           );
//         },
//         child: Padding(
//           padding: const EdgeInsets.all(16.0),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Row(
//                 children: [
//                   Container(
//                     padding: const EdgeInsets.all(8),
//                     decoration: BoxDecoration(
//                       color: Colors.red.shade50,
//                       borderRadius: BorderRadius.circular(8),
//                     ),
//                     child: const Icon(
//                       Icons.warning_amber_rounded,
//                       color: Colors.red,
//                       size: 24,
//                     ),
//                   ),
//                   const SizedBox(width: 12),
//                   Expanded(
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text(
//                           violation.numberPlate,
//                           style: const TextStyle(
//                             fontSize: 18,
//                             fontWeight: FontWeight.bold,
//                             letterSpacing: 1,
//                           ),
//                         ),
//                         const SizedBox(height: 4),
//                         Row(
//                           children: [
//                             Container(
//                               padding: const EdgeInsets.symmetric(
//                                 horizontal: 8,
//                                 vertical: 2,
//                               ),
//                               decoration: BoxDecoration(
//                                 color: Colors.orange,
//                                 borderRadius: BorderRadius.circular(4),
//                               ),
//                               child: Text(
//                                 violation.vehicleType,
//                                 style: const TextStyle(
//                                   color: Colors.white,
//                                   fontSize: 12,
//                                   fontWeight: FontWeight.bold,
//                                 ),
//                               ),
//                             ),
//                             const SizedBox(width: 8),
//                             Container(
//                               padding: const EdgeInsets.symmetric(
//                                 horizontal: 8,
//                                 vertical: 2,
//                               ),
//                               decoration: BoxDecoration(
//                                 color: Colors.green.shade100,
//                                 borderRadius: BorderRadius.circular(4),
//                               ),
//                               child: Text(
//                                 violation.accuracyPercentage,
//                                 style: TextStyle(
//                                   color: Colors.green.shade900,
//                                   fontSize: 12,
//                                   fontWeight: FontWeight.bold,
//                                 ),
//                               ),
//                             ),
//                           ],
//                         ),
//                       ],
//                     ),
//                   ),
//                   const Icon(Icons.chevron_right, color: Colors.grey),
//                 ],
//               ),
//               const Divider(height: 24),
//               _buildInfoRow(Icons.location_city, violation.zoneName),
//               const SizedBox(height: 8),
//               _buildInfoRow(Icons.access_time, violation.getFormattedTime()),
//               const SizedBox(height: 8),
//               _buildInfoRow(Icons.camera_alt, violation.cameraId),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildInfoRow(IconData icon, String text) {
//     return Row(
//       children: [
//         Icon(icon, size: 16, color: Colors.grey),
//         const SizedBox(width: 8),
//         Expanded(
//           child: Text(
//             text,
//             style: const TextStyle(fontSize: 14, color: Colors.grey),
//             overflow: TextOverflow.ellipsis,
//           ),
//         ),
//       ],
//     );
//   }
// }
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../config/api_config.dart';
import '../services/notification_service.dart'; // ✅ IMPORT NOTIFICATION SERVICE

/// 🎯 LIVE DETECTION SCREEN
/// Shows real-time violations as they're detected
class LiveDetectionScreen extends StatefulWidget {
  final String processingId; // session_id
  final String cameraId;
  final Map<String, dynamic> cameraLocation;

  const LiveDetectionScreen({
    super.key,
    required this.processingId,
    required this.cameraId,
    required this.cameraLocation,
  });

  @override
  State<LiveDetectionScreen> createState() => _LiveDetectionScreenState();
}

class _LiveDetectionScreenState extends State<LiveDetectionScreen> {
  Timer? _pollingTimer;
  List<Map<String, dynamic>> _violations = [];
  Set<String> _notifiedViolationIds = {}; // ✅ Track notified violations
  String _processingStatus = 'processing';
  bool _isLoading = true;
  String? _errorMessage;
  int _pollCount = 0;
  DateTime? _startTime;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    
    print('🎬 LIVE DETECTION STARTED');
    print('   Session: ${widget.processingId}');
    print('   Camera: ${widget.cameraId}');
    
    // ✅ Initialize notifications
    _initializeNotifications();
    
    _fetchViolations();
    _startPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  // ✅ Initialize notification service
  Future<void> _initializeNotifications() async {
    try {
      await NotificationService.initialize();
      final hasPermission = await NotificationService.requestPermissions();
      
      if (hasPermission) {
        print('✅ Notifications enabled');
      } else {
        print('⚠️ Notification permission denied');
      }
    } catch (e) {
      print('❌ Notification init error: $e');
    }
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _fetchViolations();
    });
  }

  Future<void> _fetchViolations() async {
    try {
      _pollCount++;
      
      final url = '${ApiConfig.baseUrl}/get-session-violations/${widget.processingId}';
      
      if (_pollCount % 5 == 1) {
        print('🔍 Poll #$_pollCount: $url');
      }

      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['status'] == 'success') {
          final newViolations = List<Map<String, dynamic>>.from(
            data['violations'] ?? [],
          );
          
          // ✅ CHECK FOR NEW VIOLATIONS AND SEND NOTIFICATIONS
          for (var violation in newViolations) {
            final violationId = violation['id'] ?? violation['number_plate'];
            
            if (!_notifiedViolationIds.contains(violationId)) {
              // 🚨 NEW VIOLATION - SEND NOTIFICATION!
              _sendViolationNotification(violation);
              _notifiedViolationIds.add(violationId);
            }
          }
          
          if (newViolations.length != _violations.length) {
            print('📊 Violations: ${_violations.length} → ${newViolations.length}');
          }

          setState(() {
            _violations = newViolations;
            _processingStatus = data['processing_status'] ?? 'processing';
            _isLoading = false;
            _errorMessage = null;
          });

          if (_processingStatus == 'completed' || _processingStatus == 'failed') {
            print('🏁 Processing finished: $_processingStatus');
            _pollingTimer?.cancel();
          }
        }
      } else if (response.statusCode == 404) {
        final data = jsonDecode(response.body);
        print('❌ Session not found!');
        print('   Available: ${data['available_sessions']}');
        
        setState(() {
          _errorMessage = 'Session not found';
          _isLoading = false;
        });
        
        _pollingTimer?.cancel();
      }
    } catch (e) {
      if (_pollCount <= 3) {
        print('⚠️ Poll error: $e');
      }
      setState(() {
        _errorMessage = 'Connection error';
        _isLoading = false;
      });
    }
  }

  // ✅ SEND NOTIFICATION FOR NEW VIOLATION
  Future<void> _sendViolationNotification(Map<String, dynamic> violation) async {
    try {
      final numberPlate = violation['number_plate'] ?? 'Unknown';
      final zoneName = violation['zone_name'] ?? 'Restricted Zone';
      final vehicleType = violation['vehicle_type'] ?? 'HMV';
      
      print('🔔 Sending notification for: $numberPlate');

      await NotificationService.showViolationNotification(
        title: '🚨 HMV Violation Detected!',
        body: '$vehicleType vehicle $numberPlate detected in $zoneName',
        cameraId: widget.cameraId,
      );

      print('✅ Notification sent for: $numberPlate');
    } catch (e) {
      print('❌ Failed to send notification: $e');
    }
  }

  String _getElapsedTime() {
    if (_startTime == null) return '0s';
    final elapsed = DateTime.now().difference(_startTime!);
    
    if (elapsed.inHours > 0) {
      return '${elapsed.inHours}h ${elapsed.inMinutes % 60}m';
    } else if (elapsed.inMinutes > 0) {
      return '${elapsed.inMinutes}m ${elapsed.inSeconds % 60}s';
    } else {
      return '${elapsed.inSeconds}s';
    }
  }

  Color _getStatusColor() {
    switch (_processingStatus) {
      case 'processing':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Detection'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchViolations,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStatusHeader(),
          Expanded(child: _buildViolationsList()),
        ],
      ),
    );
  }

  Widget _buildStatusHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _getStatusColor().withOpacity(0.1),
        border: Border(bottom: BorderSide(color: _getStatusColor(), width: 2)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_processingStatus == 'processing')
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              if (_processingStatus == 'processing') const SizedBox(width: 12),
              Text(
                _processingStatus == 'processing'
                    ? '🔄 Processing...'
                    : _processingStatus == 'completed'
                        ? '✅ Complete'
                        : '❌ Failed',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _getStatusColor(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStat(Icons.warning, 'Violations', '${_violations.length}', Colors.red),
              _buildStat(Icons.timer, 'Elapsed', _getElapsedTime(), Colors.blue),
              _buildStat(Icons.camera_alt, 'Camera', widget.cameraId, Colors.green),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Session: ${widget.processingId}',
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(IconData icon, String label, String value, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
        ),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildViolationsList() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading violations...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(_errorMessage!),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _fetchViolations,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_violations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _processingStatus == 'completed' ? Icons.check_circle : Icons.search,
              size: 64,
              color: _processingStatus == 'completed' ? Colors.green : Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              _processingStatus == 'completed'
                  ? 'No Violations Found'
                  : 'Waiting for violations...',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _violations.length,
      itemBuilder: (context, index) {
        final violation = _violations[index];
        return _buildViolationCard(violation, index + 1);
      },
    );
  }

  Widget _buildViolationCard(Map<String, dynamic> v, int num) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade200, width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '#$num',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          v['number_plate'] ?? 'Unknown',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          v['vehicle_type'] ?? 'HMV',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.warning, color: Colors.red, size: 32),
                ],
              ),
              const Divider(height: 24),
              _buildDetail(Icons.location_on, 'Zone', v['zone_name'] ?? 'Unknown'),
              _buildDetail(Icons.location_city, 'City', v['city'] ?? 'Unknown'),
              _buildDetail(
                Icons.straighten,
                'Distance',
                '${v['distance_from_center_m']?.toStringAsFixed(1) ?? '?'} m',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetail(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w500)),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}