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
  bool _isCheckingLocation = false;
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
    if (mounted) setState(() => _isCheckingLocation = true);
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
    } finally {
      if (mounted) setState(() => _isCheckingLocation = false);
    }
  }

  Future<void> _storeOrganizationData() async {
    if (!_formKey.currentState!.validate()) return;
    if (_latitude == null || _longitude == null) {
      _showErrorToast("Please set a location for your organization");
      return;
    }

    try {
      setState(() => _isLoading = true);
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) throw Exception("User not authenticated");

      // 1. Verify user exists in public.users table
      final userExists = await supabase
          .from('users')
          .select()
          .eq('auth_user_id', currentUser.id)
          .maybeSingle();

      if (userExists == null) {
        throw Exception(
            "User account not found. Please complete your profile first.");
      }

      // 2. Validate organization name
      await _validateOrganizationName(_orgNameController.text.trim());

      // 3. Create organization using auth.user_id directly
      final orgData = {
        'org_name': _orgNameController.text.trim(),
        'createdby': currentUser.id, // Using auth.user_id directly
        'totaluser': 1,
        'org_code': await _generateUniqueOrgCode(),
        'latitude': _latitude,
        'longitude': _longitude,
        'geofencing_radius': _geofencingRadius ?? 200.0,
      };

      final response = await supabase
          .from('organization')
          .insert(orgData)
          .select('org_id')
          .single();

      // 4. Update user's org_id and role
      await supabase.from('users').update({
        'org_id': response['org_id'],
        'role': 'admin',
      }).eq('auth_user_id', currentUser.id);

      await _clearLocationPreferences();

      Provider.of<UserState>(context, listen: false).joinOrganization(
        orgId: response['org_id'].toString(),
        orgName: _orgNameController.text.trim(),
        orgCode: orgData['org_code'].toString(),
      );

      _showSuccessToast("Organization created successfully!");
      _navigateToHome();
    } catch (e) {
      _handleError("Failed to create organization: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<String> _generateUniqueOrgCode() async {
    String code;
    bool isUnique;

    do {
      code = _generateNumericOrgCode();
      final existing = await supabase
          .from('organization')
          .select('org_code')
          .eq('org_code', code)
          .maybeSingle();
      isUnique = existing == null;
    } while (!isUnique);

    return code;
  }

  String _generateNumericOrgCode() {
    final now = DateTime.now();
    final random = _random.nextInt(900000) + 100000; // 6-digit random number
    return '${now.millisecondsSinceEpoch % 1000}$random'; // Ensures numeric-only
  }

  Future<void> _validateOrganizationName(String orgName) async {
    try {
      final existingOrg = await supabase
          .from('organization')
          .select('org_name')
          .eq('org_name', orgName)
          .maybeSingle();

      if (existingOrg != null) {
        throw Exception("Organization name '$orgName' already exists");
      }
    } on PostgrestException catch (e) {
      throw Exception("Failed to validate organization name: ${e.message}");
    }
  }

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
                    if (value.length > 255) {
                      return 'Name must be less than 255 characters';
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
    return Card(
      color: _hasLocation ? Colors.green.shade50 : Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _hasLocation ? Icons.location_on : Icons.location_off,
                  color: _hasLocation ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  _hasLocation ? 'Location Set' : 'Location Required',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_isCheckingLocation)
              const LinearProgressIndicator()
            else if (_hasLocation) ...[
              Text('Latitude: ${_latitude?.toStringAsFixed(6)}'),
              Text('Longitude: ${_longitude?.toStringAsFixed(6)}'),
              Text(
                  'Geofencing Radius: ${_geofencingRadius?.toStringAsFixed(1)} meters'),
            ] else ...[
              const Text('Organization location is required for geofencing.'),
            ],
            TextButton.icon(
              icon: const Icon(Icons.edit_location),
              label: Text(_hasLocation ? 'Change Location' : 'Set Location'),
              onPressed: () {
                Navigator.pushReplacementNamed(
                    context, '/organizationlocation');
              },
            ),
          ],
        ),
      ),
    );
  }
}
