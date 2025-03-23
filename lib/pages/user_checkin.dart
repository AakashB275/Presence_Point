import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserCheckin extends StatefulWidget {
  const UserCheckin({Key? key}) : super(key: key);

  @override
  State<UserCheckin> createState() => _GeofencingMapScreenState();
}

class _GeofencingMapScreenState extends State<UserCheckin> {
  final String goMapsApiKey = 'YOUR_GO_MAPS_API_KEY';
  final MapController mapController = MapController();

  // Current user position
  LatLng? currentPosition;

  // Geofence parameters
  final List<LatLng> geofencePoints = [];
  double geofenceRadius = 100.0; // radius in meters (default)
  bool isInsideGeofence = false;

  // Check-in time tracking
  DateTime? checkInTime;
  DateTime? checkOutTime;
  Timer? durationTimer;
  Duration stayDuration = Duration.zero;
  bool isTimerActive = false;

  // Streaming position updates
  StreamSubscription<Position>? positionStream;

  // TextEditingController for radius input
  final TextEditingController radiusController = TextEditingController();

  @override
  void initState() {
    super.initState();
    radiusController.text = geofenceRadius.toString();
    _requestLocationPermission();
    _getCurrentLocation();
    _startPositionStream();
    _loadLastCheckInData();
    _loadSavedRadius();
  }

  @override
  void dispose() {
    positionStream?.cancel();
    durationTimer?.cancel();
    radiusController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedRadius() async {
    final prefs = await SharedPreferences.getInstance();
    final savedRadius = prefs.getDouble('geofence_radius');
    if (savedRadius != null) {
      setState(() {
        geofenceRadius = savedRadius;
        radiusController.text = savedRadius.toString();
      });
    }
  }

  Future<void> _saveRadius(double radius) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('geofence_radius', radius);
  }

  Future<void> _loadLastCheckInData() async {
    final prefs = await SharedPreferences.getInstance();
    final lastCheckInTimeStr = prefs.getString('last_check_in_time');

    if (lastCheckInTimeStr != null) {
      setState(() {
        checkInTime = DateTime.parse(lastCheckInTimeStr);
      });

      // If we had a check-in but no check-out, and we're loading the app again
      // Let's calculate how long it's been since the check-in
      final lastCheckOutTimeStr = prefs.getString('last_check_out_time');
      if (lastCheckOutTimeStr == null && isInsideGeofence) {
        _startDurationTimer();
      } else if (lastCheckOutTimeStr != null) {
        final checkOutTime = DateTime.parse(lastCheckOutTimeStr);
        final duration = checkOutTime.difference(checkInTime!);
        setState(() {
          stayDuration = duration;
        });
      }
    }
  }

  Future<void> _saveCheckInData() async {
    final prefs = await SharedPreferences.getInstance();
    if (checkInTime != null) {
      await prefs.setString(
          'last_check_in_time', checkInTime!.toIso8601String());
    }
    if (checkOutTime != null) {
      await prefs.setString(
          'last_check_out_time', checkOutTime!.toIso8601String());
    }
  }

