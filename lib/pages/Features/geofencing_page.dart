import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:presence_point_2/pages/admin_home_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:presence_point_2/widgets/CustomAppBar.dart';
import 'package:presence_point_2/widgets/CustomDrawer.dart';

class Organization {
  final String orgId;
  final String orgName;
  final String orgCode;
  final double latitude;
  final double longitude;
  final double geofencingRadius;

  Organization({
    required this.orgId,
    required this.orgName,
    required this.orgCode,
    required this.latitude,
    required this.longitude,
    required this.geofencingRadius,
  });

  factory Organization.fromJson(Map<String, dynamic> json) {
    return Organization(
      orgId: json['org_id'].toString(),
      orgName: json['org_name'] ?? 'Unknown Organization',
      orgCode: json['org_code']?.toString() ?? '',
      latitude: json['latitude']?.toDouble() ?? 0.0,
      longitude: json['longitude']?.toDouble() ?? 0.0,
      geofencingRadius: json['geofencing_radius']?.toDouble() ?? 100.0,
    );
  }
}

class GeofencingPage extends StatefulWidget {
  const GeofencingPage({super.key});

  @override
  State<GeofencingPage> createState() => _GeofencingPageState();
}

class _GeofencingPageState extends State<GeofencingPage> {
  final _supabase = Supabase.instance.client;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _isInGeofence = false;
  String _status = "Loading organization data...";
  DateTime? _checkInTime;
  Timer? _durationTimer;
  int _durationInSeconds = 0;
  StreamSubscription<Position>? _positionStream;
  Position? _currentPosition;
  String? _currentAttendanceId;
  Organization? _organization;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOrganizationData();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _durationTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadOrganizationData() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        setState(() {
          _status = "User not authenticated. Please login.";
          _isLoading = false;
        });
        return;
      }

      final userData = await _supabase
          .from('user')
          .select('org_id')
          .eq('id', userId)
          .single();

      final orgId = userData['org_id'].toString();

      final response = await _supabase
          .from('organization')
          .select()
          .eq('org_id', orgId)
          .single();

      setState(() {
        _organization = Organization.fromJson(response);
        _status = "Organization data loaded. Checking location...";
        _isLoading = false;
      });

      _requestLocationPermission();
    } catch (e) {
      setState(() {
        _status = "Error loading organization data: $e";
        _isLoading = false;
      });
      print('Error loading organization: $e');
    }
  }

  Future<void> _requestLocationPermission() async {
    if (_organization == null) {
      setState(() {
        _status = 'Organization data not available.';
      });
      return;
    }

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _status = 'Location services are disabled. Please enable them.';
      });
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _status = 'Location permissions are denied.';
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _status = 'Location permissions are permanently denied.';
      });
      return;
    }

    _startLocationTracking();
  }

  void _startLocationTracking() {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    _positionStream =
        Geolocator.getPositionStream(locationSettings: locationSettings)
            .listen((Position position) {
      _currentPosition = position;
      _checkGeofence(position);
    });
  }

  void _navigateBack() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => AdminHomePage()),
    );
  }

  void _checkGeofence(Position position) {
    if (_organization == null) return;

    double distance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      _organization!.latitude,
      _organization!.longitude,
    );

    bool wasInGeofence = _isInGeofence;
    _isInGeofence = distance <= _organization!.geofencingRadius;

    if (_isInGeofence && !wasInGeofence) {
      _checkIn();
    } else if (!_isInGeofence && wasInGeofence) {
      _checkOut();
    }

    setState(() {
      _status = _isInGeofence
          ? "Inside ${_organization!.orgName} (${distance.toStringAsFixed(2)}m)"
          : "Outside ${_organization!.orgName} (${distance.toStringAsFixed(2)}m)";
    });
  }

  void _checkIn() {
    _checkInTime = DateTime.now();
    _durationInSeconds = 0;

    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _durationInSeconds++;
      });
    });

    _recordCheckInToSupabase();
  }

  void _checkOut() {
    _durationTimer?.cancel();
    _durationTimer = null;

    if (_checkInTime != null) {
      _recordCheckOutToSupabase();
      _checkInTime = null;
      // Removed the automatic navigation after checkout
    }
  }

  Future<void> _recordCheckInToSupabase() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await _supabase.from('attendance').insert({
        'user_id': userId,
        'org_id': _organization!.orgId,
        'check_in_time': _checkInTime!.toIso8601String(),
        'date': DateFormat('yyyy-MM-dd').format(_checkInTime!),
        'check_in_location':
            'POINT(${_currentPosition?.longitude} ${_currentPosition?.latitude})',
      }).select();

      if (response.isNotEmpty) {
        setState(() {
          _currentAttendanceId = response[0]['id'].toString();
        });
        print('Check-in recorded successfully. ID: $_currentAttendanceId');
      }
    } catch (e) {
      print('Error recording check-in: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to record check-in: $e')),
      );
    }
  }

  Future<void> _recordCheckOutToSupabase() async {
    try {
      if (_currentAttendanceId == null) {
        print('No active check-in to update');
        return;
      }

      final checkOutTime = DateTime.now();
      final durationHours =
          checkOutTime.difference(_checkInTime!).inSeconds / 3600.0;

      await _supabase.from('attendance').update({
        'check_out_time': checkOutTime.toIso8601String(),
        'check_out_location':
            'POINT(${_currentPosition?.longitude} ${_currentPosition?.latitude})',
        'total_hours': durationHours,
      }).eq('id', _currentAttendanceId!);

      print('Check-out recorded successfully for ID: $_currentAttendanceId');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Check-out recorded successfully')),
      );

      setState(() {
        _currentAttendanceId = null;
      });
    } catch (e) {
      print('Error recording check-out: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to record check-out: $e')),
      );
    }
  }

  String _formatDuration() {
    int hours = _durationInSeconds ~/ 3600;
    int minutes = (_durationInSeconds % 3600) ~/ 60;
    int seconds = _durationInSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _navigateBack();
        return false;
      },
      child: Scaffold(
        appBar: CustomAppBar(
          title: "Presence Point",
          scaffoldKey: _scaffoldKey,
          showBackButton: true,
          onBackPressed: _navigateBack,
        ),
        drawer: CustomDrawer(),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_organization != null) ...[
                      Text(
                        _organization!.orgName,
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Geofence Radius: ${_organization!.geofencingRadius}m',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 20),
                    ],
                    Icon(
                      _isInGeofence ? Icons.location_on : Icons.location_off,
                      size: 80,
                      color: _isInGeofence ? Colors.green : Colors.red,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _status,
                      style: const TextStyle(fontSize: 18),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    if (_isInGeofence && _checkInTime != null) ...[
                      Text(
                        'Checked in at: ${DateFormat('HH:mm:ss').format(_checkInTime!)}',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Duration: ${_formatDuration()}',
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ],
                    const SizedBox(height: 40),
                    ElevatedButton(
                      onPressed: _currentPosition != null
                          ? () => _checkGeofence(_currentPosition!)
                          : null,
                      child: const Text('Refresh Location'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
