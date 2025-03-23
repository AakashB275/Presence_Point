import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GeofencingService {
  // Singleton instance
  static final GeofencingService _instance = GeofencingService._internal();
  factory GeofencingService() => _instance;
  GeofencingService._internal();

  // Variables
  final supabase = Supabase.instance.client;
  StreamSubscription<Position>? _positionStreamSubscription;
  Timer? _workTimer;
  DateTime? _checkInTime;
  bool _isCheckedIn = false;
  int _totalSecondsWorked = 0;

  // Organization location and radius (in meters)
  final double _organizationLatitude =
      37.7749; // Replace with your org's latitude
  final double _organizationLongitude =
      -122.4194; // Replace with your org's longitude
  final double _geofenceRadius = 100.0; // 100 meters radius

  // Callback for UI updates
  Function? onStatusChange;

  // Initialize the service
  Future<void> initialize() async {
    await _checkLocationPermission();
    _startLocationTracking();
  }

  // Check and request location permissions
  Future<void> _checkLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied.');
    }
  }

  // Start tracking location
  void _startLocationTracking() {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(_handleLocationUpdate);
  }

  // Handle location updates
  void _handleLocationUpdate(Position position) async {
    double distance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      _organizationLatitude,
      _organizationLongitude,
    );

    // Inside geofence
    if (distance <= _geofenceRadius) {
      if (!_isCheckedIn) {
        await _checkIn(position);
      }
    }
    // Outside geofence
    else {
      if (_isCheckedIn) {
        await _checkOut(position);
      }
    }
  }

  // Check in when employee enters geofence
  Future<void> _checkIn(Position position) async {
    _isCheckedIn = true;
    _checkInTime = DateTime.now();
    _startWorkTimer();

    // Print log instead of notification
    print('Attendance Marked: Checked in at ${_formatTime(_checkInTime!)}');

    // Save check-in data to Supabase
    await supabase.from('attendance').insert({
      'user_id': supabase.auth.currentUser!.id,
      'check_in_time': _checkInTime!.toIso8601String(),
      'latitude': position.latitude,
      'longitude': position.longitude,
      'status': 'checked_in',
    });

    // Notify UI if callback is set
    if (onStatusChange != null) {
      onStatusChange!();
    }
  }

  // Check out when employee exits geofence
  Future<void> _checkOut(Position position) async {
    _isCheckedIn = false;
    DateTime checkOutTime = DateTime.now();
    _stopWorkTimer();

    // Calculate total hours worked
    int secondsWorked = _totalSecondsWorked;
    String hoursWorked = _formatDuration(Duration(seconds: secondsWorked));

    // Print log instead of notification
    print('Check Out Complete: Total hours worked: $hoursWorked');

    // Update attendance record in Supabase
    List<dynamic> records = await supabase
        .from('attendance')
        .select()
        .eq('user_id', supabase.auth.currentUser!.id)
        .eq('status', 'checked_in')
        .order('check_in_time', ascending: false)
        .limit(1);

    if (records.isNotEmpty) {
      int recordId = records[0]['id'];
      await supabase.from('attendance').update({
        'check_out_time': checkOutTime.toIso8601String(),
        'total_seconds_worked': secondsWorked,
        'status': 'checked_out',
      }).eq('id', recordId);
    }

    // Reset timer
    _totalSecondsWorked = 0;

    // Notify UI if callback is set
    if (onStatusChange != null) {
      onStatusChange!();
    }
  }

  // Start work timer
  void _startWorkTimer() {
    _workTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _totalSecondsWorked++;
    });
  }

  // Stop work timer
  void _stopWorkTimer() {
    _workTimer?.cancel();
    _workTimer = null;
  }

  // Get current check-in status
  bool get isCheckedIn => _isCheckedIn;

  // Get total duration worked
  Duration get totalDurationWorked => Duration(seconds: _totalSecondsWorked);

  // Format time
  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  // Format duration
  String _formatDuration(Duration duration) {
    int hours = duration.inHours;
    int minutes = duration.inMinutes.remainder(60);
    int seconds = duration.inSeconds.remainder(60);
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // Dispose of resources
  void dispose() {
    _positionStreamSubscription?.cancel();
    _workTimer?.cancel();
  }
}
