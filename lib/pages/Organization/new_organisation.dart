import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:presence_point_2/services/user_state.dart';

class NewOrganisation extends StatefulWidget {
  const NewOrganisation({super.key});

  @override
  State<NewOrganisation> createState() => _NewOrganisationState();
}

class _NewOrganisationState extends State<NewOrganisation> {
  final TextEditingController _orgCodeController = TextEditingController();
  String? selectedOrgType;
  final List<String> _orgTypes = ["IT", "Healthcare", "Education", "Finance"];
  bool _isLoading = false;

  Future<void> _joinOrganisation() async {
    if (_orgCodeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter an organization code")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final orgData = await Provider.of<UserState>(context, listen: false)
          .verifyOrganization(_orgCodeController.text.trim());

      if (orgData != null) {
        await Provider.of<UserState>(context, listen: false).joinOrganization(
          orgId: orgData['org_id'].toString(),
          orgName: orgData['org_name'].toString(),
          orgCode: orgData['org_code'].toString(),
        );
        Navigator.pushReplacementNamed(context, "/home");
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Organization not found")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error joining organization: ${e.toString()}")),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.amber,
        title: const Text("Organization Setup"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pushReplacementNamed(context, "/home"),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              const Text("Create Organization",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: selectedOrgType,
                items: _orgTypes.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type),
                  );
                }).toList(),
                onChanged: (value) => setState(() => selectedOrgType = value),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: "Select Organization Type",
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pushReplacementNamed(
                  context,
                  "/organisationdetails",
                ),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: Colors.amber,
                ),
                child: const Text("Create Organization"),
              ),
              const SizedBox(height: 30),
              const Text("Join Organization",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _orgCodeController,
                decoration: const InputDecoration(
                  hintText: "Enter Organization Code",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isLoading ? null : _joinOrganisation,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: Colors.blue,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Join Organization"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
