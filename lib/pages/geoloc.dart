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
  _GeoAttendancePageState createState() => _GeoAttendancePageState();
}

class _GeoAttendancePageState extends State<GeoAttendancePage> {
  final _supabase = Supabase.instance.client;
  final _service = FlutterBackgroundService();
  final _notificationsPlugin = FlutterLocalNotificationsPlugin();

  // Database models
  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _orgData;
  Map<String, dynamic>? _currentAttendance;

  // State variables
  bool _isLoading = true;
  bool _isCheckedIn = false;
  bool _isBackgroundServiceRunning = false;
  String _statusMessage = 'Initializing...';
  DateTime? _checkInTime;
  Position? _lastPosition;
  double _distanceToOffice = 0.0;
  Timer? _locationTimer;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      await _requestPermissions();
      await _initializeNotifications();
      await _initializeBackgroundService();
      await _loadUserData();

      if (_userData != null) {
        await _loadOrganizationData();
        await _checkCurrentAttendanceStatus();
        _startLocationTracking();
      }
    } catch (e) {
      _handleError('Initialization failed', e);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ========================
  // Database Operations
  // ========================

  Future<void> _loadUserData() async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) throw Exception('No authenticated user');

      final response = await _supabase
          .from('users')
          .select()
          .eq('auth_user_id', currentUser.id)
          .single()
          .timeout(const Duration(seconds: 10));

      setState(() {
        _userData = response;
      });
    } catch (e) {
      throw Exception('Failed to load user data: $e');
    }
  }

  Future<void> _loadOrganizationData() async {
    try {
      if (_userData == null || _userData!['org_id'] == null) {
        throw Exception('User organization not found');
      }

      final response = await _supabase
          .from('organizations')
          .select()
          .eq('org_id', _userData!['org_id'])
          .single()
          .timeout(const Duration(seconds: 10));

      setState(() => _orgData = response);
    } catch (e) {
      throw Exception('Failed to load organization data: $e');
    }
  }

  Future<void> _checkCurrentAttendanceStatus() async {
    try {
      if (_userData == null) return;

      final now = DateTime.now().toUtc();
      final today = DateTime(now.year, now.month, now.day);

      final response = await _supabase
          .from('attendance')
          .select()
          .eq('user_id', _userData!['user_id'])
          .gte('check_in_time', today.toIso8601String())
          .filter('check_out_time', 'is', 'null')
          .maybeSingle()
          .timeout(const Duration(seconds: 10));

      if (response != null) {
        setState(() {
          _currentAttendance = response;
          _isCheckedIn = true;
          _checkInTime = DateTime.parse(response['check_in_time']);
          _statusMessage =
              'Currently checked in since ${DateFormat.Hm().format(_checkInTime!)}';
        });

        if (!_isBackgroundServiceRunning) {
          await _service.startService();
          setState(() => _isBackgroundServiceRunning = true);
        }
      }
    } catch (e) {
      debugPrint('Error checking attendance status: $e');
    }
  }

  Future<void> _sendCheckInToDatabase(Position position) async {
    if (_userData == null || _orgData == null) return;

    try {
      final now = DateTime.now().toUtc();
      final point = 'POINT(${position.longitude} ${position.latitude})';

      final response = await _supabase
          .from('attendance')
          .insert({
            'user_id': _userData!['user_id'],
            'org_id': _orgData!['org_id'],
            'check_in_time': now.toIso8601String(),
            'check_in_location': point,
            'geofence_radius': _orgData!['geofencing_radius'],
          })
          .select()
          .single()
          .timeout(const Duration(seconds: 10));

      setState(() {
        _currentAttendance = response;
        _isCheckedIn = true;
        _checkInTime = now;
        _statusMessage = 'Checked in at ${DateFormat.Hm().format(now)}';
      });

      await _service.startService();
      setState(() => _isBackgroundServiceRunning = true);
      _startLocationTracking();

      _showNotification(_notificationsPlugin, 'Check-In Successful',
          'You have been checked in successfully');
    } catch (e) {
      throw Exception('Check-in failed: $e');
    }
  }

  Future<void> _sendCheckOutToDatabase(Position position) async {
    if (_userData == null || _currentAttendance == null) return;

    try {
      final now = DateTime.now().toUtc();
      final point = 'POINT(${position.longitude} ${position.latitude})';
      final checkInTime = DateTime.parse(_currentAttendance!['check_in_time']);
      final hoursWorked = now.difference(checkInTime).inMinutes / 60.0;

      await _supabase
          .from('attendance')
          .update({
            'check_out_time': now.toIso8601String(),
            'check_out_location': point,
            'total_hours': hoursWorked,
          })
          .eq('id', _currentAttendance!['id'])
          .timeout(const Duration(seconds: 10));

      setState(() {
        _isCheckedIn = false;
        _checkInTime = null;
        _currentAttendance = null;
        _statusMessage =
            'Checked out. Worked ${hoursWorked.toStringAsFixed(2)} hours';
      });

      _service.invoke('stopService');
      setState(() => _isBackgroundServiceRunning = false);
      _startLocationTracking();

      _showNotification(_notificationsPlugin, 'Check-Out Successful',
          'You have been checked out successfully');
    } catch (e) {
      throw Exception('Check-out failed: $e');
    }
  }

  // ========================
  // Location Services
  // ========================

  Future<void> _updateLocation() async {
    if (!mounted) return;

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy:
            _isCheckedIn ? LocationAccuracy.high : LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 15),
      );

      if (!mounted) return;

      setState(() => _lastPosition = position);

      if (_orgData != null) {
        final distance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          _orgData!['latitude'],
          _orgData!['longitude'],
        );

        setState(() {
          _distanceToOffice = distance;
          _statusMessage = _isCheckedIn
              ? 'Checked in (${_formatDuration(DateTime.now().difference(_checkInTime!))})'
              : distance <= _orgData!['geofencing_radius']
                  ? 'Within office area (${distance.toStringAsFixed(0)}m)'
                  : 'Outside office area (${distance.toStringAsFixed(0)}m away)';
        });

        if (_isCheckedIn) {
          _service.invoke('updateLocation', {
            'latitude': position.latitude,
            'longitude': position.longitude,
            'orgId': _orgData!['org_id'],
            'userId': _userData!['user_id'],
            'radius': _orgData!['geofencing_radius'],
            'orgLat': _orgData!['latitude'],
            'orgLng': _orgData!['longitude'],
            'isCheckedIn': _isCheckedIn,
          });

          // Auto check-out if left the geofence area
          if (distance > _orgData!['geofencing_radius']) {
            await _performCheckOut();
          }
        }
      }
    } catch (e) {
      debugPrint('Location update failed: $e');
    }
  }

  // ========================
  // User Actions
  // ========================

  Future<void> _performCheckIn() async {
    if (!mounted || _lastPosition == null || _orgData == null) return;

    final radius = _orgData!['geofencing_radius'];
    if (_distanceToOffice > radius) {
      _showError(
          'You must be within ${radius.toStringAsFixed(0)}m of the office to check in');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _sendCheckInToDatabase(_lastPosition!);
      _showSnackBar('Successfully checked in');
    } catch (e) {
      _handleError('Check-in failed', e);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _performCheckOut() async {
    if (!mounted || _lastPosition == null) return;

    setState(() => _isLoading = true);

    try {
      await _sendCheckOutToDatabase(_lastPosition!);
      _showSnackBar('Successfully checked out');
    } catch (e) {
      _handleError('Check-out failed', e);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ========================
  // Helper Methods
  // ========================

  Future<void> _requestPermissions() async {
    final status = await Permission.location.request();
    if (!status.isGranted) {
      throw Exception('Location permission not granted');
    }

    final notificationStatus = await Permission.notification.request();
    if (!notificationStatus.isGranted) {
      debugPrint('Notification permission not granted');
    }
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _notificationsPlugin.initialize(initializationSettings);
  }

  Future<void> _initializeBackgroundService() async {
    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onBackgroundServiceStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'geo_attendance_channel',
        initialNotificationTitle: 'Attendance Tracking',
        initialNotificationContent: 'Initializing tracking service',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: _onBackgroundServiceStart,
        onBackground: _onIosBackground, // Placeholder function added below
      ),
    );
  }

  @pragma('vm:entry-point')
  static Future<bool> _onIosBackground(ServiceInstance service) async {
    // Placeholder implementation for iOS background handling
    return true;
  }

  @pragma('vm:entry-point')
  static Future<void> _onBackgroundServiceStart(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();

    final supabase = Supabase.instance.client;
    final notificationsPlugin = FlutterLocalNotificationsPlugin();
    await notificationsPlugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );

    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: "Attendance Tracking",
        content: "Tracking your location for attendance",
      );
    }

    service.on('stopService').listen((event) {
      service.stopSelf();
    });

    service.on('updateLocation').listen((event) async {
      if (event is Map) {
        final lat = event?['latitude'] as double;
        final lng = event?['longitude'] as double;
        final userId = event?['userId'] as int;
        final radius = event?['radius'] as double;
        final orgLat = event?['orgLat'] as double;
        final orgLng = event?['orgLng'] as double;
        final isCheckedIn = event?['isCheckedIn'] as bool;

        final distance = Geolocator.distanceBetween(lat, lng, orgLat, orgLng);

        if (isCheckedIn && distance > radius) {
          try {
            final now = DateTime.now().toUtc();
            final today = DateTime(now.year, now.month, now.day);

            final response = await supabase
                .from('attendance')
                .select()
                .eq('user_id', userId)
                .gte('check_in_time', today.toIso8601String())
                .filter('check_out_time', 'is', 'null')
                .maybeSingle();

            if (response != null) {
              await supabase.from('attendance').update({
                'check_out_time': now.toIso8601String(),
                'check_out_location': 'POINT($lng $lat)',
                'total_hours': now
                        .difference(DateTime.parse(response['check_in_time']))
                        .inMinutes /
                    60.0,
              }).eq('id', response['id']);
            }

            await _showNotification(
              notificationsPlugin,
              'Auto Check-Out',
              'You have been automatically checked out as you left the office area.',
            );
          } catch (e) {
            debugPrint('Auto check-out failed: $e');
          }
        }

        await notificationsPlugin.show(
          888,
          'Attendance Tracking',
          isCheckedIn
              ? 'Checked in: ${distance.toStringAsFixed(0)}m from office'
              : 'Not checked in',
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'geo_attendance_channel',
              'Attendance Tracking',
              importance: Importance.low,
              priority: Priority.low,
              ongoing: true,
            ),
          ),
        );
      }
    });
  }

  void _startLocationTracking() {
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(
      Duration(minutes: _isCheckedIn ? 1 : 5),
      (timer) => _updateLocation(),
    );
    _updateLocation();
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return '${hours}h ${minutes}m';
  }

  static Future<void> _showNotification(
      FlutterLocalNotificationsPlugin notificationsPlugin,
      String title,
      String body) async {
    const androidDetails = AndroidNotificationDetails(
      'geo_attendance_actions',
      'Attendance Actions',
      importance: Importance.high,
      priority: Priority.high,
    );

    await notificationsPlugin.show(
      0,
      title,
      body,
      const NotificationDetails(android: androidDetails),
    );
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  void _handleError(String contextMessage, dynamic error) {
    final errorMessage = '$contextMessage: ${error.toString()}';
    debugPrint(errorMessage);
    if (mounted) {
      setState(() => _statusMessage = errorMessage);
      _showSnackBar(errorMessage);
    }
  }

  void _showError(String error) {
    if (mounted) {
      setState(() => _statusMessage = error);
      _showSnackBar(error);
    }
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    if (!_isCheckedIn && _isBackgroundServiceRunning) {
      _service.invoke('stopService');
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Geo Attendance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _updateLocation,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_userData == null || _orgData == null) {
      return Center(child: Text(_statusMessage));
    }

    final radius = _orgData!['geofencing_radius'];
    final progressValue = _distanceToOffice / radius;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _orgData!['org_name'] ?? 'Organization',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Welcome, ${_userData!['name'] ?? 'User'}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text('Geofence radius: ${radius.toStringAsFixed(0)}m'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Status',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(_statusMessage),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: progressValue > 1 ? 1 : progressValue,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _distanceToOffice <= radius ? Colors.green : Colors.red,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Distance: ${_distanceToOffice.toStringAsFixed(0)}m / ${radius.toStringAsFixed(0)}m',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _distanceToOffice <= radius
                          ? Colors.green
                          : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: _isCheckedIn
                ? _performCheckOut
                : _distanceToOffice <= radius
                    ? _performCheckIn
                    : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isCheckedIn ? Colors.red : Colors.green,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text(
              _isCheckedIn ? 'CHECK OUT' : 'CHECK IN',
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
    );
  }
}
