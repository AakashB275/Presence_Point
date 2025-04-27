import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:presence_point_2/pages/admin_home_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:presence_point_2/widgets/CustomAppBar.dart';
import 'package:presence_point_2/widgets/CustomDrawer.dart';

class Organization {
  final int orgId;
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
      orgId: json['org_id'],
      orgName: json['org_name'] ?? 'Unknown Organization',
      orgCode: json['org_code']?.toString() ?? '',
      latitude: json['latitude'] ?? 0.0,
      longitude: json['longitude'] ?? 0.0,
      geofencingRadius: json['geofencing_radius'] ?? 100.0,
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
  int? _currentAttendanceId;
  Organization? _organization;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOrganizationData();

    // Set up back button handling
    SystemChannels.platform
        .invokeMethod<void>('SystemNavigator.setSystemUIOverlayStyle', null);
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _durationTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadOrganizationData() async {
    try {
      // Get current user ID
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        setState(() {
          _status = "User not authenticated. Please login.";
          _isLoading = false;
        });
        return;
      }

      // Fetch user data to get their organization
      final userData = await _supabase
          .from('user')
          .select('created_at, org_id')
          .eq('id', userId)
          .single();

      final int orgId = userData['org_id'];

      // Fetch the organization data
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

      // Now that we have org data, request location permissions
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

    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _status =
            'Location services are disabled. Please enable location services.';
      });
      return;
    }

    // Check location permission
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _status = 'Location permissions are denied. Cannot use geofencing.';
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _status =
            'Location permissions are permanently denied. Please enable in settings.';
      });
      return;
    }

    // Start tracking location
    _startLocationTracking();
  }

  void _startLocationTracking() {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Update every 10 meters
    );

    _positionStream =
        Geolocator.getPositionStream(locationSettings: locationSettings)
            .listen((Position position) {
      _currentPosition = position;
      _checkGeofence(position);
    });
  }

  // Navigate to Admin/Employee page
  void _navigateToAdminEmployeePage() {
    if (!mounted) return;

    // Forcefully navigate with replacement to prevent back button from exiting app
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => AdminHomePage()),
        (route) => false, // Remove all routes from stack
      );
    });
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

    // User just entered geofence
    if (_isInGeofence && !wasInGeofence) {
      _checkIn();
    }
    // User just exited geofence
    else if (!_isInGeofence && wasInGeofence) {
      _checkOut();
    }

    setState(() {
      _status = _isInGeofence
          ? "You are inside ${_organization!.orgName} boundary (${distance.toStringAsFixed(2)}m from center)"
          : "You are outside ${_organization!.orgName} boundary (${distance.toStringAsFixed(2)}m from center)";
    });
  }

  void _checkIn() {
    _checkInTime = DateTime.now();
    _durationInSeconds = 0;

    // Start timer to measure duration inside geofence
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _durationInSeconds++;
      });
    });

    // Record check-in to Supabase
    _recordCheckInToSupabase();
  }

  void _checkOut() {
    _durationTimer?.cancel();
    _durationTimer = null;

    // Record check-out/duration to Supabase
    if (_checkInTime != null) {
      _recordCheckOutToSupabase();
      _checkInTime = null;
    }
  }

  Future<void> _recordCheckInToSupabase() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        print('User not authenticated');
        return;
      }

      final response = await _supabase.from('attendance').insert({
        'user_id': userId,
        'org_id': _organization!.orgId, // Include the org_id
        'check_in_time': _checkInTime!.toIso8601String(),
        'check_in_location':
            '${_currentPosition?.latitude},${_currentPosition?.longitude}',
      }).select();

      if (response.isNotEmpty) {
        _currentAttendanceId = response[0]['id'];
        print('Check-in recorded successfully with ID: $_currentAttendanceId');
      }
    } catch (e) {
      print('Error recording check-in: $e');
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
            '${_currentPosition?.latitude},${_currentPosition?.longitude}',
        'total_hours': durationHours,
      }).eq('id', _currentAttendanceId as Object);

      print(
          'Check-out recorded successfully. Duration: ${durationHours.toStringAsFixed(2)} hours');
      _currentAttendanceId = null;
    } catch (e) {
      print('Error recording check-out: $e');
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
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _navigateToAdminEmployeePage();
        });
        return false;
      },
      child: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: const Text("Presence Point"),
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed:
                _navigateToAdminEmployeePage, // Handle back button in app bar explicitly
          ),
        ),
        drawer: CustomDrawer(),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Organization information
                    if (_organization != null) ...[
                      Text(
                        _organization!.orgName,
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        'Organization Code: ${_organization!.orgCode}',
                        style: const TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        'Geofence Radius: ${_organization!.geofencingRadius.toStringAsFixed(1)} meters',
                        style: const TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Status icon
                    Icon(
                      _isInGeofence ? Icons.location_on : Icons.location_off,
                      size: 80,
                      color: _isInGeofence ? Colors.green : Colors.red,
                    ),
                    const SizedBox(height: 20),

                    // Status text
                    Text(
                      _status,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 18),
                    ),
                    const SizedBox(height: 20),

                    // Check-in status
                    if (_isInGeofence) ...[
                      const Text(
                        'Checked in at:',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        _checkInTime != null
                            ? DateFormat('yyyy-MM-dd HH:mm:ss')
                                .format(_checkInTime!)
                            : 'Not checked in yet',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Duration in organization:',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        _formatDuration(),
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ],

                    const SizedBox(height: 40),

                    // Manual check buttons (for testing)
                    ElevatedButton(
                      onPressed: _currentPosition != null
                          ? () => _checkGeofence(_currentPosition!)
                          : null,
                      child: const Text('Refresh Location Status'),
                    ),

                    const SizedBox(height: 20),

                    // Manual check-in/check-out buttons (for backup)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: _isInGeofence && _checkInTime == null
                              ? _checkIn
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            disabledBackgroundColor: Colors.grey,
                          ),
                          child: const Text('Manual Check-In'),
                        ),
                        ElevatedButton(
                          onPressed: _isInGeofence && _checkInTime != null
                              ? _checkOut
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            disabledBackgroundColor: Colors.grey,
                          ),
                          child: const Text('Manual Check-Out'),
                        ),
                      ],
                    ),

                    // Extra back button for testing
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _navigateToAdminEmployeePage,
                      child: const Text('Back to Admin Home'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
