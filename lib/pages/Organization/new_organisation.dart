import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NewOrganisation extends StatefulWidget {
  const NewOrganisation({super.key});

  @override
  State<NewOrganisation> createState() => _NewOrganisationState();
}

class _NewOrganisationState extends State<NewOrganisation> {
  final TextEditingController _orgCodeController = TextEditingController();
  String? selectedOrgType;
  final List<String> _orgTypes = ["IT", "Healthcare", "Education", "Finance"];

  Future<void> _joinOrganisation() async {
    if (_orgCodeController.text.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('joined_org', true); // Save joined status
      Navigator.pushReplacementNamed(context, "/home"); // Redirect to home
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Enter a valid organization code")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.amber,
        title: Text("Organisation Setup"),
        leading: IconButton(
          icon: Icon(Icons.arrow_back), // Back Button at Top Left
          onPressed: () {
            Navigator.pushReplacementNamed(context, "/home"); // Navigate Back
          },
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 20),
              Text("Create Organization",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: selectedOrgType,
                items: _orgTypes.map((type) {
                  return DropdownMenuItem(value: type, child: Text(type));
                }).toList(),
                onChanged: (value) => setState(() => selectedOrgType = value),
                decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: "Select Organization Type"),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacementNamed(
                      context, "/organisationdetails");
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50),
                  backgroundColor: Colors.amber,
                ),
                child: Text("Create Organization"),
              ),
              SizedBox(height: 30),
              Text("Join Organization",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              TextField(
                controller: _orgCodeController,
                decoration: InputDecoration(
                  hintText: "Enter Organization Code",
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _joinOrganisation,
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50),
                  backgroundColor: Colors.blue,
                ),
                child: Text("Join Organization"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
