import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:presence_point_2/widgets/CustomDrawer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:presence_point_2/widgets/CustomAppBar.dart';
import 'package:presence_point_2/services/user_state.dart';

class OrganisationDetails extends StatefulWidget {
  const OrganisationDetails({super.key});

  @override
  State<OrganisationDetails> createState() => _OrganisationDetailsState();
}

class _OrganisationDetailsState extends State<OrganisationDetails> {
  final TextEditingController _orgNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _hasLocation = false;
  double? _latitude;
  double? _longitude;
  double? _geofencingRadius;
  final supabase = Supabase.instance.client;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  Future<void> _initializeForm() async {
    await _checkForLocation();
    _prepopulateEmail();
  }

  void _prepopulateEmail() {
    final currentUser = supabase.auth.currentUser;
    if (currentUser != null && mounted) {
      setState(() {
        _emailController.text = currentUser.email ?? '';
      });
    }
  }

  @override
  void dispose() {
    _orgNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _checkForLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final latitude = prefs.getDouble('org_latitude');
      final longitude = prefs.getDouble('org_longitude');
      final radius = prefs.getDouble('org_geofence_radius');

      if (latitude != null && longitude != null && mounted) {
        setState(() {
          _hasLocation = true;
          _latitude = latitude;
          _longitude = longitude;
          _geofencingRadius = radius ?? 200.0;
        });
      }
    } catch (e) {
      _showErrorToast("Error loading location: ${e.toString()}");
    }
  }

  Future<void> _storeOrganizationData() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      setState(() => _isLoading = true);
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) throw Exception("User not authenticated");

      // Create organization
      final orgData = {
        'org_name': _orgNameController.text.trim(),
        'createdby': currentUser.id,
        'totaluser': 1,
        'org_code': _generateNumericOrgCode(),
        'latitude': _latitude,
        'longitude': _longitude,
        'geofencing_radius': _geofencingRadius ?? 200.0,
      };

      final response = await supabase
          .from('organization')
          .insert(orgData)
          .select('org_id')
          .single();

      // Assign admin role to creator
      await supabase.from('user_roles').insert({
        'user_id': currentUser.id,
        'org_id': response['org_id'],
        'role': 'admin',
      });

      await _clearLocationPreferences();

      Provider.of<UserState>(context, listen: false).joinOrganization(
        orgId: response['org_id'].toString(),
        orgName: _orgNameController.text.trim(),
        orgCode: orgData['org_code'].toString(),
      );

      _showSuccessToast(
          "Organization created successfully! You are now an admin.");
      _navigateToHome();
    } catch (e) {
      _handleError("Failed to create organization: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

// Updated to generate numeric-only codes
  String _generateNumericOrgCode() {
    final now = DateTime.now();
    final random = _random.nextInt(900000) + 100000; // 6-digit random number
    return '${now.millisecondsSinceEpoch % 1000}$random'; // Ensures numeric-only
  }

  // Future<void> _validateOrganizationName(String orgName) async {
  //   try {
  //     final existingOrg = await supabase
  //         .from('organization')
  //         .select('org_name')
  //         .eq('org_name', orgName)
  //         .maybeSingle();

  //     if (existingOrg != null) {
  //       throw Exception("Organization name '$orgName' already exists");
  //     }
  //   } on PostgrestException catch (e) {
  //     throw Exception("Failed to validate organization name: ${e.message}");
  //   }
  // }

  Future<void> _clearLocationPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove('org_latitude'),
      prefs.remove('org_longitude'),
      prefs.remove('org_geofence_radius'),
    ]);
  }

  void _navigateToHome() {
    if (mounted) {
      Navigator.pushReplacementNamed(context, "/home");
    }
  }

  // void _handleDatabaseError(PostgrestException e) {
  //   String userMessage = "Database error occurred";

  //   if (e.code == '23505') {
  //     userMessage = "Organization code already exists. Please try again.";
  //   } else if (e.code == '42501') {
  //     userMessage = "Permission denied. Contact your administrator.";
  //   } else {
  //     userMessage = "Database operation failed: ${e.message}";
  //   }

  //   _showErrorToast(userMessage);
  //   debugPrint("Database error: ${e.toString()}");
  // }

  void _handleError(String message) {
    _showErrorToast(message);
    debugPrint(message);
  }

  void _showErrorToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.red,
      textColor: Colors.white,
    );
  }

  void _showSuccessToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.green,
      textColor: Colors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: "Organization Details",
        scaffoldKey: GlobalKey<ScaffoldState>(),
      ),
      drawer: CustomDrawer(),
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
                    if (value.length < 3) {
                      return 'Name must be at least 3 characters';
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
                _buildLocationCard(),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: () {
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

  Widget _buildLocationCard() {
    return _hasLocation
        ? Card(
            color: Colors.green.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.green),
                      const SizedBox(width: 8),
                      const Text(
                        'Location Set',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Latitude: ${_latitude?.toStringAsFixed(6)}'),
                  Text('Longitude: ${_longitude?.toStringAsFixed(6)}'),
                  Text(
                      'Geofencing Radius: ${_geofencingRadius?.toStringAsFixed(1)} meters'),
                  TextButton.icon(
                    icon: const Icon(Icons.edit_location),
                    label: const Text('Change Location'),
                    onPressed: () {
                      Navigator.pushReplacementNamed(
                          context, '/organizationlocation');
                    },
                  ),
                ],
              ),
            ),
          )
        : Card(
            color: Colors.orange.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_off, color: Colors.orange),
                      const SizedBox(width: 8),
                      const Text(
                        'No Location Set',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('Set a location for your organization.'),
                ],
              ),
            ),
          );
  }
}
