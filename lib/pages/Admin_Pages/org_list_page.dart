// organizations_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'employee_list_page.dart';

class OrganizationsPage extends StatefulWidget {
  const OrganizationsPage({super.key});

  @override
  _OrganizationsPageState createState() => _OrganizationsPageState();
}

class _OrganizationsPageState extends State<OrganizationsPage> {
  final supabase = Supabase.instance.client;

  Future<List<dynamic>> fetchOrganizations() async {
    final userId = supabase.auth.currentUser!.id;
    final response =
        await supabase.from('organization').select().eq('createdby', userId);
    return response;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("My Organizations")),
      body: FutureBuilder(
        future: fetchOrganizations(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }
          final orgs = snapshot.data as List;

          return ListView.builder(
            itemCount: orgs.length,
            itemBuilder: (context, index) {
              final org = orgs[index];
              return ListTile(
                title: Text(org['org_name']),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EmployeeListPage(orgId: org['org_id']),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
