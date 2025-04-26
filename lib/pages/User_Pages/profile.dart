import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:presence_point_2/widgets/CustomAppBar.dart';
import 'package:presence_point_2/widgets/CustomDrawer.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final supabase = Supabase.instance.client;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final _formKey = GlobalKey<FormState>();

  late Future<Map<String, dynamic>> _profileFuture;
  bool _isEditing = false;
  late TextEditingController _nameController;
  late TextEditingController _emailController;

  @override
  void initState() {
    super.initState();
    _initializeProfile();
  }

  void _initializeProfile() {
    _profileFuture = _fetchUserProfile().catchError((error) {
      debugPrint('Profile loading error: $error');
      throw error; // Re-throw to let FutureBuilder handle it
    });
    _nameController = TextEditingController();
    _emailController = TextEditingController();
  }

  Future<Map<String, dynamic>> _fetchUserProfile() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await supabase
          .from('users') // Changed from 'user' to 'users'
          .select('''
            name, 
            email,
            created_at,
            organization:org_id (org_name, org_code)
          ''')
          .eq('id', userId)
          .single()
          .timeout(const Duration(seconds: 10));

      return response;
    } on PostgrestException catch (e) {
      throw Exception('Database error: ${e.message}');
    } on TimeoutException {
      throw Exception('Request timed out');
    } catch (e) {
      throw Exception('Failed to load profile: ${e.toString()}');
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      setState(() => _isEditing = false);

      await supabase.from('users').update({
        'name': _nameController.text,
      }).eq('id', supabase.auth.currentUser!.id);

      setState(() {
        _profileFuture = _fetchUserProfile();
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating profile: ${e.toString()}')),
      );
      setState(() => _isEditing = true); // Return to edit mode on failure
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_isEditing) {
          setState(() => _isEditing = false);
          return false;
        }
        return true;
      },
      child: Scaffold(
        key: _scaffoldKey,
        appBar: CustomAppBar(title: "My Profile", scaffoldKey: _scaffoldKey),
        drawer: CustomDrawer(),
        body: FutureBuilder<Map<String, dynamic>>(
          future: _profileFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return _buildErrorState(snapshot.error as String?);
            }

            if (!snapshot.hasData) {
              return _buildErrorState(
                  Exception('No profile data found') as String?);
            }

            final profile = snapshot.data!;
            _initializeControllers(profile);

            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildProfileHeader(profile),
                  const SizedBox(height: 24),
                  Expanded(
                    child: _isEditing
                        ? _buildEditForm()
                        : _buildProfileView(profile),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _initializeControllers(Map<String, dynamic> profile) {
    _nameController = TextEditingController(text: profile['name']?.toString());
    _emailController =
        TextEditingController(text: profile['email']?.toString());
  }

  Widget _buildErrorState(String? error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            error ?? 'Failed to load profile',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () =>
                setState(() => _profileFuture = _fetchUserProfile()),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(Map<String, dynamic> profile) {
    return Column(
      children: [
        CircleAvatar(
          radius: 60,
          backgroundColor: Colors.amber.withOpacity(0.2),
          child: Text(
            (profile['name']?.toString().substring(0, 1) ?? '?').toUpperCase(),
            style: const TextStyle(fontSize: 48),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          profile['organization']?['org_name']?.toString() ?? 'No Organization',
          style: const TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileView(Map<String, dynamic> profile) {
    return Column(
      children: [
        _buildProfileItem(
            'Name', profile['name']?.toString() ?? 'Not provided'),
        _buildProfileItem(
            'Email', profile['email']?.toString() ?? 'Not provided'),
        _buildProfileItem(
          'Member Since',
          profile['created_at'] != null
              ? DateFormat('MMM d, yyyy').format(
                  DateTime.parse(profile['created_at'].toString()),
                )
              : 'Unknown',
        ),
        const Spacer(),
        ElevatedButton(
          onPressed: () => setState(() => _isEditing = true),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
            backgroundColor: Colors.amber,
          ),
          child: const Text('Edit Profile'),
        ),
      ],
    );
  }

  Widget _buildEditForm() {
    return Form(
      key: _formKey,
      child: ListView(
        children: [
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
            ),
            validator: (value) =>
                value?.isEmpty ?? true ? 'Name is required' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
            ),
            enabled: false, // Email shouldn't be editable
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _isEditing = false),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 50),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _updateProfile,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 50),
                    backgroundColor: Colors.green,
                  ),
                  child: const Text('Save Changes'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Divider(),
        ],
      ),
    );
  }
}
