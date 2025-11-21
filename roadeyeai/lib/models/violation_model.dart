// lib/models/violation_model.dart

class Violation {
  final String id;
  final String cameraId;
  final String city;
  final double distanceFromCenter;
  final String numberPlate;
  final String status;
  final String timestamp;
  final String vehicleType;
  final String videoPath;
  final String zoneId;
  final String zoneName;
  final double zoneRadius;
  final String accuracyPercentage;
  final double latitude;
  final double longitude;

  Violation({
    required this.id,
    required this.cameraId,
    required this.city,
    required this.distanceFromCenter,
    required this.numberPlate,
    required this.status,
    required this.timestamp,
    required this.vehicleType,
    required this.videoPath,
    required this.zoneId,
    required this.zoneName,
    required this.zoneRadius,
    required this.accuracyPercentage,
    required this.latitude,
    required this.longitude,
  });

  factory Violation.fromJson(Map<String, dynamic> json) {
  dynamic safeGet(Map<String, dynamic> map, String key, [dynamic defaultValue]) {
    if (!map.containsKey(key) || map[key] == null) return defaultValue;
    return map[key];
  }

  double parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is String) {
      // Handle stray quotes or formatting issues
      return double.tryParse(value.replaceAll('"', '').trim()) ?? 0.0;
    }
    return 0.0;
  }

  final Map<String, dynamic> location = (json['location'] is Map)
      ? Map<String, dynamic>.from(json['location'])
      : {};

  return Violation(
    id: safeGet(json, 'id', '').toString(),
    cameraId: safeGet(json, 'camera_id', '').toString(),
    city: safeGet(json, 'city', '').toString(),
    distanceFromCenter: parseDouble(safeGet(json, 'distance_from_center_m', 0.0)),
    numberPlate: safeGet(json, 'number_plate', '').toString(),
    status: safeGet(json, 'status', '').toString(),
    timestamp: safeGet(json, 'timestamp', '').toString(),
    vehicleType: safeGet(json, 'vehicle_type', '').toString(),
    videoPath: safeGet(json, 'video_path', '').toString(),
    zoneId: safeGet(json, 'zone_id', '').toString(),
    zoneName: safeGet(json, 'zone_name', '').toString(),
    zoneRadius: parseDouble(safeGet(json, 'zone_radius_m', 0.0)),
    accuracyPercentage: safeGet(json, 'accuracy_percentage', 'N/A').toString(),
    latitude: parseDouble(safeGet(location, 'lat', 0.0)),
    longitude: parseDouble(safeGet(location, 'lon', 0.0)),
  );
}


  /// Convert Violation → JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'camera_id': cameraId,
      'city': city,
      'distance_from_center_m': distanceFromCenter,
      'number_plate': numberPlate,
      'status': status,
      'timestamp': timestamp,
      'vehicle_type': vehicleType,
      'video_path': videoPath,
      'zone_id': zoneId,
      'zone_name': zoneName,
      'zone_radius_m': zoneRadius,
      'accuracy_percentage': accuracyPercentage,
      'location': {
        'lat': latitude,
        'lon': longitude,
      },
    };
  }

  /// Get formatted timestamp
  String getFormattedTime() {
    try {
      final dateTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inHours < 1) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inDays < 1) {
        return '${difference.inHours}h ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
      }
    } catch (e) {
      return 'Unknown';
    }
  }

  /// Get formatted date string
  String getFormattedDate() {
    try {
      final dateTime = DateTime.parse(timestamp);
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Unknown';
    }
  }
}

class Location {
  final double lat;
  final double lon;

  Location({required this.lat, required this.lon});

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      lat: (json['lat'] is num)
          ? json['lat'].toDouble()
          : double.tryParse(json['lat']?.toString() ?? '0') ?? 0.0,
      lon: (json['lon'] is num)
          ? json['lon'].toDouble()
          : double.tryParse(json['lon']?.toString() ?? '0') ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'lat': lat,
        'lon': lon,
      };

  String getCoordinates() => '${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)}';
}