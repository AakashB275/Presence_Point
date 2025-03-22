import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:presence_point_2/widgets/CustomAppBar.dart';
import 'package:presence_point_2/widgets/CustomDrawer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _userProfile;
  final supabase = Supabase.instance.client;
  final GlobalKey<ScaffoldState> MyKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final userId = supabase.auth.currentUser!.id;
      final response =
          await supabase.from('users').select().eq('id', userId).single();

      setState(() {
        _userProfile = response;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: "Presence Point", scaffoldKey: MyKey),
      drawer: CustomDrawer(),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _userProfile == null
              ? Center(child: Text('Error loading profile'))
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: CircleAvatar(
                          radius: 60,
                          child: Text(
                            _userProfile!['name'].substring(0, 1).toUpperCase(),
                            style: TextStyle(fontSize: 48),
                          ),
                        ),
                      ),
                      SizedBox(height: 24),
                      _buildProfileItem('Name', _userProfile!['name']),
                      _buildProfileItem('Email', _userProfile!['email']),
                      _buildProfileItem(
                          'Role', _userProfile!['role'].toUpperCase()),
                      _buildProfileItem(
                          'Hourly Rate', '\$${_userProfile!['hourly_rate']}'),
                      _buildProfileItem(
                        'Member Since',
                        DateFormat('MMM d, yyyy').format(
                          DateTime.parse(_userProfile!['created_at']),
                        ),
                      ),
                      Spacer(),
                      ElevatedButton(
                        onPressed: () {
                          // Implement edit profile functionality
                        },
                        child: Text('Edit Profile'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: Size(double.infinity, 50),
                        ),
                      ),
                    ],
                  ),
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
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Divider(),
        ],
      ),
    );
  }
}
