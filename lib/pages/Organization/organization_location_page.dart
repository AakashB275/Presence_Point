import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:presence_point_2/pages/admin_home_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OrganizationLocationScreen extends StatefulWidget {
  final String? orgId; // Optional parameter to receive organization ID

  const OrganizationLocationScreen({
    super.key,
    this.orgId,
  });

  @override
  State<OrganizationLocationScreen> createState() =>
      _OrganizationLocationScreenState();
}

class _OrganizationLocationScreenState
    extends State<OrganizationLocationScreen> {
  final MapController mapController = MapController();
  final supabase = Supabase.instance.client;
  bool _isLoading = false;

  // Current user position
  LatLng? currentPosition;

  // Location parameters
  LatLng? selectedLocation;
  double locationRadius = 200.0; // default radius in meters

  // Controller for radius input
  final TextEditingController radiusController =
      TextEditingController(text: '200.0');

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
    _getCurrentLocation();
    _loadSavedRadius();
  }

  @override
  void dispose() {
    radiusController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedRadius() async {
    final prefs = await SharedPreferences.getInstance();
    double? savedRadius = prefs.getDouble('location_radius');
    if (savedRadius != null) {
      setState(() {
        locationRadius = savedRadius;
        radiusController.text = savedRadius.toString();
      });
    }
  }

  Future<void> _saveRadius(double radius) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('location_radius', radius);
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
    } catch (e) {
      print('Error getting location: $e');
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

  void _selectLocation(LatLng point) {
    setState(() {
      selectedLocation = point;
    });

    // Show a confirmation dialog for the radius
    _showRadiusDialog();
  }

  void _showRadiusDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Set Location Radius'),
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
                  locationRadius = double.parse(radiusController.text);
                });
                _saveRadius(locationRadius);
                Navigator.of(context).pop();
              },
              child: const Text('Set'),
            ),
          ],
        );
      },
    );
  }

  void _clearLocation() {
    setState(() {
      selectedLocation = null;
    });
  }

  // Function to save organization location to Supabase
  Future<void> _saveOrganizationLocation() async {
    if (selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please set a location first')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      Map<String, dynamic> data = {
        'latitude': selectedLocation!.latitude,
        'longitude': selectedLocation!.longitude,
        'geofence_radius': locationRadius,
      };

      // If we're creating a new organization
      if (widget.orgId == null) {
        // Store in shared preferences to be used when creating organization
        final prefs = await SharedPreferences.getInstance();
        await prefs.setDouble('org_latitude', selectedLocation!.latitude);
        await prefs.setDouble('org_longitude', selectedLocation!.longitude);
        await prefs.setDouble('org_geofence_radius', locationRadius);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location saved for organization creation'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pushReplacementNamed(context, '/organisationdetails');
      }
      // If we're updating an existing organization
      else {
        await supabase
            .from('organizations')
            .update(data)
            .eq('org_id', widget.orgId as Object);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Organization location updated successfully'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving location: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
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
            title: const Text('Set Organization Location'),
            backgroundColor: Colors.amber,
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () {
                  if (selectedLocation != null) {
                    _showRadiusDialog();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Select a location first')),
                    );
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: _clearLocation,
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
                          onTap: (_, point) => _selectLocation(point),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.example.app',
                          ),
                          // Draw markers
                          MarkerLayer(
                            markers: [
                              // Current position marker
                              Marker(
                                point: currentPosition!,
                                width: 80,
                                height: 80,
                                builder: (context) => Container(
                                  child: const Icon(
                                    Icons.my_location,
                                    color: Colors.blue,
                                    size: 30,
                                  ),
                                ),
                              ),
                              // Selected location marker
                              if (selectedLocation != null)
                                Marker(
                                  point: selectedLocation!,
                                  width: 80,
                                  height: 80,
                                  builder: (context) => Container(
                                    child: const Icon(
                                      Icons.location_on,
                                      color: Colors.red,
                                      size: 40,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          // Draw radius circle
                          if (selectedLocation != null)
                            CircleLayer(
                              circles: [
                                CircleMarker(
                                  point: selectedLocation!,
                                  radius: locationRadius,
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
                        'Tap on the map to set your organization location',
                        style: TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    if (selectedLocation != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Chip(
                              label: Text(
                                  'Radius: ${locationRadius.toStringAsFixed(1)}m'),
                              avatar: const Icon(Icons.radar, size: 16),
                              backgroundColor: Colors.blue.shade100,
                            ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              icon: const Icon(Icons.edit, size: 16),
                              label: const Text('Change'),
                              onPressed: _showRadiusDialog,
                              style: TextButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    // Location info display
                    if (selectedLocation != null)
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              children: [
                                Text(
                                  'Selected Location',
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Latitude: ${selectedLocation!.latitude.toStringAsFixed(6)}',
                                  style:
                                      const TextStyle(fontFamily: 'monospace'),
                                ),
                                Text(
                                  'Longitude: ${selectedLocation!.longitude.toStringAsFixed(6)}',
                                  style:
                                      const TextStyle(fontFamily: 'monospace'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    // Save location button
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: ElevatedButton(
                        onPressed:
                            _isLoading ? null : _saveOrganizationLocation,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          backgroundColor: Colors.amber,
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : const Text("Save Organization Location"),
                      ),
                    ),
                  ],
                ),
          floatingActionButton: FloatingActionButton(
            onPressed: _getCurrentLocation,
            backgroundColor: Colors.amber,
            child: const Icon(Icons.my_location),
          ),
        ));
  }
}
