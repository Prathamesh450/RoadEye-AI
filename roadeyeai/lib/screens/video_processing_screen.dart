import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'live_detection_screen.dart';
import '../services/notification_service.dart';
import '../config/api_config.dart';

/// 🎯 UNIFIED VIDEO PROCESSING SCREEN
/// Combines: Upload Video + IP Camera + YouTube in ONE screen
class VideoProcessingScreen extends StatefulWidget {
  const VideoProcessingScreen({super.key});

  @override
  State<VideoProcessingScreen> createState() => _VideoProcessingScreenState();
}

class _VideoProcessingScreenState extends State<VideoProcessingScreen> {
  final String baseUrl = ApiConfig.baseUrl;

  // Tab selection: 0=Upload Video, 1=IP Camera, 2=YouTube
  int _selectedTab = 0;

  // === UPLOAD VIDEO STATES ===
  String? _selectedFilePath;
  String? _selectedFileName;
  Uint8List? _fileBytes;

  // === IP CAMERA STATES ===
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _portController = TextEditingController(
    text: '8080',
  );
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _requiresAuth = false;
  StreamType _streamType = StreamType.mjpeg;

  // === YOUTUBE STATES ===
  final TextEditingController _youtubeController = TextEditingController();

  // === COMMON STATES ===
  final TextEditingController _latController = TextEditingController(
    text: '18.5204',
  );
  final TextEditingController _lonController = TextEditingController(
    text: '73.8567',
  );
  final TextEditingController _cameraIdController = TextEditingController(
    text: 'CAMERA_001',
  );

