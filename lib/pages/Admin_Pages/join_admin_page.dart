import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:presence_point_2/services/user_state.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
        user:users(email, name)  // Changed from user_email to email
      ''')
        .eq('org_id', orgId)
        .eq('status', 'pending')
        .order('created_at', ascending: false);

    return (response as List)
        .map((e) => JoinRequest.fromMap({
              ...e,
              'user_email': e['user']['email'], // Maps to the correct column
              'user_name': e['user']['name'],
            }))
        .toList();
  }

  Future<void> approveRequest(String requestId, String userId) async {
    await supabase.rpc('approve_join_request', params: {
      'request_id': requestId,
      'user_id': userId,
    });
  }

  Future<void> rejectRequest(String requestId) async {
    await supabase
        .from('organization_join_requests')
        .update({'status': 'rejected'}).eq('id', requestId);
  }
}

class JoinRequestsAdminPage extends StatefulWidget {
  const JoinRequestsAdminPage({super.key});

  @override
  State<JoinRequestsAdminPage> createState() => _JoinRequestsAdminPageState();
}

class _JoinRequestsAdminPageState extends State<JoinRequestsAdminPage> {
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
    _requestsFuture = _repo.getPendingRequests(_userState.currentOrgId!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Join Requests'),
      ),
      body: FutureBuilder<List<JoinRequest>>(
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
      _loadRequests(); // Refresh the list
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: \${e.toString()}')),
      );
    }
  }

  Future<void> _handleRejection(String requestId) async {
    try {
      await _repo.rejectRequest(requestId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request rejected')),
      );
      _loadRequests(); // Refresh the list
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: \${e.toString()}')),
      );
    }
  }
}
