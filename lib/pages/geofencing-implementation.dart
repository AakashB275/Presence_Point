import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class GeofencingMapScreen extends StatefulWidget {
  const GeofencingMapScreen({super.key});

  @override
  State<GeofencingMapScreen> createState() => _GeofencingMapScreenState();
}

class _GeofencingMapScreenState extends State<GeofencingMapScreen> {
  final String goMapsApiKey = 'YOUR_GO_MAPS_API_KEY';
  final MapController mapController = MapController();

  // Current user position
  LatLng? currentPosition;

  // Geofence parameters
  final List<LatLng> geofencePoints = [];
  double geofenceRadius = 100.0; // radius in meters
  bool isInsideGeofence = false;
  bool isGeofenceActive = false;

  // Streaming position updates
  StreamSubscription<Position>? positionStream;

  // Controller for radius input
  final TextEditingController radiusController =
      TextEditingController(text: '200.0');

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
    _getCurrentLocation();
    _startPositionStream();
  }

  @override
  void dispose() {
    positionStream?.cancel();
    radiusController.dispose();
    super.dispose();
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
    // For simplicity, we'll just allow a single point for circular geofence
    setState(() {
      geofencePoints.clear(); // Clear existing points
      geofencePoints.add(point);
      isGeofenceActive = true;
    });

    // Show a confirmation dialog for the radius
    _showRadiusDialog();
  }

  void _showRadiusDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Set Geofence Radius'),
          content: TextField(
            controller: radiusController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Radius (meters)',
              hintText: 'Enter radius in meters',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  geofenceRadius = double.parse(radiusController.text);
                });
                _checkGeofence();
                Navigator.of(context).pop();
              },
              child: const Text('Set'),
            ),
          ],
        );
      },
    );
  }

  void _clearGeofence() {
    setState(() {
      geofencePoints.clear();
      isInsideGeofence = false;
      isGeofenceActive = false;
    });
  }

  void _checkGeofence() {
    if (currentPosition == null || geofencePoints.isEmpty) {
      setState(() {
        isInsideGeofence = false;
        isGeofenceActive = false;
      });
      return;
    }

    // For a circular geofence around a single point
    double distance = Geolocator.distanceBetween(
      currentPosition!.latitude,
      currentPosition!.longitude,
      geofencePoints[0].latitude,
      geofencePoints[0].longitude,
    );

    bool wasInside = isInsideGeofence;

    setState(() {
      isInsideGeofence = distance <= geofenceRadius;
      isGeofenceActive = true;
    });

    // Only trigger events if the status has changed
    if (isInsideGeofence && !wasInside) {
      _onEnterGeofence();
    } else if (!isInsideGeofence && wasInside) {
      _onExitGeofence();
    }
  }

  void _onEnterGeofence() {
    // Handle enter geofence event
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Entered geofence area!'),
        backgroundColor: Colors.green,
      ),
    );

    // You can call Go Maps API here to log the entry
    _logGeofenceEvent('enter');
  }

  void _onExitGeofence() {
    // Handle exit geofence event
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Exited geofence area!'),
        backgroundColor: Colors.red,
      ),
    );

    // You can call Go Maps API here to log the exit
    _logGeofenceEvent('exit');
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
          'user_id': 'user_123', // Replace with actual user ID
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Geofencing Demo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              if (geofencePoints.isNotEmpty) {
                _showRadiusDialog();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Add a geofence point first')),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _clearGeofence,
          ),
        ],
      ),
      body: currentPosition == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: FlutterMap(
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
                          // Current position marker
                          Marker(
                            point: currentPosition!,
                            width: 80,
                            height: 80,
                            builder: (context) => Container(
                              child: Icon(
                                Icons.location_on,
                                color: isInsideGeofence
                                    ? Colors.green
                                    : Colors.blue,
                                size: 40,
                              ),
                            ),
                          ),
                          // Geofence points markers
                          ...geofencePoints.map(
                            (point) => Marker(
                              point: point,
                              width: 80,
                              height: 80,
                              builder: (context) => Container(
                                child: Icon(
                                  Icons.radio_button_checked,
                                  color: Colors.red,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
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
                // Instructions panel
                Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.white,
                  child: const Text(
                    'Tap on the map to set a geofence location',
                    style: TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),
                if (geofencePoints.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Chip(
                          label: Text(
                              'Radius: ${geofenceRadius.toStringAsFixed(1)}m'),
                          avatar: const Icon(Icons.radar, size: 16),
                          backgroundColor: Colors.blue.shade100,
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          icon: const Icon(Icons.edit, size: 16),
                          label: const Text('Change'),
                          onPressed: _showRadiusDialog,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
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
        color: !isGeofenceActive
            ? Colors.grey
            : (isInsideGeofence ? Colors.green : Colors.red),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              !isGeofenceActive
                  ? Icons.location_off
                  : (isInsideGeofence ? Icons.check_circle : Icons.cancel),
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Text(
              !isGeofenceActive
                  ? 'No Active Geofence'
                  : (isInsideGeofence ? 'Inside Geofence' : 'Outside Geofence'),
              style: const TextStyle(color: Colors.white, fontSize: 18),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
