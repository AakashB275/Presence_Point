import 'dart:async';
import 'package:flutter/material.dart';
import 'package:presence_point_2/pages/admin_home_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/geofencing_service.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({Key? key}) : super(key: key);

  @override
  _AttendancePageState createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  final GeofencingService _geofencingService = GeofencingService();
  final supabase = Supabase.instance.client;

  Position? _currentPosition;
  List<Map<String, dynamic>> _organizationLocations = [];
  Set<Circle> _geofenceCircles = {};
  bool _isLoading = true;
  Timer? _uiUpdateTimer;
  String _formattedWorkDuration = '00:00:00';

  // Controller for Google Maps
  final Completer<GoogleMapController> _mapController = Completer();
  static const CameraPosition _defaultLocation = CameraPosition(
    target: LatLng(37.7749, -122.4194), // Default to San Francisco
    zoom: 14.0,
  );

  @override
  void initState() {
    super.initState();
    _initializeGeofencing();
    _fetchOrganizationLocations();
    _getCurrentLocation();

    // Register callback for status changes
    _geofencingService.onStatusChange = () {
      if (mounted) {
        setState(() {});
      }
    };

    // Update UI every second to reflect current duration
    _uiUpdateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _geofencingService.isCheckedIn) {
        setState(() {
          Duration duration = _geofencingService.totalDurationWorked;
          _formattedWorkDuration = _formatDuration(duration);
        });
      }
    });
  }

  Future<void> _initializeGeofencing() async {
    try {
      await _geofencingService.initialize();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _fetchOrganizationLocations() async {
    try {
      final response = await supabase.from('organization_locations').select();

      if (mounted) {
        setState(() {
          _organizationLocations = List<Map<String, dynamic>>.from(response);
          _updateGeofenceCircles();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching locations: ${e.toString()}')),
        );
      }
    }
  }

  // Navigate to Admin/Employee page
  void _navigateToAdminEmployeePage() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        // Replace AdminEmployeePage with your actual page class
        builder: (context) => AdminHomePage(),
      ),
    );
  }

  void _updateGeofenceCircles() {
    Set<Circle> circles = {};

    // If organization locations are empty, use the default from geofencing service
    if (_organizationLocations.isEmpty) {
      circles.add(
        Circle(
          circleId: const CircleId("default"),
          center: const LatLng(
              37.7749, -122.4194), // Default from GeofencingService
          radius: 100.0, // Default radius from GeofencingService
          fillColor: Colors.blue.withOpacity(0.3),
          strokeColor: Colors.blue,
          strokeWidth: 2,
        ),
      );
    } else {
      for (var location in _organizationLocations) {
        circles.add(
          Circle(
            circleId: CircleId(location['id'].toString()),
            center: LatLng(location['latitude'], location['longitude']),
            radius: location['radius'],
            fillColor: Colors.blue.withOpacity(0.3),
            strokeColor: Colors.blue,
            strokeWidth: 2,
          ),
        );
      }
    }

    setState(() {
      _geofenceCircles = circles;
    });
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
      }

      _animateToCurrentLocation();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting location: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _animateToCurrentLocation() async {
    if (_currentPosition == null) return;

    final GoogleMapController controller = await _mapController.future;
    controller.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(
        target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        zoom: 15.0,
      ),
    ));
  }

  String _formatDuration(Duration duration) {
    int hours = duration.inHours;
    int minutes = duration.inMinutes.remainder(60);
    int seconds = duration.inSeconds.remainder(60);
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _uiUpdateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
        canPop: false,
        onPopInvoked: (didPop) {
          if (didPop) return;

          // Navigate to employee/admin page on back button press
          _navigateToAdminEmployeePage();
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Attendance Tracker'),
            actions: [
              IconButton(
                icon: const Icon(Icons.history),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AttendanceHistoryPage(),
                    ),
                  );
                },
              ),
            ],
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    // Status card
                    Card(
                      margin: const EdgeInsets.all(16.0),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Current Status:',
                                  style: TextStyle(
                                    fontSize: 18.0,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12.0,
                                    vertical: 6.0,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _geofencingService.isCheckedIn
                                        ? Colors.green
                                        : Colors.red,
                                    borderRadius: BorderRadius.circular(20.0),
                                  ),
                                  child: Text(
                                    _geofencingService.isCheckedIn
                                        ? 'Checked In'
                                        : 'Checked Out',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16.0),
                            if (_geofencingService.isCheckedIn) ...[
                              const Text(
                                'Time Worked Today:',
                                style: TextStyle(fontSize: 16.0),
                              ),
                              const SizedBox(height: 8.0),
                              Text(
                                _formattedWorkDuration,
                                style: const TextStyle(
                                  fontSize: 36.0,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    // Map view
                    Expanded(
                      child: GoogleMap(
                        initialCameraPosition: _defaultLocation,
                        myLocationEnabled: true,
                        myLocationButtonEnabled: true,
                        mapType: MapType.normal,
                        zoomControlsEnabled: true,
                        circles: _geofenceCircles,
                        onMapCreated: (GoogleMapController controller) {
                          _mapController.complete(controller);
                          _animateToCurrentLocation();
                        },
                      ),
                    ),
                  ],
                ),
          floatingActionButton: FloatingActionButton(
            onPressed: _getCurrentLocation,
            child: const Icon(Icons.my_location),
          ),
        ));
  }
}

