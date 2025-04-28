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
      // Fetch all leave requests
      final leaveResponse = await supabase
          .from('leaves')
          .select('*')
          .order('applied_at', ascending: false);

      List<Map<String, dynamic>> leaveRequests =
          List<Map<String, dynamic>>.from(leaveResponse);

      // For each leave request, fetch the corresponding user info
      for (var leave in leaveRequests) {
        try {
          // Use .select() instead of .single() to handle cases with no matching rows
          final userResponse = await supabase
              .from('users')
              .select('email, name')
              .eq('auth_user_id', leave['user_id']);

          // Check if we got any results
          if (userResponse != null && userResponse.isNotEmpty) {
            leave['user_info'] = userResponse.first;
          } else {
            leave['user_info'] = {'name': 'Unknown', 'email': ''};
          }
        } catch (e) {
          leave['user_info'] = {'name': 'Unknown', 'email': ''};
          debugPrint('Error fetching user info: $e');
        }
      }

      setState(() {
        _leaveRequests = leaveRequests;
      });
    } catch (e) {
      debugPrint('Error loading leave requests: $e');
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

  // Find the leave object in our local list rather than querying the database again
  Future<void> _updateLeaveStatus(String leaveId, String status) async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Find the leave in our local data
      final leaveIndex =
          _leaveRequests.indexWhere((leave) => leave['id'] == leaveId);

      if (leaveIndex >= 0) {
        // Update using a direct SQL statement via RPC
        await supabase.rpc(
          'safe_update_leave_status',
          params: {
            'p_leave_id': leaveId,
            'p_status': status,
          },
        );

        // Update our local data too
        setState(() {
          _leaveRequests[leaveIndex]['status'] = status;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Leave request $status successfully')),
        );
      } else {
        throw Exception('Leave not found with ID: $leaveId');
      }
    } catch (e) {
      debugPrint('Error updating leave status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating leave status: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });

      // Reload the leave requests to ensure we have the latest data
      await _loadAllLeaveRequests();
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

                              // Access user info correctly
                              final userInfo = leave['user_info'] ?? {};
                              final userName = userInfo['name'] ?? 'Unknown';
                              final userEmail = userInfo['email'] ?? '';

                              // Calculate leave duration in days
                              final leaveDuration =
                                  endDate.difference(startDate).inDays + 1;

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
                                        'Duration: $leaveDuration days',
                                      ),
                                      Text(
                                        'Applied on: ${DateFormat('MMM d, yyyy').format(appliedAt)}',
                                      ),
                                      if (leave['leaves_remaining'] != null)
                                        Text(
                                          'Leaves Remaining: ${leave['leaves_remaining']}',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w500),
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
