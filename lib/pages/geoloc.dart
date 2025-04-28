import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

class GeoAttendancePage extends StatefulWidget {
  const GeoAttendancePage({super.key});

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
      _showNotification('Auto Check-Out', 'You left the office premises');
    }
  }

  String _toPostgisPoint(Position position) {
    return 'POINT(${position.latitude} ${position.longitude})';
  }

  Future<void> _performCheckIn() async {
    if (_currentPosition == null ||
        _orgData == null ||
        _supabase.auth.currentUser == null) return;

    setState(() => _isLoading = true);
    try {
      final now = DateTime.now().toUtc();

      await _supabase.from('attendance').insert({
        'user_id': _supabase.auth.currentUser!.id,
        'org_id': _orgData!['org_id'],
        'check_in_time': now.toIso8601String(),
        'check_in_location': _toPostgisPoint(_currentPosition!),
        'date': now.dateOnly.toIso8601String(),
      });

      setState(() {
        _isCheckedIn = true;
        _checkInTime = now.toLocal();
      });

      await _service.startService();
      _showNotification(
          'Check-In Successful', 'Your attendance has been recorded');
    } catch (e) {
      _handleError('Check-in failed', e);
      setState(() => _isCheckedIn = false);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _performCheckOut() async {
    if (!_isCheckedIn ||
        _currentPosition == null ||
        _supabase.auth.currentUser == null) return;

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
      _showNotification(
          'Check-Out Successful', 'Your attendance has been completed');
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
    if (status.isDenied || status.isPermanentlyDenied) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Permission Required'),
            content: const Text(
                'Location permission is required for attendance tracking'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => openAppSettings(),
                child: const Text('Open Settings'),
              ),
            ],
          ),
        );
      }
      return false;
    }
    return status.isGranted;
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
    final locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 10,
    );

    final positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((position) {
      service.invoke('updateLocation', position.toJson());
    });

    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: "Attendance Tracking",
        content: "Monitoring your location",
      );
    }

    service.on('stopService').listen((event) {
      positionStream.cancel();
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
      ticker: 'ticker',
      styleInformation: BigTextStyleInformation(''),
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
      return _distanceToOffice <=
              (_orgData?['geofencing_radius'] ?? double.infinity)
          ? 'You can check-in now'
          : 'You need to be within ${_orgData?['geofencing_radius']?.toStringAsFixed(0)}m to check-in (${_distanceToOffice.toStringAsFixed(0)}m away)';
    }
    final duration = _checkInTime != null
        ? DateTime.now().difference(_checkInTime!)
        : Duration.zero;
    return 'Checked in for ${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
  }

  Widget _buildLocationInfo() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.business, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  _orgData?['org_name'] ?? 'Office Location',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.location_on, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  'Geofence radius: ${_orgData?['geofencing_radius']?.toStringAsFixed(0) ?? '--'} meters',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_currentPosition != null) ...[
              Row(
                children: [
                  Icon(Icons.gps_fixed, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    'Current distance: ${_distanceToOffice.toStringAsFixed(0)} meters',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Attendance Status',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isCheckedIn
                    ? Colors.green.withOpacity(0.1)
                    : Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isCheckedIn ? Colors.green : Colors.blue,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isCheckedIn ? Icons.check_circle : Icons.info,
                    color: _isCheckedIn ? Colors.green : Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _statusText,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: _isCheckedIn ? Colors.green : Colors.blue,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: _distanceToOffice / (_orgData?['geofencing_radius'] ?? 1),
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                _distanceToOffice <= (_orgData?['geofencing_radius'] ?? 0)
                    ? Colors.green
                    : Colors.red,
              ),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '0m',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                Text(
                  '${_orgData?['geofencing_radius']?.toStringAsFixed(0) ?? '--'}m',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading
            ? null
            : _isCheckedIn
                ? _performCheckOut
                : _performCheckIn,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: _isCheckedIn ? Colors.red : Colors.green,
          disabledBackgroundColor: Colors.grey[400],
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                _isCheckedIn ? 'CHECK OUT' : 'CHECK IN',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Geo Attendance'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _startLocationTracking,
            tooltip: 'Refresh location',
          )
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading attendance data...'),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildLocationInfo(),
                  const SizedBox(height: 20),
                  _buildStatusCard(),
                  const SizedBox(height: 20),
                  if (_currentPosition != null) ...[
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Location Details',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(Icons.my_location,
                                    color: Colors.grey[600]),
                                const SizedBox(width: 8),
                                Text(
                                  'Lat: ${_currentPosition!.latitude.toStringAsFixed(6)}',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.my_location,
                                    color: Colors.grey[600]),
                                const SizedBox(width: 8),
                                Text(
                                  'Lng: ${_currentPosition!.longitude.toStringAsFixed(6)}',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.speed, color: Colors.grey[600]),
                                const SizedBox(width: 8),
                                Text(
                                  'Accuracy: ${_currentPosition!.accuracy.toStringAsFixed(2)}m',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  _buildActionButton(),
                ],
              ),
            ),
    );
  }
}

extension DateTimeExtensions on DateTime {
  DateTime get dateOnly => DateTime(year, month, day);
}
