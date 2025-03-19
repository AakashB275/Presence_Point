import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class GeofencingMapScreen extends StatefulWidget {
  const GeofencingMapScreen({Key? key}) : super(key: key);

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
  double geofenceRadius = 200.0; // radius in meters
  bool isInsideGeofence = false;
  
  // Streaming position updates
  StreamSubscription<Position>? positionStream;

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
          content: Text('Location permissions are permanently denied, we cannot request permissions.'),
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

  void _clearGeofence() {
    setState(() {
      geofencePoints.clear();
      isInsideGeofence = false;
    });
  }

  void _checkGeofence() {
    if (currentPosition == null || geofencePoints.isEmpty) return;
    
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
      
      if (isInsideGeofence) {
        _onEnterGeofence();
      } else {
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
      
      if (isInsideGeofence) {
        _onEnterGeofence();
      } else {
        _onExitGeofence();
      }
    }
  }

  void _onEnterGeofence() {
    // Handle enter geofence event
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Entered geofence area!')),
    );
    
    // You can call Go Maps API here to log the entry
    _logGeofenceEvent('enter');
  }

  void _onExitGeofence() {
    // Handle exit geofence event
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Exited geofence area!')),
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
            icon: const Icon(Icons.delete),
            onPressed: _clearGeofence,
          ),
        ],
      ),
      body: currentPosition == null
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
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
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
                          color: Colors.blue,
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
                            Icons.circle,
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
                // Draw geofence polygon
                if (geofencePoints.length > 2)
                  PolygonLayer(
                    polygons: [
                      Polygon(
                        points: geofencePoints,
                        color: Colors.red.withOpacity(0.2),
                        borderColor: Colors.red,
                        borderStrokeWidth: 2,
                      ),
                    ],
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
        child: Text(
          isInsideGeofence ? 'Inside Geofence' : 'Outside Geofence',
          style: const TextStyle(color: Colors.white, fontSize: 18),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
