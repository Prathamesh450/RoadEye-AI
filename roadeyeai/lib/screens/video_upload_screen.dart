import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_config.dart';
class VideoUploadScreen extends StatefulWidget {
  const VideoUploadScreen({super.key});

  @override
  State<VideoUploadScreen> createState() => _VideoUploadScreenState();
}

class _VideoUploadScreenState extends State<VideoUploadScreen> {
  String? _selectedFileName;
  Uint8List? _selectedFileBytes;
  String? _selectedFilePath;
  bool _isUploading = false;
  String? _errorMessage;

  // ✅ FIXED: Changed FileType.video to FileType.custom
  Future<void> _pickVideo() async {
    try {
      setState(() {
        _errorMessage = null;
      });

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom, // ✅ CHANGED
        allowedExtensions: ['mp4', 'avi', 'mov'],
        withData: kIsWeb,
      );

      if (result != null) {
        PlatformFile file = result.files.single;

        // Validate file extension manually (extra safety)
        String fileExtension = file.extension?.toLowerCase() ?? '';
        if (!['mp4', 'avi', 'mov'].contains(fileExtension)) {
          setState(() {
            _errorMessage =
                "Invalid file type. Please select MP4, AVI, or MOV file.";
          });
          return;
        }

        setState(() {
          _selectedFileName = file.name;

          if (kIsWeb) {
            _selectedFileBytes = file.bytes;
            _selectedFilePath = null;
            print("✅ Video selected (Web - bytes): ${file.name}");
          } else {
            _selectedFilePath = file.path;
            _selectedFileBytes = null;
            print("✅ Video selected (Mobile - path): ${file.path}");
          }
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Error selecting video: $e";
      });
      print("❌ Error picking video: $e");
    }
  }

  // Upload video to backend
  Future<void> _uploadVideo() async {
    if (_selectedFileName == null) {
      setState(() {
        _errorMessage = "Please select a video first";
      });
      return;
    }

    setState(() {
      _isUploading = true;
      _errorMessage = null;
    });

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse(ApiConfig.uploadVideo)
      );

      if (kIsWeb && _selectedFileBytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'video',
            _selectedFileBytes!,
            filename: _selectedFileName,
          ),
        );
        print("📤 Uploading from Web (bytes)");
      } else if (_selectedFilePath != null) {
        request.files.add(
          await http.MultipartFile.fromPath('video', _selectedFilePath!),
        );
        print("📤 Uploading from Mobile (path)");
      }

      print("📡 Sending request to backend...");
      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      var jsonResponse = jsonDecode(responseData);

      if (response.statusCode == 200) {
        setState(() {
          _isUploading = false;
        });

        print("✅ Upload successful!");

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                jsonResponse['message'] ?? 'Video uploaded successfully!',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }

        // Clear selection
        setState(() {
          _selectedFileName = null;
          _selectedFileBytes = null;
          _selectedFilePath = null;
        });
      } else {
        throw Exception(jsonResponse['error'] ?? 'Upload failed');
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
        _errorMessage = "Upload failed: $e";
      });
      print("❌ Upload error: $e");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Upload failed: $e"),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Video for Detection'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title
            const Text(
              'Vehicle Detection Video Upload',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Select Video Button
            Container(
              height: 150,
              decoration: BoxDecoration(
                border: Border.all(
                  color: _selectedFileName != null ? Colors.green : Colors.blue,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(12),
                color: _selectedFileName != null
                    ? Colors.green.shade50
                    : Colors.blue.shade50,
              ),
              child: InkWell(
                onTap: _isUploading ? null : _pickVideo,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _selectedFileName != null
                            ? Icons.video_file
                            : Icons.video_library,
                        size: 56,
                        color: _selectedFileName != null
                            ? Colors.green.shade700
                            : Colors.blue.shade700,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _selectedFileName ?? 'SELECT VIDEO',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _selectedFileName != null
                              ? Colors.green.shade700
                              : Colors.blue.shade700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (_selectedFileName != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          kIsWeb
                              ? 'Web Upload (bytes)'
                              : 'Mobile Upload (path)',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Upload Button
            SizedBox(
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _isUploading || _selectedFileName == null
                    ? null
                    : _uploadVideo,
                icon: _isUploading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Icon(Icons.cloud_upload, size: 24),
                label: Text(
                  _isUploading ? 'UPLOADING...' : '☁ UPLOAD TO DATABASE',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedFileName != null
                      ? Colors.blue
                      : Colors.grey.shade400,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: _selectedFileName != null ? 4 : 0,
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Instructions Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          'Instructions:',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildInstruction(
                      '1. Select a video file from your device',
                      Icons.video_library,
                    ),
                    _buildInstruction(
                      '2. Supported formats: MP4, AVI, MOV',
                      Icons.video_settings,
                    ),
                    _buildInstruction(
                      '3. Click "Upload to Database" to process',
                      Icons.cloud_upload,
                    ),
                    _buildInstruction(
                      '4. AI will analyze the video for vehicle detection',
                      Icons.auto_awesome,
                    ),
                  ],
                ),
              ),
            ),

            // Error Message
            if (_errorMessage != null) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Error:',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInstruction(String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue, size: 22),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 15))),
        ],
      ),
    );
  }
}
