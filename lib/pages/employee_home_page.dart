import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart'; // Add this package to your pubspec.yaml
import '../widgets/CustomAppBar.dart';
import '../widgets/CustomDrawer.dart';

class EmployeeHomePage extends StatefulWidget {
  const EmployeeHomePage({super.key});

  @override
  State<EmployeeHomePage> createState() => _EmployeeHomePageState();
}

class _EmployeeHomePageState extends State<EmployeeHomePage> {
  final supabase = Supabase.instance.client;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isLoading = false;
  bool _isCheckedIn = false;

  // User data
  String _userName = '';
  String _userId = '';
  String _orgId = '';
  List<Map<String, dynamic>> _attendanceHistory = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        if (mounted) Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      final userData = await supabase
          .from('users')
          .select('auth_user_id, name, org_id')
          .eq('auth_user_id', user.id)
          .single();

      _userId = userData['auth_user_id'] as String;
      _userName = userData['name'] as String;
      _orgId = userData['org_id'] as String;

      await _checkAttendanceStatus();
      await _loadAttendanceHistory();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _checkAttendanceStatus() async {
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];

      final attendance = await supabase
          .from('attendance')
          .select('check_in_time, check_out_time')
          .eq('auth_user_id', _userId)
          .eq('date', today)
          .maybeSingle();

      if (attendance != null) {
        final checkOutTime = attendance['check_out_time'];
        setState(() {
          _isCheckedIn = checkOutTime == null;
        });
      } else {
        setState(() {
          _isCheckedIn = false;
        });
      }
    } catch (e) {
      debugPrint('Error checking attendance status: $e');
    }
  }

  Future<void> _loadAttendanceHistory() async {
    try {
      final response = await supabase
          .from('attendance')
          .select('date, check_in_time, check_out_time')
          .eq('auth_user_id', _userId) // Changed from user_id to auth_user_id
          .order('date', ascending: false)
          .limit(10);

      setState(() {
        _attendanceHistory = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      debugPrint('Error loading attendance history: $e');
    }
  }

  Future<void> _toggleAttendance() async {
    setState(() => _isLoading = true);
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];
      final now = DateTime.now().toIso8601String();

      if (!_isCheckedIn) {
        // Check in
        await supabase.from('attendance').insert({
          'auth_user_id': _userId, // Changed from user_id to auth_user_id
          'org_id': _orgId,
          'date': today,
          'check_in_time': now,
          'check_out_time': null,
        });

        setState(() => _isCheckedIn = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully checked in!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Check out
        await supabase
            .from('attendance')
            .update({'check_out_time': now})
            .eq('auth_user_id', _userId) // Changed from user_id to auth_user_id
            .eq('date', today);

        setState(() => _isCheckedIn = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully checked out!'),
            backgroundColor: Colors.green,
          ),
        );
      }

      await _loadAttendanceHistory();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating attendance: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatAttendanceRecord(Map<String, dynamic> record) {
    final date = record['date'] as String;
    final checkIn = record['check_in_time'] != null
        ? DateFormat('hh:mm a').format(DateTime.parse(record['check_in_time']))
        : 'N/A';

    final checkOut = record['check_out_time'] != null
        ? DateFormat('hh:mm a').format(DateTime.parse(record['check_out_time']))
        : 'Not checked out';

    return '$date: Check in - $checkIn | Check out - $checkOut';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;

        // Show confirmation dialog
        final shouldPop = await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Exit App?'),
              content: const Text('Are you sure you want to exit the app?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('No'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Yes'),
                ),
              ],
            );
          },
        );

        if (shouldPop ?? false) {
          // This will exit the app
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        appBar: CustomAppBar(
          title: "Employee Portal",
          scaffoldKey: _scaffoldKey,
        ),
        drawer: CustomDrawer(),
        body: _isLoading && _userName.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      Text(
                        "Welcome Back,",
                        style: TextStyle(
                          fontSize: 24,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        _userName,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 40),
                      _buildAttendanceButton(),
                      const SizedBox(height: 30),
                      _buildAttendanceStatus(),
                      const SizedBox(height: 30),
                      _buildAttendanceHistory(),
                      const Spacer(),
                      _buildSignOutButton(),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildAttendanceButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _toggleAttendance,
      child: Container(
        width: 150,
        height: 150,
        decoration: BoxDecoration(
          color: _isCheckedIn ? Colors.red[100] : Colors.green[100],
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.3),
              spreadRadius: 2,
              blurRadius: 10,
            ),
          ],
        ),
        child: _isLoading
            ? const CircularProgressIndicator()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isCheckedIn ? Icons.logout : Icons.login,
                    size: 40,
                    color: _isCheckedIn ? Colors.red : Colors.green,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _isCheckedIn ? 'Check Out' : 'Check In',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _isCheckedIn ? Colors.red : Colors.green,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildAttendanceStatus() {
    return Column(
      children: [
        const Text(
          "Current Status",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
          decoration: BoxDecoration(
            color: _isCheckedIn ? Colors.green[50] : Colors.grey[200],
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            _isCheckedIn ? "Currently Checked In" : "Not Checked In",
            style: TextStyle(
              fontSize: 16,
              color: _isCheckedIn ? Colors.green[800] : Colors.grey[600],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAttendanceHistory() {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Recent Attendance",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _attendanceHistory.isEmpty
                ? Center(
                    child: Text(
                      "No attendance records found",
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  )
                : ListView.builder(
                    itemCount: _attendanceHistory.length,
                    itemBuilder: (context, index) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const Icon(Icons.calendar_today),
                        title: Text(
                            _formatAttendanceRecord(_attendanceHistory[index])),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignOutButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _isLoading ? null : _signOut,
        icon: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.logout),
        label: const Text("Sign Out"),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red,
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: const BorderSide(color: Colors.red),
        ),
      ),
    );
  }

  Future<void> _signOut() async {
    setState(() => _isLoading = true);
    try {
      await supabase.auth.signOut();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error signing out: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