  bool _isProcessing = false;
  String? _statusMessage;
  String? _sessionId;

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _youtubeController.dispose();
    _latController.dispose();
    _lonController.dispose();
    _cameraIdController.dispose();
    super.dispose();
  }

  // ==========================================
  // 📹 UPLOAD VIDEO METHODS
  // ==========================================

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
          _statusMessage = null;
        });

        print('✅ Video selected: $_selectedFileName');
        _showSuccess('Video selected: $_selectedFileName');
      }
    } catch (e) {
      print('❌ Error picking file: $e');
      _showError('Error selecting video: $e');
    }
  }

  Future<void> _uploadAndProcess() async {
    if (_fileBytes == null && _selectedFilePath == null) {
      _showError('Please select a video first');
      return;
    }

    if (!_validateLocation()) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = null;
    });

    try {
      final sessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';
      _sessionId = sessionId;

      print('🔑 Starting upload with session: $sessionId');

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/process-video'),
      );

      // Add video file
      if (kIsWeb && _fileBytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'video',
            _fileBytes!,
            filename: _selectedFileName ?? 'video.mp4',
          ),
        );
      } else if (_selectedFilePath != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'video',
            _selectedFilePath!,
            filename: _selectedFileName,
          ),
        );
      }

      // Add form fields
      request.fields['camera_lat'] = _latController.text;
      request.fields['camera_lon'] = _lonController.text;
      request.fields['camera_id'] = _cameraIdController.text;
      request.fields['session_id'] = sessionId;

      print('📤 Uploading video...');

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 120),
        onTimeout: () => throw Exception('Upload timeout'),
      );

      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);

        if (jsonResponse['status'] == 'success') {
          setState(() {
            _isProcessing = false;
            _statusMessage = '✅ Processing started! Session: $sessionId';
          });

          await NotificationService.showNotification(
            title: '✅ Video Upload Complete',
            body: 'AI processing started. You will be notified of violations.',
          );

          _navigateToLiveDetection(sessionId);
        } else {
          throw Exception(jsonResponse['message'] ?? 'Upload failed');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Upload error: $e');
      setState(() {
        _isProcessing = false;
        _statusMessage = '❌ Error: $e';
      });
      _showError('Upload failed: $e');
    }
  }

  // ==========================================
  // 📹 IP CAMERA METHODS
  // ==========================================

  String _buildStreamURL() {
    String ip = _ipController.text.trim();
    String port = _portController.text.trim();

    String auth = '';
    if (_requiresAuth && _usernameController.text.isNotEmpty) {
      auth = '${_usernameController.text}:${_passwordController.text}@';
    }

    switch (_streamType) {
      case StreamType.mjpeg:
        return 'http://$auth$ip:$port/video';
      case StreamType.rtsp:
        return 'rtsp://$auth$ip:$port/';
      case StreamType.hls:
        return 'http://$auth$ip:$port/stream.m3u8';
      case StreamType.http:
        return 'http://$auth$ip:$port/videofeed';
    }
  }

  bool _isValidIP(String ip) {
    final ipRegex = RegExp(
      r'^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$',
    );
    return ipRegex.hasMatch(ip);
  }

  Future<void> _testIPConnection() async {
    if (_ipController.text.isEmpty) {
      _showError('Please enter IP address');
      return;
    }

    if (!_isValidIP(_ipController.text.trim())) {
      _showError('Invalid IP address format');
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = '⏳ Testing connection...';
    });

    try {
      String streamUrl = _buildStreamURL();

      final response = await http
          .get(
            Uri.parse(streamUrl),
            headers: _requiresAuth
                ? {
                    'Authorization':
                        'Basic ${base64Encode(utf8.encode('${_usernameController.text}:${_passwordController.text}'))}',
                  }
                : null,
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception('Connection timeout'),
          );

      if (response.statusCode == 200) {
        setState(() {
          _statusMessage = '✅ Connection successful!';
        });
        _showSuccess('Camera connected successfully!');
      } else if (response.statusCode == 401) {
        setState(() {
          _statusMessage = '⚠️ Authentication required';
          _requiresAuth = true;
        });
        _showError('Authentication required. Enter credentials.');
      } else {
        throw Exception('Connection failed: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _statusMessage = '❌ Connection failed: $e';
      });
      _showError('Cannot connect to camera: $e');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _processIPCamera() async {
    if (_ipController.text.isEmpty) {
      _showError('Please enter IP address');
      return;
    }

    if (!_isValidIP(_ipController.text.trim())) {
      _showError('Invalid IP address format');
      return;
    }

    if (!_validateLocation()) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = '⏳ Starting camera processing...';
    });

    try {
      final sessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';
      _sessionId = sessionId;

      final payload = {
        'camera_ip': _ipController.text.trim(),
        'camera_port': _portController.text.trim(),
        'camera_lat': _latController.text.trim(),
        'camera_lon': _lonController.text.trim(),
        'camera_id': _cameraIdController.text.trim(),
        'session_id': sessionId,
        'stream_type': _streamType.name,
      };

      if (_requiresAuth) {
        payload['username'] = _usernameController.text.trim();
        payload['password'] = _passwordController.text.trim();
      }

      print('📤 Starting IP camera processing: $sessionId');

      final response = await http
          .post(
            Uri.parse('$baseUrl/process-camera'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);

        if (jsonResponse['status'] == 'success') {
          setState(() {
            _isProcessing = false;
            _statusMessage = '✅ Processing started! Session: $sessionId';
          });

          _showSuccess('Camera processing started!');
          _navigateToLiveDetection(sessionId);
        } else {
          throw Exception(jsonResponse['message'] ?? 'Processing failed');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error: $e');
      setState(() {
        _isProcessing = false;
        _statusMessage = '❌ Error: $e';
      });
      _showError('Processing failed: $e');
    }
  }

  // ==========================================
  // 📺 YOUTUBE METHODS
  // ==========================================

  bool _isValidYouTubeURL(String url) {
    final patterns = [
      RegExp(r'(https?://)?(www\.)?(youtube\.com|youtu\.be)/.+'),
      RegExp(r'(https?://)?(www\.)?youtube\.com/watch\?v=[\w-]+'),
      RegExp(r'(https?://)?(www\.)?youtu\.be/[\w-]+'),
    ];
    return patterns.any((pattern) => pattern.hasMatch(url));
  }

  Future<void> _processYouTube() async {
    if (_youtubeController.text.isEmpty) {
      _showError('Please enter YouTube URL');
      return;
    }

    if (!_isValidYouTubeURL(_youtubeController.text.trim())) {
      _showError('Invalid YouTube URL format');
      return;
    }

    if (!_validateLocation()) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = '⏳ Starting YouTube processing...';
    });

    try {
      final sessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';
      _sessionId = sessionId;

      final payload = {
        'youtube_url': _youtubeController.text.trim(),
        'camera_lat': _latController.text.trim(),
        'camera_lon': _lonController.text.trim(),
        'camera_id': _cameraIdController.text.trim(),
        'session_id': sessionId,
      };

      print('📤 Starting YouTube processing: $sessionId');

      final response = await http
          .post(
            Uri.parse('$baseUrl/process-youtube'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);

        if (jsonResponse['status'] == 'success') {
          setState(() {
            _isProcessing = false;
            _statusMessage = '✅ Processing started! Session: $sessionId';
          });

          _showSuccess('YouTube processing started!');
          _navigateToLiveDetection(sessionId);
        } else {
          throw Exception(jsonResponse['message'] ?? 'Processing failed');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error: $e');
      setState(() {
        _isProcessing = false;
        _statusMessage = '❌ Error: $e';
      });
      _showError('Processing failed: $e');
    }
  }

  // ==========================================
  // 🛠️ HELPER METHODS
  // ==========================================

  bool _validateLocation() {
    if (_latController.text.isEmpty || _lonController.text.isEmpty) {
      _showError('Please enter camera location');
      return false;
    }

    double? lat = double.tryParse(_latController.text);
    double? lon = double.tryParse(_lonController.text);

    if (lat == null || lon == null) {
      _showError('Invalid latitude/longitude format');
      return false;
    }

    if (lat < -90 || lat > 90 || lon < -180 || lon > 180) {
      _showError('Invalid coordinate range');
      return false;
    }

    return true;
  }

  void _navigateToLiveDetection(String sessionId) {
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => LiveDetectionScreen(
            processingId: sessionId,
            cameraId: _cameraIdController.text,
            cameraLocation: {
              'lat': double.parse(_latController.text),
              'lon': double.parse(_lonController.text),
            },
          ),
        ),
      );
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ==========================================
  // 🎨 UI BUILD METHODS
  // ==========================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Processing'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // 🎯 TAB SELECTOR
          _buildTabSelector(),

          // 📄 CONTENT
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Show selected tab content
                  if (_selectedTab == 0) _buildUploadVideoTab(),
                  if (_selectedTab == 1) _buildIPCameraTab(),
                  if (_selectedTab == 2) _buildYouTubeTab(),

                  const SizedBox(height: 24),

                  // Common: Camera Location
                  _buildLocationSection(),

                  const SizedBox(height: 24),

                  // Action Button
                  _buildActionButton(),

                  // Status Message
                  if (_statusMessage != null) ...[
                    const SizedBox(height: 16),
                    _buildStatusCard(),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabSelector() {
    return Container(
      color: Colors.grey[200],
      child: Row(
        children: [
          _buildTab(0, Icons.video_file, 'Upload'),
          _buildTab(1, Icons.videocam, 'IP Camera'),
          _buildTab(2, Icons.play_circle_filled, 'YouTube'),
        ],
      ),
    );
  }

  Widget _buildTab(int index, IconData icon, String label) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: InkWell(
        onTap: _isProcessing
            ? null
            : () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            border: Border(
              bottom: BorderSide(
                color: isSelected ? Colors.blue : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: isSelected ? Colors.blue : Colors.grey),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.blue : Colors.grey,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUploadVideoTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeaderCard(
          icon: Icons.video_library,
          color: Colors.blue,
          title: 'Upload Video File',
          subtitle: 'Select a video from your device',
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _isProcessing ? null : _pickVideo,
          icon: const Icon(Icons.video_file),
          label: const Text('Select Video File'),
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
              subtitle: const Text('Ready to upload'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildIPCameraTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeaderCard(
          icon: Icons.videocam,
          color: Colors.deepPurple,
          title: 'Connect IP Camera',
          subtitle: 'Stream from network cameras',
        ),
        const SizedBox(height: 16),

        // IP Address & Port
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: _ipController,
                decoration: const InputDecoration(
                  labelText: 'IP Address',
                  hintText: '192.168.1.100',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.router),
                ),
                keyboardType: TextInputType.number,
                enabled: !_isProcessing,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 1,
              child: TextField(
                controller: _portController,
                decoration: const InputDecoration(
                  labelText: 'Port',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                enabled: !_isProcessing,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Stream Type
        DropdownButtonFormField<StreamType>(
          value: _streamType,
          decoration: const InputDecoration(
            labelText: 'Stream Type',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.stream),
          ),
          items: StreamType.values.map((type) {
            return DropdownMenuItem(value: type, child: Text(type.displayName));
          }).toList(),
          onChanged: _isProcessing
              ? null
              : (value) {
                  if (value != null) setState(() => _streamType = value);
                },
        ),

        const SizedBox(height: 12),

        // Authentication Toggle
        SwitchListTile(
          title: const Text('🔐 Requires Authentication'),
          value: _requiresAuth,
          onChanged: _isProcessing
              ? null
              : (value) {
                  setState(() => _requiresAuth = value);
                },
        ),

        if (_requiresAuth) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _usernameController,
            decoration: const InputDecoration(
              labelText: 'Username',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person),
            ),
            enabled: !_isProcessing,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _passwordController,
            decoration: const InputDecoration(
              labelText: 'Password',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.lock),
            ),
            obscureText: true,
            enabled: !_isProcessing,
          ),
        ],

        const SizedBox(height: 12),

        // Test Connection Button
        OutlinedButton.icon(
          onPressed: _isProcessing ? null : _testIPConnection,
          icon: const Icon(Icons.wifi_tethering),
          label: const Text('Test Connection'),
        ),
      ],
    );
  }

  Widget _buildYouTubeTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeaderCard(
          icon: Icons.play_circle_filled,
          color: Colors.red,
          title: 'Process YouTube Video',
          subtitle: 'Analyze traffic from YouTube',
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _youtubeController,
          decoration: const InputDecoration(
            labelText: 'YouTube URL',
            hintText: 'https://www.youtube.com/watch?v=...',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.link),
          ),
          keyboardType: TextInputType.url,
          enabled: !_isProcessing,
          maxLines: 2,
        ),
      ],
    );
  }

  Widget _buildLocationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '📍 Camera Location',
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
          enabled: !_isProcessing,
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
                enabled: !_isProcessing,
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
                enabled: !_isProcessing,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton() {
    String label;
    VoidCallback? onPressed;
    Color color;

    if (_selectedTab == 0) {
      label = _isProcessing ? 'Uploading...' : 'Upload & Process Video';
      onPressed = (_selectedFileName != null && !_isProcessing)
          ? _uploadAndProcess
          : null;
      color = Colors.green;
    } else if (_selectedTab == 1) {
      label = _isProcessing ? 'Processing...' : 'Start Camera Processing';
      onPressed = !_isProcessing ? _processIPCamera : null;
      color = Colors.deepPurple;
    } else {
      label = _isProcessing ? 'Processing...' : 'Process YouTube Video';
      onPressed = !_isProcessing ? _processYouTube : null;
      color = Colors.red;
    }

    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: _isProcessing
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Colors.white),
              ),
            )
          : const Icon(Icons.play_arrow),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.all(20),
        backgroundColor: color,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildHeaderCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Card(
      color: color.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      color: _statusMessage!.contains('❌')
          ? Colors.red.shade50
          : _statusMessage!.contains('✅')
          ? Colors.green.shade50
          : Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          _statusMessage!,
          style: TextStyle(
            color: _statusMessage!.contains('❌')
                ? Colors.red.shade900
                : _statusMessage!.contains('✅')
                ? Colors.green.shade900
                : Colors.blue.shade900,
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 📦 ENUMS
// ==========================================

enum StreamType {
  mjpeg,
  rtsp,
  http,
  hls;

  String get displayName {
    switch (this) {
      case StreamType.mjpeg:
        return 'MJPEG (IP Webcam)';
      case StreamType.rtsp:
        return 'RTSP Stream';
      case StreamType.http:
        return 'HTTP Stream';
      case StreamType.hls:
        return 'HLS Stream';
    }
  }
}
