import 'package:flutter/material.dart';
import 'package:presence_point_2/pages/admin_home_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EmployeeListPage extends StatefulWidget {
  final String orgId;

  const EmployeeListPage({super.key, required this.orgId});

  @override
  State<EmployeeListPage> createState() => _EmployeeListPageState();
}

class _EmployeeListPageState extends State<EmployeeListPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> employeeStatuses = [];
  RealtimeChannel? channel;

  @override
  void initState() {
    super.initState();
    fetchStatuses();
    setupRealtime();
  }

  Future<void> fetchStatuses() async {
    final employees = await supabase
        .from('users')
        .select('user_id, name')
        .eq('org_id', widget.orgId);

    final checkedIn = await supabase
        .from('attendance')
        .select('user_id')
        .eq('org_id', widget.orgId)
        .isFilter('check_out_time', null);

    final checkedInUserIds = checkedIn.map((e) => e['user_id']).toSet();

    setState(() {
      employeeStatuses = employees.map<Map<String, dynamic>>((user) {
        return {
          'name': user['name'],
          'user_id': user['user_id'],
          'isCheckedIn': checkedInUserIds.contains(user['user_id']),
        };
      }).toList();
    });
  }

  void setupRealtime() {
    channel = supabase.channel('attendance_changes');

    channel!.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'attendance',
      callback: (payload) {
        fetchStatuses();
      },
    );

    channel!.subscribe();
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

  @override
  void dispose() {
    if (channel != null) {
      supabase.removeChannel(channel!);
    }
    super.dispose();
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
          appBar: AppBar(title: Text("Employees")),
          body: employeeStatuses.isEmpty
              ? Center(child: CircularProgressIndicator())
              : ListView.builder(
                  itemCount: employeeStatuses.length,
                  itemBuilder: (context, index) {
                    final emp = employeeStatuses[index];
                    return ListTile(
                      title: Text(emp['name']),
                      trailing: Icon(
                        emp['isCheckedIn'] ? Icons.check_circle : Icons.cancel,
                        color: emp['isCheckedIn'] ? Colors.green : Colors.red,
                      ),
                    );
                  },
                ),
        ));
  }
}
