import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'employee_list_page.dart';

class OrganizationsManage extends StatefulWidget {
<<<<<<< HEAD
=======
  const OrganizationsManage({super.key});

>>>>>>> 0f5452abe6027247129abcc6afc371d246a67885
  @override
  _OrganizationsManageState createState() => _OrganizationsManageState();
}

class _OrganizationsManageState extends State<OrganizationsManage> {
  final supabase = Supabase.instance.client;
  bool _isLoading = false;
  bool _isAdmin = false;
  Map<String, List<dynamic>> _joinRequests = {};

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
  }

  Future<void> _checkAdminStatus() async {
    final userId = supabase.auth.currentUser!.id;
    final response = await supabase
        .from('users')
        .select('role')
        .eq('auth_user_id', userId)
        .single();

    setState(() {
      _isAdmin = response['role'] == 'admin';
    });

    if (_isAdmin) {
      await _fetchAllJoinRequests();
    }
  }

  Future<void> _fetchAllJoinRequests() async {
    final orgs = await fetchOrganizations();
    Map<String, List<dynamic>> requests = {};

    for (var org in orgs) {
      final orgId = org['org_id'];
      final joinRequests = await _fetchJoinRequests(orgId);
      if (joinRequests.isNotEmpty) {
        requests[orgId.toString()] = joinRequests;
      }
    }

    setState(() {
      _joinRequests = requests;
    });
  }

  Future<List<dynamic>> _fetchJoinRequests(String orgId) async {
    try {
      final response = await supabase
          .from('organization_join_requests')
          .select('*, users(name, email)')
          .eq('org_id', orgId)
          .eq('status', 'pending');
      return response;
    } catch (e) {
      print('Error fetching join requests: $e');
      return [];
    }
  }

  Future<void> _handleJoinRequest(String requestId, String status) async {
    try {
      await supabase
          .from('organization_join_requests')
          .update({'status': status}).eq('id', requestId);

      if (status == 'approved') {
        final request = await supabase
            .from('organization_join_requests')
            .select('user_id, org_id')
            .eq('id', requestId)
            .single();

        await supabase
            .from('users')
            .update({'org_id': request['org_id']}).eq('id', request['user_id']);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Request ${status == 'approved' ? 'approved' : 'rejected'}')),
      );

      await _fetchAllJoinRequests();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error processing request: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<List<dynamic>> fetchOrganizations() async {
    setState(() => _isLoading = true);
    try {
      final userId = supabase.auth.currentUser!.id;
      final response = await supabase
          .from('organization')
          .select()
          .eq('createdby', userId)
          .order('org_name', ascending: true);
      return response;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading organizations: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
      return [];
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _navigateToEmployeeList(Map<String, dynamic> org) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EmployeeListPage(orgId: org['org_id']),
      ),
    );
  }

  Widget _buildJoinRequestsSection(String orgId, String orgName) {
    final requests = _joinRequests[orgId] ?? [];

    if (requests.isEmpty) return SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, top: 8, bottom: 4),
          child: Text(
            'Join Requests for $orgName',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blue[800],
              fontSize: 14,
            ),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index];
            final user = request['users'];

            return Card(
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.grey[300],
                          radius: 20,
                          child: Icon(Icons.person, color: Colors.grey[700]),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user['name'] ?? 'Unknown User',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                user['email'] ?? '',
                                style: TextStyle(
                                    color: Colors.grey[600], fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Requested ${_formatDate(request['created_at'])}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () =>
                              _handleJoinRequest(request['id'], 'rejected'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                          child: Text('Reject'),
                        ),
                        SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () =>
                              _handleJoinRequest(request['id'], 'approved'),
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
        Divider(height: 24),
      ],
    );
  }

  String _formatDate(String dateString) {
    final date = DateTime.parse(dateString);
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("My Organizations",
            style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 2,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              setState(() {});
              if (_isAdmin) {
                _fetchAllJoinRequests();
              }
            },
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () {
              Navigator.pushNamed(context, '/neworganisation');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text('Create organization feature coming soon')),
              );
            },
            tooltip: 'Create Organization',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {});
          if (_isAdmin) {
            await _fetchAllJoinRequests();
          }
          return;
        },
        child: FutureBuilder(
          future: fetchOrganizations(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting ||
                _isLoading) {
              return Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 60, color: Colors.red),
                    SizedBox(height: 16),
                    Text('Error loading organizations',
                        style: TextStyle(fontSize: 18)),
                    TextButton(
                      onPressed: () => setState(() {}),
                      child: Text('Retry'),
                    )
                  ],
                ),
              );
            }

            final orgs = snapshot.data as List;

            if (orgs.isEmpty) {
              return SingleChildScrollView(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.business, size: 80, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No organizations found',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      SizedBox(height: 8),
                      Text('Tap + to create your first organization'),
                      SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: Icon(Icons.add),
                        label: Text('Create Organization'),
                        onPressed: () {
                          Navigator.pushNamed(context, '/neworganisation');
                        },
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.builder(
              itemCount: orgs.length,
              itemBuilder: (context, index) {
                final org = orgs[index];
                final orgId = org['org_id'].toString();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      margin: EdgeInsets.fromLTRB(8, index == 0 ? 8 : 0, 8, 4),
                      elevation: 2,
                      child: Column(
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            leading: CircleAvatar(
                              backgroundColor: Theme.of(context).primaryColor,
                              child: Text(
                                org['org_name'].substring(0, 1).toUpperCase(),
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                            title: Text(
                              org['org_name'],
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            subtitle: org['description'] != null
                                ? Text(org['description'],
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis)
                                : Text('Tap to manage employees'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_isAdmin &&
                                    (_joinRequests[orgId]?.isNotEmpty ?? false))
                                  Container(
                                    margin: EdgeInsets.only(right: 8),
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${_joinRequests[orgId]?.length ?? 0}',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                Icon(Icons.chevron_right),
                              ],
                            ),
                            onTap: () => _navigateToEmployeeList(org),
                          ),
                          if (_isAdmin)
                            AnimatedSize(
                              duration: Duration(milliseconds: 300),
                              child: _buildJoinRequestsSection(
                                  orgId, org['org_name']),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/neworganisation');
        },
        child: Icon(Icons.add),
        tooltip: 'Create new organization',
      ),
    );
  }
}
