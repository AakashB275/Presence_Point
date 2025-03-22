import 'package:flutter/material.dart';

class NewOrganisation extends StatefulWidget {
  const NewOrganisation({super.key});

  @override
  State<NewOrganisation> createState() => _NewOrganisationState();
}

class _NewOrganisationState extends State<NewOrganisation> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.amber,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 50),
            Text("Create Organization", style: TextStyle(fontSize: 16)),
            SizedBox(height: 8),
            TextField(
              decoration: InputDecoration(
                hintText: "Select Organization Type",
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pushReplacementNamed(context, "/organisationdetails");
              },
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
                backgroundColor: Colors.amber,
              ),
              child: Text("Create Organization"),
            ),
            SizedBox(height: 20),
            Text("Join Organisation", style: TextStyle(fontSize: 16)),
            SizedBox(height: 8),
            TextField(
              decoration: InputDecoration(
                hintText: "Organisation Code",
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
