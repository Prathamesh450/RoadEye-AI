import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'live_detection_screen.dart';
import '../services/notification_service.dart';
import '../config/api_config.dart';
class VideoProcessingScreen extends StatefulWidget {
  const VideoProcessingScreen({super.key});

  @override
  State<VideoProcessingScreen> createState() => _VideoProcessingScreenState();
}

class _VideoProcessingScreenState extends State<VideoProcessingScreen> {
  // FIXED: Use localhost for better connectivity
  final String baseUrl =
      ApiConfig.baseUrl; // Use your actual backend IP

  String? _selectedFilePath;
  String? _selectedFileName;
  Uint8List? _fileBytes;
  bool _isUploading = false;
  bool _isProcessing = false;
  String? _uploadMessage;
  String? _sessionId;

  // Camera location inputs
  final TextEditingController _latController = TextEditingController(
    text: '18.5204',
  );
  final TextEditingController _lonController = TextEditingController(
    text: '73.8567',
  );
  final TextEditingController _cameraIdController = TextEditingController(
    text: 'CAMERA_001',
  );

  @override
  void dispose() {
    _latController.dispose();
    _lonController.dispose();
    _cameraIdController.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFileName = result.files.first.name;
          _selectedFilePath = result.files.first.path;
          _fileBytes = result.files.first.bytes;
          _uploadMessage = null;
        });

        print('✅ Video selected: $_selectedFileName');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Video selected: $_selectedFileName'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('❌ Error picking file: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting video: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _uploadAndProcess() async {
    if (_fileBytes == null && _selectedFilePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Please select a video first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Validate location
    if (_latController.text.isEmpty || _lonController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Please enter camera location'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    double? lat = double.tryParse(_latController.text);
    double? lon = double.tryParse(_lonController.text);

    if (lat == null || lon == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Invalid latitude/longitude format'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadMessage = null;
    });

    try {
      // Generate session ID
      final sessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';
      _sessionId = sessionId;

      print('🔑 Starting processing with session ID: $sessionId');
      print('📤 Uploading video and starting processing...');
      print('📍 Camera Location: $lat, $lon');
      print('🌐 Backend URL: $baseUrl/process-video');

      // Create multipart request
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/process-video'),
      );

      // Add video file
      if (kIsWeb && _fileBytes != null) {
        // Web: use bytes
        request.files.add(
          http.MultipartFile.fromBytes(
            'video',
            _fileBytes!,
            filename: _selectedFileName ?? 'video.mp4',
          ),
        );
      } else if (_selectedFilePath != null) {
        // Mobile/Desktop: use file path
        request.files.add(
          await http.MultipartFile.fromPath(
            'video',
            _selectedFilePath!,
            filename: _selectedFileName,
          ),
        );
      }

      // Add form fields
      request.fields['camera_lat'] = lat.toString();
      request.fields['camera_lon'] = lon.toString();
      request.fields['camera_id'] = _cameraIdController.text;
      request.fields['session_id'] = sessionId;

      print('📦 Request prepared. Sending to backend...');

      // Send request with extended timeout
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 120), // 2 minute timeout for large files
        onTimeout: () {
          throw Exception(
            'Upload timeout after 2 minutes. Try a smaller video file.',
          );
        },
      );

      print('📡 Response received: ${streamedResponse.statusCode}');

      // Get response
      final response = await http.Response.fromStream(streamedResponse);

      print('📄 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);

        if (jsonResponse['status'] == 'success') {
          setState(() {
            _isUploading = false;
            _isProcessing = true;
            _uploadMessage = 'Processing started! Session: $sessionId';
          });

          print('✅ Upload successful!');
          print('🎬 Processing session: $sessionId');

          // Show success notification
          await NotificationService.showNotification(
            title: '✅ Video Upload Complete',
            body:
                'AI processing started. You will be notified of any violations.',
          );

          // Navigate to live detection screen
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => LiveDetectionScreen(
                  processingId: sessionId,
                  cameraId: _cameraIdController.text,
                  cameraLocation: {'lat': lat, 'lon': lon},
                ),
              ),
            );
          }
        } else {
          throw Exception(jsonResponse['message'] ?? 'Upload failed');
        }
      } else {
        throw Exception(
          'Server error: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print('❌ Upload error: $e');

      setState(() {
        _isUploading = false;
        _uploadMessage = 'Error: $e';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Processing'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Card
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.video_library,
                      size: 48,
                      color: Colors.blue.shade700,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Upload Video for AI Processing',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'AI will detect HMV vehicles and check for violations',
                      style: TextStyle(color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Video Selection Section
            const Text(
              '📹 Step 1: Select Video',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            ElevatedButton.icon(
              onPressed: _isUploading ? null : _pickVideo,
              icon: const Icon(Icons.video_file),
              label: const Text('Pick Video File'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),

            if (_selectedFileName != null) ...[
              const SizedBox(height: 12),
              Card(
                color: Colors.green.shade50,
                child: ListTile(
                  leading: const Icon(Icons.check_circle, color: Colors.green),
                  title: Text(_selectedFileName!),
                  subtitle: const Text('Video ready to upload'),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Camera Location Section
            const Text(
              '📍 Step 2: Camera Location',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _cameraIdController,
              decoration: const InputDecoration(
                labelText: 'Camera ID',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.camera_alt),
              ),
              enabled: !_isUploading,
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _latController,
                    decoration: const InputDecoration(
                      labelText: 'Latitude',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.location_on),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    enabled: !_isUploading,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _lonController,
                    decoration: const InputDecoration(
                      labelText: 'Longitude',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.location_on),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    enabled: !_isUploading,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Upload Button
            const Text(
              '🚀 Step 3: Start Processing',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            ElevatedButton.icon(
              onPressed: (_selectedFileName != null && !_isUploading)
                  ? _uploadAndProcess
                  : null,
              icon: _isUploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Icon(Icons.upload),
              label: Text(
                _isUploading ? 'Uploading...' : 'Upload & Process Video',
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(20),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            // Status Message
            if (_uploadMessage != null) ...[
              const SizedBox(height: 16),
              Card(
                color: _uploadMessage!.contains('Error')
                    ? Colors.red.shade50
                    : Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Text(
                    _uploadMessage!,
                    style: TextStyle(
                      color: _uploadMessage!.contains('Error')
                          ? Colors.red.shade900
                          : Colors.green.shade900,
                    ),
                  ),
                ),
              ),
            ],

            // Info Card
            const SizedBox(height: 24),
            Card(
              color: Colors.amber.shade50,
              child: const Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.orange),
                        SizedBox(width: 8),
                        Text(
                          'Important Information',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Text('✅ AI will detect HMV vehicles (trucks, buses)'),
                    SizedBox(height: 6),
                    Text('✅ License plates will be automatically read'),
                    SizedBox(height: 6),
                    Text('✅ Violations in restricted zones will be flagged'),
                    SizedBox(height: 6),
                    Text('✅ You will receive notifications for each violation'),
                    SizedBox(height: 6),
                    Text('⏱️ Processing may take a few minutes'),
                  ],
                ),
              ),
            ),

            // Backend Connection Status
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.cloud, color: Colors.blue),
                title: const Text('Backend Connection'),
                subtitle: Text(baseUrl),
                trailing: const Icon(Icons.info_outline, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
