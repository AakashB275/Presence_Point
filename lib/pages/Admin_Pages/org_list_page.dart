import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:presence_point_2/services/user_state.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Employee Model and Repository
class Employee {
  final String userId;
  final String authUserId;
  final String orgId;
  final String email;
  final String name;
  final String role;
  final DateTime createdAt;

  Employee({
    required this.userId,
    required this.authUserId,
    required this.orgId,
    required this.email,
    required this.name,
    required this.role,
    required this.createdAt,
  });

  factory Employee.fromMap(Map<String, dynamic> map) {
    return Employee(
      userId: map['users_id'] as String,
      authUserId: map['auth_user_id'] as String,
      orgId: map['org_id'] as String,
      email: map['email'] as String,
      name: map['name'] as String,
      role: map['role'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

class EmployeeRepository {
  final SupabaseClient _supabase;

  EmployeeRepository(this._supabase);

  Future<List<Employee>> getEmployeesByOrg(String orgId) async {
    final response = await _supabase
        .from('users')
        .select()
        .eq('org_id', orgId)
        .order('created_at', ascending: false);

    return (response as List).map((e) => Employee.fromMap(e)).toList();
  }

  Future<void> updateEmployeeRole(String userId, String newRole) async {
    await _supabase
        .from('users')
        .update({'role': newRole}).eq('users_id', userId);
  }

  Future<void> removeEmployee(String userId) async {
    await _supabase.from('users').delete().eq('users_id', userId);
  }
}

// JoinRequest Model and Repository
class JoinRequest {
  final String id;
  final String userId;
  final String orgId;
  final String userEmail;
  final String userName;
  final DateTime createdAt;

  JoinRequest({
    required this.id,
    required this.userId,
    required this.orgId,
    required this.userEmail,
    required this.userName,
    required this.createdAt,
  });

  factory JoinRequest.fromMap(Map<String, dynamic> map) {
    return JoinRequest(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      orgId: map['org_id'] as String,
      userEmail: map['user_email'] as String,
      userName: map['user_name'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

class JoinRequestRepository {
  final SupabaseClient supabase;

  JoinRequestRepository(this.supabase);

  Future<List<JoinRequest>> getPendingRequests(String orgId) async {
    final response = await supabase
        .from('organization_join_requests')
        .select('''
        id, 
        user_id, 
        org_id, 
        created_at,
        user:users(email, name)
      ''')
        .eq('org_id', orgId)
        .eq('status', 'pending')
        .order('created_at', ascending: false);

    return (response as List)
        .map((e) => JoinRequest.fromMap({
              ...e,
              'user_email': e['user']['email'],
              'user_name': e['user']['name'],
            }))
        .toList();
  }

  Future<void> approveRequest(String requestId, String userId) async {
    await supabase.rpc('approve_join_request', params: {
      'request_id': requestId,
      'user_id': userId,
    });
    final request = await supabase
        .from('organization_join_requests')
        .select('org_id')
        .eq('id', requestId)
        .single();

    // Increment the user count
    await supabase
        .from('organizations')
        .update({'totaluser': supabase.rpc('increment')}).eq(
            'org_id', request['org_id']);
  }

  Future<void> rejectRequest(String requestId) async {
    await supabase
        .from('organization_join_requests')
        .update({'status': 'rejected'}).eq('id', requestId);
  }
}

// Main Combined Admin Page
class CombinedAdminPage extends StatelessWidget {
  const CombinedAdminPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Organization Management'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Members', icon: Icon(Icons.people)),
              Tab(text: 'Join Requests', icon: Icon(Icons.person_add)),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            AdminEmployeesTab(),
            JoinRequestsTab(),
          ],
        ),
      ),
    );
  }
}

// Members Tab
class AdminEmployeesTab extends StatefulWidget {
  const AdminEmployeesTab({super.key});

  @override
  State<AdminEmployeesTab> createState() => _AdminEmployeesTabState();
}

class _AdminEmployeesTabState extends State<AdminEmployeesTab> {
  final EmployeeRepository _employeeRepo =
      EmployeeRepository(Supabase.instance.client);
  late Future<List<Employee>> _employeesFuture;
  late UserState _userState;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _userState = context.read<UserState>();
    _loadEmployees();
  }

  void _loadEmployees() {
    setState(() {
      _employeesFuture =
          _employeeRepo.getEmployeesByOrg(_userState.currentOrgId!);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search members...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value.toLowerCase();
              });
            },
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              _loadEmployees();
              return;
            },
            child: FutureBuilder<List<Employee>>(
              future: _employeesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final employees = snapshot.data!;
                final filteredEmployees = employees.where((employee) {
                  return employee.name.toLowerCase().contains(_searchQuery) ||
                      employee.email.toLowerCase().contains(_searchQuery) ||
                      employee.role.toLowerCase().contains(_searchQuery);
                }).toList();

                if (filteredEmployees.isEmpty) {
                  return const Center(child: Text('No members found'));
                }

                return ListView.builder(
                  itemCount: filteredEmployees.length,
                  itemBuilder: (context, index) {
                    final employee = filteredEmployees[index];
                    return _buildEmployeeCard(context, employee);
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmployeeCard(BuildContext context, Employee employee) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          child: Text(employee.name.substring(0, 1)),
        ),
        title: Text(employee.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(employee.email),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getRoleColor(employee.role),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    employee.role.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  DateFormat.yMMMd().format(employee.createdAt),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleMenuSelection(value, employee),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit_role',
              child: Text('Edit Role'),
            ),
            const PopupMenuItem(
              value: 'remove',
              child: Text('Remove from Organization'),
            ),
          ],
        ),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Colors.red;
      case 'manager':
        return Colors.blue;
      case 'member':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Future<void> _handleMenuSelection(String value, Employee employee) async {
    switch (value) {
      case 'edit_role':
        await _showEditRoleDialog(context, employee);
        break;
      case 'remove':
        await _showRemoveDialog(context, employee);
        break;
    }
  }

