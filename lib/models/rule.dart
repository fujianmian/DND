enum TriggerType { time, location, app, activity }

class Rule {
  String id;
  String name;
  bool isEnabled;
  TriggerType type;

  // Parameters for Time
  String? startTime; // e.g., "09:00"
  String? endTime; // e.g., "17:00"

  // Parameters for Location
  double? latitude;
  double? longitude;
  double? radius; // in meters

  // Parameters for App Usage
  String? packageName; // e.g., "com.mobile.legends"

  // NEW: Parameters for Activity
  String? activityType;

  Rule({
    required this.id,
    required this.name,
    this.isEnabled = true,
    required this.type,
    this.startTime,
    this.endTime,
    this.latitude,
    this.longitude,
    this.radius,
    this.packageName,
    this.activityType,
  });
}
