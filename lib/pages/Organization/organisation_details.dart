import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:presence_point_2/services/user_state.dart';
import 'package:provider/provider.dart';

class OrganisationDetails extends StatefulWidget {
  const OrganisationDetails({super.key});

  @override
  State<OrganisationDetails> createState() => _OrganisationDetailsState();
}

class _OrganisationDetailsState extends State<OrganisationDetails> {
  final TextEditingController _orgNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _hasLocation = false;
  double? _latitude;
  double? _longitude;
  double? _geofenceRadius;

  // Get Supabase client instance
  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _checkForLocation();
  }

  Future<void> _checkForLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final latitude = prefs.getDouble('org_latitude');
    final longitude = prefs.getDouble('org_longitude');
    final radius = prefs.getDouble('org_geofence_radius');

    if (latitude != null && longitude != null) {
      setState(() {
        _hasLocation = true;
        _latitude = latitude;
        _longitude = longitude;
        _geofenceRadius = radius ?? 200.0;
      });
    }
  }

  // Generate a unique org_code
  Future<int> _generateOrgCode() async {
    // Get current timestamp and use it as part of the code
    return DateTime.now().millisecondsSinceEpoch % 1000000000;
  }

  // Store organization data in Supabase
  Future<void> _storeOrganizationData() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Generate a unique org_code
      final orgCode = await _generateOrgCode();

      // Get current user's email from Supabase auth
      final currentUser = supabase.auth.currentUser;
      final createdBy = currentUser?.email ?? _emailController.text;

      // Create the data object to insert
      final data = {
        'org_name': _orgNameController.text,
        'createdby': createdBy,
        'totaluser': 1, // Starting with 1 user (creator)
        'org_code': orgCode,
      };

      // Add location data if available
      if (_hasLocation && _latitude != null && _longitude != null) {
        data['latitude'] = _latitude as Object;
        data['longitude'] = _longitude as Object;
        data['geofence_radius'] = _geofenceRadius as Object;
      }

      // Insert data into the 'organizations' table
      final response =
          await supabase.from('organization').insert(data).select();

      // Clear saved location data after successful creation
      if (_hasLocation) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('org_latitude');
        await prefs.remove('org_longitude');
        await prefs.remove('org_geofence_radius');
      }

      // Update the UserState to reflect organization membership
      Provider.of<UserState>(context, listen: false).joinOrganization();

      Fluttertoast.showToast(
        msg: "Organization created successfully!",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );

      // Navigate to home screen
      if (mounted) {
        Navigator.pushReplacementNamed(context, "/home");
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Error creating organization: ${e.toString()}",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.amber,
        title: const Text('Create Organization'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacementNamed(context, "/home");
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 30),
                const Text(
                  "Organization's Details",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                const Text("Organization's Name",
                    style: TextStyle(fontSize: 16)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _orgNameController,
                  decoration: const InputDecoration(
                    hintText: "Enter the name of your Organization",
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter organization name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                const Text("Email ID", style: TextStyle(fontSize: 16)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    hintText: "Enter your Email ID",
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter an email';
                    }
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                        .hasMatch(value)) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                const Text("Phone Number", style: TextStyle(fontSize: 16)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    hintText: "Enter your Phone Number",
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a phone number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                // Location information card
                if (_hasLocation)
                  Card(
                    color: Colors.green.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.location_on, color: Colors.green),
                              SizedBox(width: 8),
                              Text(
                                'Location Set',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Text('Latitude: ${_latitude?.toStringAsFixed(6)}'),
                          Text('Longitude: ${_longitude?.toStringAsFixed(6)}'),
                          Text(
                              'Radius: ${_geofenceRadius?.toStringAsFixed(1)} meters'),
                          TextButton.icon(
                            icon: Icon(Icons.edit_location),
                            label: Text('Change Location'),
                            onPressed: () {
                              Navigator.pushReplacementNamed(
                                  context, '/organizationlocation');
                            },
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Card(
                    color: Colors.orange.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.location_off, color: Colors.orange),
                              SizedBox(width: 8),
                              Text(
                                'No Location Set',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Text('Set a location for your organization.'),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: () {
                    // Save form data before navigating
                    if (_formKey.currentState!.validate()) {
                      Navigator.pushReplacementNamed(
                          context, '/organizationlocation');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: Colors.red,
                  ),
                  child: const Text("Set Location"),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isLoading ? null : _storeOrganizationData,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: Colors.amber,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Create Organization"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