  Future<void> _showEditRoleDialog(
      BuildContext context, Employee employee) async {
    String selectedRole = employee.role;
    final roles = ['admin', 'manager', 'member'];

    return showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('Change Role for ${employee.name}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...roles.map((role) => RadioListTile<String>(
                      title: Text(role.toUpperCase()),
                      value: role,
                      groupValue: selectedRole,
                      onChanged: (value) {
                        setState(() {
                          selectedRole = value!;
                        });
                      },
                    )),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  try {
                    await _employeeRepo.updateEmployeeRole(
                      employee.userId,
                      selectedRole,
                    );
                    Navigator.pop(context);
                    _loadEmployees();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            '${employee.name} role updated to ${selectedRole.toUpperCase()}'),
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showRemoveDialog(
      BuildContext context, Employee employee) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${employee.name}?'),
        content: const Text(
            'This will remove the user from your organization. They will need to be re-invited to join again.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await _employeeRepo.removeEmployee(employee.userId);
                Navigator.pop(context);
                _loadEmployees();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${employee.name} removed from organization'),
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// Join Requests Tab
class JoinRequestsTab extends StatefulWidget {
  const JoinRequestsTab({super.key});

  @override
  State<JoinRequestsTab> createState() => _JoinRequestsTabState();
}

class _JoinRequestsTabState extends State<JoinRequestsTab> {
  final JoinRequestRepository _repo =
      JoinRequestRepository(Supabase.instance.client);
  late Future<List<JoinRequest>> _requestsFuture;
  late UserState _userState;

  @override
  void initState() {
    super.initState();
    _userState = context.read<UserState>();
    _loadRequests();
  }

  void _loadRequests() {
    setState(() {
      _requestsFuture = _repo.getPendingRequests(_userState.currentOrgId!);
    });
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        _loadRequests();
        return;
      },
      child: FutureBuilder<List<JoinRequest>>(
        future: _requestsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            debugPrint('Error: ${snapshot.error}');
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final requests = snapshot.data!;

          if (requests.isEmpty) {
            return const Center(child: Text('No pending requests'));
          }

          return ListView.builder(
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];
              return Card(
                margin: const EdgeInsets.all(8),
                child: ListTile(
                  title: Text(request.userEmail),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(request.userName),
                      Text(DateFormat.yMMMd().format(request.createdAt)),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check, color: Colors.green),
                        onPressed: () => _handleApproval(request),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () => _handleRejection(request.id),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _handleApproval(JoinRequest request) async {
    try {
      await _repo.approveRequest(request.id, request.userId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request approved')),
      );
      _loadRequests();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  Future<void> _handleRejection(String requestId) async {
    try {
      await _repo.rejectRequest(requestId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request rejected')),
      );
      _loadRequests();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }
}
