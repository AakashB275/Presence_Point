import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';

class GeoAttendancePage extends StatefulWidget {
  const GeoAttendancePage({Key? key}) : super(key: key);

  @override
  State<GeoAttendancePage> createState() => _GeoAttendancePageState();
}

class _GeoAttendancePageState extends State<GeoAttendancePage> {
  final _supabase = Supabase.instance.client;
  final _service = FlutterBackgroundService();
  final _notifications = FlutterLocalNotificationsPlugin();
  final _locationSettings = const LocationSettings(
    accuracy: LocationAccuracy.bestForNavigation,
    distanceFilter: 10, // meters
  );

  // State variables
  bool _isLoading = true;
  bool _isCheckedIn = false;
  Position? _currentPosition;
  double _distanceToOffice = 0.0;
  StreamSubscription<Position>? _positionStream;
  DateTime? _checkInTime;
  Map<String, dynamic>? _orgData;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _service.invoke('stopService');
    super.dispose();
  }

  Future<void> _initializeApp() async {
    try {
      await _requestPermissions();
      await _initNotifications();
      await _initBackgroundService();
      await _loadOrganizationData();
      await _checkCurrentAttendance();
      _startLocationTracking();
    } catch (e) {
      _handleError('Initialization failed', e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadOrganizationData() async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final response = await _supabase
        .from('users')
        .select('org_id')
        .eq('auth_user_id', user.id)
        .single();

    final orgResponse = await _supabase
        .from('organization')
        .select()
        .eq('org_id', response['org_id'])
        .single();

    setState(() => _orgData = orgResponse);
  }

  Future<void> _checkCurrentAttendance() async {
    final user = _supabase.auth.currentUser;
    if (user == null || _orgData == null) return;

    final today = DateTime.now().toUtc().dateOnly;
    final response = await _supabase
        .from('attendance')
        .select()
        .eq('user_id', user.id)
        .gte('check_in_time', today.toIso8601String())
        .filter('check_out_time', 'is', 'null')
        .maybeSingle();

    if (response != null) {
      setState(() {
        _isCheckedIn = true;
        _checkInTime = DateTime.parse(response['check_in_time']).toLocal();
      });
      await _service.startService();
    }
  }

  Future<void> _handleLocationUpdate(Position position) async {
    if (!mounted || _orgData == null) return;

    final distance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      _orgData!['latitude'],
      _orgData!['longitude'],
    );

    setState(() {
      _currentPosition = position;
      _distanceToOffice = distance;
    });

    if (_isCheckedIn && distance > _orgData!['geofencing_radius']) {
      await _performCheckOut();
      _showNotification('Auto Check-Out', 'Left office premises');
    }
  }

  // Proper geography point formatting for Supabase
  String _toPostgisPoint(Position position) {
    return 'SRID=4326;POINT(${position.longitude} ${position.latitude})';
  }

  Future<void> _performCheckIn() async {
    if (_currentPosition == null || _orgData == null) return;

    setState(() => _isLoading = true);
    try {
      final now = DateTime.now().toUtc();
      final response = await _supabase
          .from('attendance')
          .insert({
            'user_id': _supabase.auth.currentUser!.id,
            'org_id': _orgData!['org_id'],
            'check_in_time': now.toIso8601String(),
            'check_in_location': _toPostgisPoint(_currentPosition!),
          })
          .select()
          .single();

      setState(() {
        _isCheckedIn = true;
        _checkInTime = now.toLocal();
      });

      await _service.startService();
      _showNotification('Check-In Successful', 'Attendance recorded');
    } catch (e) {
      _handleError('Check-in failed', e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _performCheckOut() async {
    if (!_isCheckedIn || _currentPosition == null) return;

    setState(() => _isLoading = true);
    try {
      final now = DateTime.now().toUtc();
      await _supabase
          .from('attendance')
          .update({
            'check_out_time': now.toIso8601String(),
            'check_out_location': _toPostgisPoint(_currentPosition!),
            'total_hours':
                now.difference(_checkInTime!.toUtc()).inMinutes / 60.0,
          })
          .eq('user_id', _supabase.auth.currentUser!.id)
          .filter('check_out_time', 'is', 'null');

      setState(() {
        _isCheckedIn = false;
        _checkInTime = null;
      });

      _service.invoke('stopService');
      _showNotification('Check-Out Successful', 'Attendance completed');
    } catch (e) {
      _handleError('Check-out failed', e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startLocationTracking() {
    _positionStream?.cancel();
    _positionStream = Geolocator.getPositionStream(
      locationSettings: _locationSettings,
    ).listen(_handleLocationUpdate, onError: (e) {
      debugPrint('Location stream error: $e');
    });
  }

  Future<bool> _requestPermissions() async {
    final status = await Permission.location.request();
    if (!status.isGranted) {
      _handleError('Permission required', 'Location permission denied');
      return false;
    }
    return true;
  }

  Future<void> _initBackgroundService() async {
    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onBackgroundServiceStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'geo_attendance',
        initialNotificationTitle: 'Attendance Tracking',
        initialNotificationContent: 'Tracking your location',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        onForeground: _onBackgroundServiceStart,
        autoStart: false,
      ),
    );
  }

  @pragma('vm:entry-point')
  static Future<void> _onBackgroundServiceStart(ServiceInstance service) async {
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: "Attendance Tracking",
        content: "Monitoring your location",
      );
    }
    service.on('stopService').listen((event) {
      service.stopSelf();
    });
  }

  Future<void> _initNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _notifications
        .initialize(const InitializationSettings(android: android));
  }

  Future<void> _showNotification(String title, String body) async {
    const android = AndroidNotificationDetails(
      'attendance_channel',
      'Attendance Notifications',
      importance: Importance.high,
      priority: Priority.high,
    );
    await _notifications.show(
        0, title, body, const NotificationDetails(android: android));
  }

  void _handleError(String context, dynamic error) {
    debugPrint('$context: $error');
    _showNotification('Error', '$context: ${error.toString()}');
  }

  String get _statusText {
    if (!_isCheckedIn) {
      return _distanceToOffice <= _orgData?['geofencing_radius']
          ? 'Ready to check-in'
          : 'Move closer to office (${_distanceToOffice.toStringAsFixed(0)}m away)';
    }
    final duration = _checkInTime != null
        ? DateTime.now().difference(_checkInTime!)
        : Duration.zero;
    return 'Checked in (${duration.inHours}h ${duration.inMinutes.remainder(60)}m)';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Geo Attendance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _startLocationTracking,
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Text(_orgData?['org_name'] ?? 'Office Location',
                              style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 8),
                          Text(
                              'Geofence: ${_orgData?['geofencing_radius']?.toStringAsFixed(0) ?? '--'}m radius'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Text('Current Status',
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 8),
                          Text(_statusText),
                          const SizedBox(height: 12),
                          LinearProgressIndicator(
                            value: _distanceToOffice /
                                (_orgData?['geofencing_radius'] ?? 1),
                            backgroundColor: Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _distanceToOffice <=
                                      (_orgData?['geofencing_radius'] ?? 0)
                                  ? Colors.green
                                  : Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed:
                        _isCheckedIn ? _performCheckOut : _performCheckIn,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      backgroundColor: _isCheckedIn ? Colors.red : Colors.green,
                    ),
                    child: Text(_isCheckedIn ? 'CHECK OUT' : 'CHECK IN',
                        style: const TextStyle(fontSize: 18)),
                  ),
                ],
              ),
            ),
    );
  }
}

extension DateTimeExtensions on DateTime {
  DateTime get dateOnly => DateTime(year, month, day);
}
