import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  final List<String> _attendanceHistory = [
    '2023-09-20: Checked In - 08:15 AM',
    '2023-09-19: Checked In - 08:30 AM',
    '2023-09-18: Checked In - 08:45 AM',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: CustomAppBar(
        title: "Employee Portal",
        scaffoldKey: _scaffoldKey,
      ),
      drawer: CustomDrawer(),
      body: SafeArea(
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
                "John Doe", // Replace with actual user name
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
    );
  }

  Widget _buildAttendanceButton() {
    return GestureDetector(
      onTap: () {
        setState(() => _isCheckedIn = !_isCheckedIn);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isCheckedIn
                ? 'Successfully checked in!'
                : 'Successfully checked out!'),
            backgroundColor: Colors.green,
          ),
        );
      },
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
        child: Column(
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
            child: ListView.builder(
              itemCount: _attendanceHistory.length,
              itemBuilder: (context, index) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.calendar_today),
                  title: Text(_attendanceHistory[index]),
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
        onPressed: _isLoading ? null : () => _signOut(),
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
