import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:presence_point_2/widgets/CustomAppBar.dart';
import 'package:presence_point_2/widgets/CustomDrawer.dart';

class UpdateOrganizationLocationScreen extends StatefulWidget {
  const UpdateOrganizationLocationScreen({super.key});

  @override
  State<UpdateOrganizationLocationScreen> createState() =>
      _UpdateOrganizationLocationScreenState();
}

class _UpdateOrganizationLocationScreenState
    extends State<UpdateOrganizationLocationScreen> {
  // Initialize MapController in initState
  late MapController mapController;
  final supabase = Supabase.instance.client;
  bool _isLoading = false;
  bool _isFetchingInitialData = true;
  String? _errorMessage;

  // Flag to indicate if map needs to be centered after init
  bool _needsMapCentering = false;

  // Organization details
  String? _orgId;
  String? _orgName;

  // Location parameters
  LatLng? currentPosition;
  LatLng? selectedLocation;
  double locationRadius = 200.0;
  final TextEditingController radiusController = TextEditingController();

  // Helper function to safely convert database values to double
  double? toDoubleOrNull(dynamic value) {
    if (value == null) return null;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    return null;
  }

  @override
  void initState() {
    super.initState();
    debugPrint("Initializing UpdateOrganizationLocationScreen");
    // Initialize the mapController here
    mapController = MapController();
    _initializeData();
  }

  @override
  void dispose() {
    debugPrint("Disposing UpdateOrganizationLocationScreen");
    radiusController.dispose();
    // No need to dispose mapController as flutter_map handles this internally
    super.dispose();
  }

  // Function to center map - called after map is ready
  void _centerMapOnLocation() {
    debugPrint("Attempting to center map on location");
    if (selectedLocation != null) {
      mapController.mapEventStream.listen((event) {
        if (event is MapEventMoveEnd) {
          debugPrint("Map is ready after move event");
        }
      });
      debugPrint("Moving map to selected location");
      try {
        mapController.move(selectedLocation!, 15.0);
        _needsMapCentering = false;
      } catch (e) {
        debugPrint("Error moving map: $e");
      }
    } else {
      debugPrint("Map not ready or no selected location");
      _needsMapCentering = true; // Will try again when the map is ready
    }
  }

  Future<void> _initializeData() async {
    debugPrint("Starting _initializeData()");
    try {
      setState(() {
        _isFetchingInitialData = true;
        _errorMessage = null;
      });

      // Get current authenticated user
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) {
        debugPrint("Error: User not authenticated");
        throw Exception('User not authenticated');
      }
      debugPrint("Current user ID: ${currentUser.id}");

      // Fetch user details from public.users table
      debugPrint("Fetching user details from Supabase");
      final userResponse = await supabase
          .from('users')
          .select('org_id, role')
          .eq('auth_user_id', currentUser.id)
          .single();
      debugPrint("User response: $userResponse");

      if (userResponse['org_id'] == null) {
        debugPrint("Error: User is not associated with any organization");
        throw Exception('User is not associated with any organization');
      }

      if (userResponse['role'] != 'admin') {
        debugPrint("Error: User role is not admin: ${userResponse['role']}");
        throw Exception('Only organization admins can update location');
      }

      // Fetch organization details
      debugPrint(
          "Fetching organization details for org_id: ${userResponse['org_id']}");
      final orgResponse = await supabase
          .from('organization')
          .select('org_id, org_name, latitude, longitude, geofencing_radius')
          .eq('org_id', userResponse['org_id'])
          .single();
      debugPrint("Organization response: $orgResponse");

      // Set organization data with null checks
      _orgId = orgResponse['org_id'] as String?;
      _orgName = orgResponse['org_name'] as String?;
      debugPrint("Set org_id: $_orgId, org_name: $_orgName");

      // Get current device location
      debugPrint("Requesting location permission");
      await _requestLocationPermission();
      debugPrint("Getting current device position");
      final devicePosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      debugPrint(
          "Device position: ${devicePosition.latitude}, ${devicePosition.longitude}");

      // Make sure the widget is still mounted before setState
      if (!mounted) {
        debugPrint("Widget unmounted during async operation, aborting");
        return;
      }

      setState(() {
        currentPosition =
            LatLng(devicePosition.latitude, devicePosition.longitude);

        // Use organization location if available, otherwise use device location
        // Convert database values safely to double using helper function
        final orgLat = toDoubleOrNull(orgResponse['latitude']);
        final orgLng = toDoubleOrNull(orgResponse['longitude']);
        debugPrint("Org latitude: $orgLat, longitude: $orgLng");

        selectedLocation = (orgLat != null && orgLng != null)
            ? LatLng(orgLat, orgLng)
            : currentPosition;
        debugPrint(
            "Selected location: ${selectedLocation?.latitude}, ${selectedLocation?.longitude}");

        // Safely convert geofencing_radius to double
        var radius = toDoubleOrNull(orgResponse['geofencing_radius']);
        debugPrint(
            "Original geofencing_radius type: ${orgResponse['geofencing_radius']?.runtimeType}, value: ${orgResponse['geofencing_radius']}");
        debugPrint("Converted radius: $radius");
        locationRadius = radius ?? 200.0;
        radiusController.text = locationRadius.toStringAsFixed(1);

        // Set flag to center map after it's initialized
        // Don't call move() directly here
        _needsMapCentering = true;
      });
    } catch (e, stackTrace) {
      debugPrint("Error in _initializeData: $e");
      debugPrint("Stack trace: $stackTrace");

      // Make sure the widget is still mounted before setState
      if (!mounted) {
        debugPrint("Widget unmounted during error handling, aborting");
        return;
      }

      setState(() {
        _errorMessage = 'Error initializing data: ${e.toString()}';
      });
    } finally {
      // Make sure the widget is still mounted before setState
      if (mounted) {
        setState(() => _isFetchingInitialData = false);
        debugPrint(
            "Finished _initializeData(), _isFetchingInitialData: $_isFetchingInitialData");
      }
    }
  }

  Future<void> _requestLocationPermission() async {
    debugPrint("Checking location permission");
    LocationPermission permission = await Geolocator.checkPermission();
    debugPrint("Current permission status: $permission");

    if (permission == LocationPermission.denied) {
      debugPrint("Permission denied, requesting permission");
      permission = await Geolocator.requestPermission();
      debugPrint("New permission status: $permission");

      if (permission == LocationPermission.denied) {
        debugPrint("Permission still denied after request");
        throw Exception('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint("Permission denied forever");
      throw Exception('Location permissions are permanently denied');
    }

    debugPrint("Location permission granted");
  }

  void _selectLocation(LatLng point) {
    debugPrint("Location selected: ${point.latitude}, ${point.longitude}");
    setState(() {
      selectedLocation = point;
    });
    _showRadiusDialog();
  }

  void _showRadiusDialog() {
    radiusController.text = locationRadius.toStringAsFixed(1);
    debugPrint("Showing radius dialog, current radius: $locationRadius");

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Update Geofencing Radius'),
          content: TextField(
            controller: radiusController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Radius (meters)',
              hintText: 'Enter radius in meters',
              suffixText: 'meters',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final newRadius =
                    double.tryParse(radiusController.text) ?? 200.0;
                debugPrint("Updating radius to: $newRadius");
                setState(() => locationRadius = newRadius);
                Navigator.of(context).pop();
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateOrganizationLocation() async {
    debugPrint("Starting organization location update");
    if (selectedLocation == null || _orgId == null) {
      debugPrint("Update failed: selectedLocation or _orgId is null");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a location first')),
      );
      return;
    }

    setState(() => _isLoading = true);
    debugPrint("Updating location for org_id: $_orgId");

    try {
      debugPrint(
          "Sending update to Supabase with data: latitude: ${selectedLocation!.latitude}, longitude: ${selectedLocation!.longitude}, radius: $locationRadius");
      await supabase.from('organization').update({
        'latitude': selectedLocation!.latitude,
        'longitude': selectedLocation!.longitude,
        'geofencing_radius': locationRadius,
        // Removed 'updated_at': DateTime.now().toIso8601String(), as it doesn't exist in the schema
      }).eq('org_id', _orgId!);

      debugPrint("Location update successful");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Organization location updated successfully'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.of(context).pop(); // Return to previous screen
    } catch (e, stackTrace) {
      debugPrint("Error updating location: $e");
      debugPrint("Stack trace: $stackTrace");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update location: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("Building UpdateOrganizationLocationScreen widget");
    return Scaffold(
      appBar: CustomAppBar(
        title: _orgName != null
            ? "Update $_orgName Location"
            : "Update Organization Location",
        scaffoldKey: GlobalKey<ScaffoldState>(),
      ),
      drawer: CustomDrawer(),
      body: _isFetchingInitialData
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _initializeData,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: FlutterMap(
                        mapController: mapController,
                        options: MapOptions(
                          center: selectedLocation ??
                              currentPosition ??
                              LatLng(0, 0),
                          zoom: 15.0,
                          onTap: (_, point) => _selectLocation(point),
                          onMapReady: () {
                            debugPrint("Map is ready");
                            // Center map after it's fully initialized
                            if (_needsMapCentering) {
                              _centerMapOnLocation();
                            }
                          },
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.example.app',
                          ),
                          MarkerLayer(
                            markers: [
                              if (currentPosition != null)
                                Marker(
                                  point: currentPosition!,
                                  width: 80,
                                  height: 80,
                                  builder: (context) => const Icon(
                                    Icons.my_location,
                                    color: Colors.blue,
                                    size: 30,
                                  ),
                                ),
                              if (selectedLocation != null)
                                Marker(
                                  point: selectedLocation!,
                                  width: 80,
                                  height: 80,
                                  builder: (context) => const Icon(
                                    Icons.location_on,
                                    color: Colors.red,
                                    size: 40,
                                  ),
                                ),
                            ],
                          ),
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
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          if (selectedLocation != null)
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Selected Location',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Latitude: ${selectedLocation!.latitude.toStringAsFixed(6)}',
                                      style: const TextStyle(
                                          fontFamily: 'monospace'),
                                    ),
                                    Text(
                                      'Longitude: ${selectedLocation!.longitude.toStringAsFixed(6)}',
                                      style: const TextStyle(
                                          fontFamily: 'monospace'),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(Icons.radar, size: 16),
                                        const SizedBox(width: 8),
                                        Text(
                                            'Radius: ${locationRadius.toStringAsFixed(1)} meters'),
                                        const Spacer(),
                                        TextButton(
                                          onPressed: _showRadiusDialog,
                                          child: const Text('Change'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed:
                                _isLoading ? null : _updateOrganizationLocation,
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 50),
                              backgroundColor: Colors.amber,
                            ),
                            child: _isLoading
                                ? const CircularProgressIndicator(
                                    color: Colors.white)
                                : const Text("Update Location"),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          debugPrint("FAB pressed, moving to current position");
          if (currentPosition != null) {
            try {
              mapController.move(currentPosition!, 15.0);
            } catch (e) {
              debugPrint("Error moving map: $e");
            }
          }
        },
        backgroundColor: Colors.amber,
        child: const Icon(Icons.my_location),
      ),
    );
  }
}
