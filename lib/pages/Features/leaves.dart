import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart' as uuid;

class LeavesScreen extends StatefulWidget {
  @override
  _LeavesScreenState createState() => _LeavesScreenState();
}

class _LeavesScreenState extends State<LeavesScreen> {
  bool _isLoading = false;
  bool _applying = false;
  List<Map<String, dynamic>> _leaveRequests = [];
  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadLeaveRequests();
  }

  Future<void> _loadLeaveRequests() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userId = supabase.auth.currentUser!.id;

      final response = await supabase
          .from('leaves')
          .select()
          .eq('user_id', userId)
          .order('applied_at', ascending: false);

      setState(() {
        _leaveRequests = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading leaves: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showApplyLeaveDialog() {
    final formKey = GlobalKey<FormState>();
    String leaveType = 'sick';
    DateTime startDate = DateTime.now();
    DateTime endDate = DateTime.now();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text('Apply for Leave'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: leaveType,
                  decoration: InputDecoration(labelText: 'Leave Type'),
                  items: ['sick', 'casual', 'earned'].map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type.toUpperCase()),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setModalState(() {
                      leaveType = value!;
                    });
                  },
                ),
                SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final pickedDate = await showDatePicker(
                      context: context,
                      initialDate: startDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(Duration(days: 365)),
                    );
                    if (pickedDate != null) {
                      setModalState(() {
                        startDate = pickedDate;
                      });
                    }
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Start Date',
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(DateFormat('MMM d, yyyy').format(startDate)),
                  ),
                ),
                SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final pickedDate = await showDatePicker(
                      context: context,
                      initialDate: endDate,
                      firstDate: startDate,
                      lastDate: DateTime.now().add(Duration(days: 365)),
                    );
                    if (pickedDate != null) {
                      setModalState(() {
                        endDate = pickedDate;
                      });
                    }
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'End Date',
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(DateFormat('MMM d, yyyy').format(endDate)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _applying
                  ? null
                  : () async {
                      if (formKey.currentState!.validate()) {
                        setState(() {
                          _applying = true;
                        });

                        try {
                          final userId = supabase.auth.currentUser!.id;
                          await supabase.from('leaves').insert({
                            'id': uuid.Uuid().v4(),
                            'user_id': userId,
                            'leave_type': leaveType,
                            'start_date': startDate.toIso8601String(),
                            'end_date': endDate.toIso8601String(),
                            'status': 'pending',
                            'applied_at': DateTime.now().toIso8601String(),
                          });

                          Navigator.of(context).pop();
                          _loadLeaveRequests();
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: ${e.toString()}')),
                          );
                        } finally {
                          setState(() {
                            _applying = false;
                          });
                        }
                      }
                    },
              child: _applying
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Leave Requests')),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'My Leave Requests',
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

                              return Card(
                                margin: EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  title: Text(
                                    '${leave['leave_type'].toUpperCase()} Leave',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Text(
                                    'From: ${DateFormat('MMM d, yyyy').format(startDate)}\n'
                                    'To: ${DateFormat('MMM d, yyyy').format(endDate)}\n'
                                    'Applied on: ${DateFormat('MMM d, yyyy').format(appliedAt)}\n'
                                    'Status: ${leave['status'].toUpperCase()}',
                                  ),
                                  isThreeLine: true,
                                  trailing: _getStatusIcon(leave['status']),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showApplyLeaveDialog,
        child: Icon(Icons.add),
        tooltip: 'Apply for Leave',
      ),
    );
  }

  Widget _getStatusIcon(String status) {
    switch (status) {
      case 'approved':
        return Icon(Icons.check_circle, color: Colors.green);
      case 'rejected':
        return Icon(Icons.cancel, color: Colors.red);
      default:
        return Icon(Icons.hourglass_empty, color: Colors.orange);
    }
  }
}
