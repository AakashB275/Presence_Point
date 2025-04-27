import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:presence_point_2/services/user_state.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

class AdminEmployeesPage extends StatefulWidget {
  const AdminEmployeesPage({super.key});

  @override
  State<AdminEmployeesPage> createState() => _AdminEmployeesPageState();
}

class _AdminEmployeesPageState extends State<AdminEmployeesPage> {
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Organization Members'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadEmployees,
          ),
        ],
      ),
      body: Column(
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
        ],
      ),
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