class AttendanceHistoryPage extends StatefulWidget {
  const AttendanceHistoryPage({Key? key}) : super(key: key);

  @override
  _AttendanceHistoryPageState createState() => _AttendanceHistoryPageState();
}

class _AttendanceHistoryPageState extends State<AttendanceHistoryPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _attendanceRecords = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAttendanceHistory();
  }

  Future<void> _fetchAttendanceHistory() async {
    try {
      final response = await supabase
          .from('attendance')
          .select()
          .eq('user_id', supabase.auth.currentUser!.id)
          .order('check_in_time', ascending: false);

      setState(() {
        _attendanceRecords = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Error fetching attendance history: ${e.toString()}')),
      );
    }
  }

  String _formatDuration(int seconds) {
    Duration duration = Duration(seconds: seconds);
    int hours = duration.inHours;
    int minutes = duration.inMinutes.remainder(60);
    return '${hours}h ${minutes}m';
  }

  String _formatDate(String dateString) {
    DateTime date = DateTime.parse(dateString);
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatTime(String dateString) {
    DateTime date = DateTime.parse(dateString);
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance History'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _attendanceRecords.isEmpty
              ? const Center(child: Text('No attendance records found'))
              : ListView.builder(
                  itemCount: _attendanceRecords.length,
                  itemBuilder: (context, index) {
                    final record = _attendanceRecords[index];
                    final bool isCheckedOut = record['status'] == 'checked_out';

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      child: ListTile(
                        title: Text(
                          'Date: ${_formatDate(record['check_in_time'])}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4.0),
                            Text(
                                'Check-in: ${_formatTime(record['check_in_time'])}'),
                            if (isCheckedOut) ...[
                              Text(
                                  'Check-out: ${_formatTime(record['check_out_time'])}'),
                              Text(
                                  'Hours worked: ${_formatDuration(record['total_seconds_worked'])}'),
                            ] else ...[
                              const Text(
                                'Status: Currently Checked In',
                                style: TextStyle(color: Colors.green),
                              ),
                            ],
                          ],
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.all(8.0),
                          decoration: BoxDecoration(
                            color: isCheckedOut
                                ? Colors.grey[300]
                                : Colors.green[100],
                            borderRadius: BorderRadius.circular(4.0),
                          ),
                          child: Text(
                            isCheckedOut ? 'Completed' : 'Active',
                            style: TextStyle(
                              color: isCheckedOut
                                  ? Colors.black
                                  : Colors.green[800],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _fetchAttendanceHistory,
        child: const Icon(Icons.refresh),
      ),
    );
  }
}
