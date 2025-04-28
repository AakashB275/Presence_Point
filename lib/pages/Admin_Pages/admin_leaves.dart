import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminLeavesScreen extends StatefulWidget {
  @override
  _AdminLeavesScreenState createState() => _AdminLeavesScreenState();
}

class _AdminLeavesScreenState extends State<AdminLeavesScreen> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _leaveRequests = [];
  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadAllLeaveRequests();
  }

  Future<void> _loadAllLeaveRequests() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Fetch all leave requests with user information
      final response = await supabase.from('leaves').select('''
            *,
            profiles:user_id (
              full_name, 
              email
            )
          ''').order('applied_at', ascending: false);

      setState(() {
        _leaveRequests = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error loading leave requests: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateLeaveStatus(String leaveId, String status) async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Update the leave status in the database
      await supabase
          .from('leaves')
          .update({'status': status}).eq('id', leaveId);

      // Reload the leave requests to reflect the changes
      await _loadAllLeaveRequests();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Leave request $status successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating leave status: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Leave Requests'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'All Leave Requests',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  SizedBox(height: 16),
                  Expanded(
                    child: _leaveRequests.isEmpty
                        ? Center(child: Text('No leave requests found'))
                        : ListView.builder(
                            itemCount: _leaveRequests.length,
                            itemBuilder: (context, index) {
                              final leave = _leaveRequests[index];
                              final startDate =
                                  DateTime.parse(leave['start_date']);
                              final endDate = DateTime.parse(leave['end_date']);
                              final appliedAt =
                                  DateTime.parse(leave['applied_at']);
                              final userProfile = leave['profiles'] ?? {};
                              final userName =
                                  userProfile['full_name'] ?? 'Unknown';
                              final userEmail = userProfile['email'] ?? '';

                              return Card(
                                margin: EdgeInsets.only(bottom: 16),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '${leave['leave_type'].toUpperCase()} Leave',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                            ),
                                          ),
                                          _getStatusChip(leave['status']),
                                        ],
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'Employee: $userName',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w500),
                                      ),
                                      if (userEmail.isNotEmpty)
                                        Text('Email: $userEmail'),
                                      SizedBox(height: 8),
                                      Text(
                                        'From: ${DateFormat('MMM d, yyyy').format(startDate)}',
                                      ),
                                      Text(
                                        'To: ${DateFormat('MMM d, yyyy').format(endDate)}',
                                      ),
                                      Text(
                                        'Applied on: ${DateFormat('MMM d, yyyy').format(appliedAt)}',
                                      ),
                                      SizedBox(height: 16),
                                      // Only show action buttons for pending requests
                                      if (leave['status'] == 'pending')
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            OutlinedButton(
                                              onPressed: () =>
                                                  _updateLeaveStatus(
                                                      leave['id'], 'rejected'),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: Colors.red,
                                              ),
                                              child: Text('Decline'),
                                            ),
                                            SizedBox(width: 8),
                                            ElevatedButton(
                                              onPressed: () =>
                                                  _updateLeaveStatus(
                                                      leave['id'], 'approved'),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.green,
                                                foregroundColor: Colors.white,
                                              ),
                                              child: Text('Approve'),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _getStatusChip(String status) {
    Color color;
    IconData icon;

    switch (status) {
      case 'approved':
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case 'rejected':
        color = Colors.red;
        icon = Icons.cancel;
        break;
      default:
        color = Colors.orange;
        icon = Icons.hourglass_empty;
    }

    return Chip(
      avatar: Icon(icon, color: Colors.white, size: 16),
      label: Text(
        status.toUpperCase(),
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      backgroundColor: color,
    );
  }
}