  Future<void> _requestLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permissions are denied')),
        );
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Location permissions are permanently denied, we cannot request permissions.'),
        ),
      );
    }
  }

  void _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        currentPosition = LatLng(position.latitude, position.longitude);
      });

      // Center map on current position
      mapController.move(currentPosition!, 15.0);

      // Check if user is inside geofence
      _checkGeofence();
    } catch (e) {
      print('Error getting location: $e');
    }
  }

  void _startPositionStream() {
    positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters
      ),
    ).listen((Position position) {
      setState(() {
        currentPosition = LatLng(position.latitude, position.longitude);
      });

      // Check if user is inside geofence
      _checkGeofence();
    });
  }

  void _addGeofencePoint(LatLng point) {
    setState(() {
      geofencePoints.add(point);
    });
    _checkGeofence();
  }

  void _updateRadius() {
    // Parse the radius from the text field
    double? newRadius = double.tryParse(radiusController.text);
    if (newRadius != null && newRadius > 0) {
      setState(() {
        geofenceRadius = newRadius;
      });

      // Save the new radius
      _saveRadius(newRadius);

      // Re-check geofence with new radius
      _checkGeofence();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Radius updated to $newRadius meters')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid radius')),
      );
    }
  }

  void _clearGeofence() {
    setState(() {
      geofencePoints.clear();
      isInsideGeofence = false;

      // Reset check-in data when geofence is cleared
      _resetCheckInData();
    });
  }

  void _resetCheckInData() {
    durationTimer?.cancel();
    setState(() {
      checkInTime = null;
      checkOutTime = null;
      stayDuration = Duration.zero;
      isTimerActive = false;
    });
    _saveCheckInData();
  }

  void _checkGeofence() {
    if (currentPosition == null || geofencePoints.isEmpty) return;

    bool wasInsideGeofence = isInsideGeofence;

    // For a circular geofence around a single point
    if (geofencePoints.length == 1) {
      double distance = Geolocator.distanceBetween(
        currentPosition!.latitude,
        currentPosition!.longitude,
        geofencePoints[0].latitude,
        geofencePoints[0].longitude,
      );

      setState(() {
        isInsideGeofence = distance <= geofenceRadius;
      });

      // If status changed, trigger appropriate events
      if (!wasInsideGeofence && isInsideGeofence) {
        _onEnterGeofence();
      } else if (wasInsideGeofence && !isInsideGeofence) {
        _onExitGeofence();
      }
    }
    // For a polygon geofence with multiple points
    else if (geofencePoints.length > 2) {
      // Here you would use a polygon containment algorithm
      // For simplicity, we'll just check against the first point as circular
      double distance = Geolocator.distanceBetween(
        currentPosition!.latitude,
        currentPosition!.longitude,
        geofencePoints[0].latitude,
        geofencePoints[0].longitude,
      );

      setState(() {
        isInsideGeofence = distance <= geofenceRadius;
      });

      // If status changed, trigger appropriate events
      if (!wasInsideGeofence && isInsideGeofence) {
        _onEnterGeofence();
      } else if (wasInsideGeofence && !isInsideGeofence) {
        _onExitGeofence();
      }
    }
  }

  void _startDurationTimer() {
    durationTimer?.cancel();

    durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (checkInTime != null) {
        setState(() {
          stayDuration = DateTime.now().difference(checkInTime!);
          isTimerActive = true;
        });
      }
    });
  }

  void _stopDurationTimer() {
    durationTimer?.cancel();
    setState(() {
      isTimerActive = false;
    });
  }

  void _onEnterGeofence() {
    // Record check-in time
    setState(() {
      checkInTime = DateTime.now();
      checkOutTime = null;
      stayDuration = Duration.zero;
    });

    // Start the duration timer
    _startDurationTimer();

    // Save check-in data
    _saveCheckInData();

    // Show notification
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Checked in at ${_formatTime(checkInTime!)}'),
        backgroundColor: Colors.green,
      ),
    );

    // Log the geofence entry event
    _logGeofenceEvent('enter');
    _logCheckInEvent();
  }

  void _onExitGeofence() {
    // Record check-out time
    if (checkInTime != null) {
      setState(() {
        checkOutTime = DateTime.now();
        stayDuration = checkOutTime!.difference(checkInTime!);
      });

      // Stop the duration timer
      _stopDurationTimer();

      // Save check-out data
      _saveCheckInData();

      // Show notification with duration
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Checked out after ${_formatDuration(stayDuration)}'),
          backgroundColor: Colors.red,
        ),
      );

      // Log the geofence exit event
      _logGeofenceEvent('exit');
      _logCheckOutEvent();
    }
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _logGeofenceEvent(String eventType) async {
    try {
      final response = await http.post(
        Uri.parse('https://api.gomaps.example/geofence/log'),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $goMapsApiKey',
        },
        body: jsonEncode(<String, dynamic>{
          'event_type': eventType,
          'latitude': currentPosition!.latitude,
          'longitude': currentPosition!.longitude,
          'timestamp': DateTime.now().toIso8601String(),
          'user_id': 'user_123',
          'geofence_radius': geofenceRadius,
        }),
      );

      if (response.statusCode == 200) {
        print('Successfully logged geofence $eventType event');
      } else {
        print('Failed to log geofence event: ${response.body}');
      }
    } catch (e) {
      print('Error logging geofence event: $e');
    }
  }

  Future<void> _logCheckInEvent() async {
    try {
      final response = await http.post(
        Uri.parse('https://api.gomaps.example/check_in/log'),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $goMapsApiKey',
        },
        body: jsonEncode(<String, dynamic>{
          'event_type': 'check_in',
          'latitude': currentPosition!.latitude,
          'longitude': currentPosition!.longitude,
          'timestamp': checkInTime!.toIso8601String(),
          'user_id': 'user_123', // Replace with actual user ID
          'geofence_id':
              'geofence_${geofencePoints.first.latitude}_${geofencePoints.first.longitude}',
          'geofence_radius': geofenceRadius,
        }),
      );

      if (response.statusCode == 200) {
        print('Successfully logged check-in event');
      } else {
        print('Failed to log check-in event: ${response.body}');
      }
    } catch (e) {
      print('Error logging check-in event: $e');
    }
  }

  Future<void> _logCheckOutEvent() async {
    if (checkInTime == null || checkOutTime == null) return;

    try {
      final response = await http.post(
        Uri.parse('https://api.gomaps.example/check_out/log'),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $goMapsApiKey',
        },
        body: jsonEncode(<String, dynamic>{
          'event_type': 'check_out',
          'latitude': currentPosition!.latitude,
          'longitude': currentPosition!.longitude,
          'check_in_timestamp': checkInTime!.toIso8601String(),
          'check_out_timestamp': checkOutTime!.toIso8601String(),
          'duration_seconds': stayDuration.inSeconds,
          'user_id': 'user_123', // Replace with actual user ID
          'geofence_id':
              'geofence_${geofencePoints.first.latitude}_${geofencePoints.first.longitude}',
          'geofence_radius': geofenceRadius,
        }),
      );

      if (response.statusCode == 200) {
        print('Successfully logged check-out event');
      } else {
        print('Failed to log check-out event: ${response.body}');
      }
    } catch (e) {
      print('Error logging check-out event: $e');
    }
  }

  void _showRadiusDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Geofence Radius'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: radiusController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Radius (meters)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Current radius: ${geofenceRadius.toStringAsFixed(1)} meters',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _updateRadius();
              Navigator.pop(context);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Geofencing Check-in'),
        actions: [
          // Radius setting button
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Set Radius',
            onPressed: _showRadiusDialog,
          ),
          // Clear geofence button
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: 'Clear Geofence',
            onPressed: _clearGeofence,
          ),
        ],
      ),
      body: Column(
        children: [
          // Check-in information card
          if (checkInTime != null)
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    'Check-in Time: ${_formatTime(checkInTime!)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (isTimerActive)
                    Text(
                      'Duration: ${_formatDuration(stayDuration)}',
                      style: const TextStyle(fontSize: 16),
                    )
                  else if (checkOutTime != null)
                    Column(
                      children: [
                        Text(
                          'Check-out Time: ${_formatTime(checkOutTime!)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Total Duration: ${_formatDuration(stayDuration)}',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                ],
              ),
            ),

          // Radius information chip
          if (geofencePoints.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Chip(
                    label:
                        Text('Radius: ${geofenceRadius.toStringAsFixed(1)}m'),
                    avatar: const Icon(Icons.radar, size: 16),
                    backgroundColor: Colors.blue.shade100,
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),

          // Map takes remaining space
          Expanded(
            child: currentPosition == null
                ? const Center(child: CircularProgressIndicator())
                : FlutterMap(
                    mapController: mapController,
                    options: MapOptions(
                      center: currentPosition!,
                      zoom: 15.0,
                      onTap: (_, point) => _addGeofencePoint(point),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.app',
                      ),
                      // Draw geofence points
                      MarkerLayer(
                        markers: [
                          // Current position marker only
                          Marker(
                            point: currentPosition!,
                            width: 80,
                            height: 80,
                            builder: (context) => Container(
                              child: const Icon(
                                Icons.location_on,
                                color: Colors.blue,
                                size: 40,
                              ),
                            ),
                          ),
                          // Remove the geofencePoints markers
                        ],
                      ),
                      // Draw geofence circle
                      if (geofencePoints.isNotEmpty)
                        CircleLayer(
                          circles: [
                            CircleMarker(
                              point: geofencePoints.first,
                              radius: geofenceRadius,
                              color: Colors.red.withOpacity(0.3),
                              borderColor: Colors.red,
                              borderStrokeWidth: 2,
                            ),
                          ],
                        ),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _getCurrentLocation,
        child: const Icon(Icons.my_location),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        color: isInsideGeofence ? Colors.green : Colors.red,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              isInsideGeofence ? 'Inside Geofence' : 'Outside Geofence',
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
            if (isInsideGeofence && checkInTime != null && isTimerActive)
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: Text(
                  '(${_formatDuration(stayDuration)})',
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
