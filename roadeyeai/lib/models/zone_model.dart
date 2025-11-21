class RestrictedZone {
  final String id;
  final String city;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final String activeHours;
  final String inactiveHours;
  final bool isActive;

  RestrictedZone({
    required this.id,
    required this.city,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.activeHours,
    required this.inactiveHours,
    this.isActive = true,
  });

  // From JSON (for API responses)
  factory RestrictedZone.fromJson(Map<String, dynamic> json) {
    return RestrictedZone(
      id: json['id'] ?? '',
      city: json['city'] ?? '',
      latitude: (json['center']?['lat'] ?? 0.0).toDouble(),
      longitude: (json['center']?['lon'] ?? 0.0).toDouble(),
      radiusMeters: (json['radius_meters'] ?? 0.0).toDouble(),
      activeHours: json['active_hours'] ?? '',
      inactiveHours: json['inactive_hours'] ?? '',
      isActive: json['is_active'] ?? true,
    );
  }

  // To JSON (for API requests)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'city': city,
      'center': {
        'lat': latitude,
        'lon': longitude,
      },
      'radius_meters': radiusMeters,
      'active_hours': activeHours,
      'inactive_hours': inactiveHours,
      'is_active': isActive,
    };
  }

  // Copy with method for updates
  RestrictedZone copyWith({
    String? id,
    String? city,
    double? latitude,
    double? longitude,
    double? radiusMeters,
    String? activeHours,
    String? inactiveHours,
    bool? isActive,
  }) {
    return RestrictedZone(
      id: id ?? this.id,
      city: city ?? this.city,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      activeHours: activeHours ?? this.activeHours,
      inactiveHours: inactiveHours ?? this.inactiveHours,
      isActive: isActive ?? this.isActive,
    );
  }
}