import 'package:flutter/material.dart';

class OrganisationDetails extends StatefulWidget {
  const OrganisationDetails({super.key});

  @override
  State<OrganisationDetails> createState() => _OrganisationDetailsState();
}

class _OrganisationDetailsState extends State<OrganisationDetails> {
  final TextEditingController _orgNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.amber,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 50),
            Text(
              "Organization's Details",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Text("Organization's Name", style: TextStyle(fontSize: 16)),
            SizedBox(height: 8),
            TextField(
              controller: _orgNameController,
              decoration: InputDecoration(
                hintText: "Enter the name of your Organization",
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 20),
            Text("Email ID", style: TextStyle(fontSize: 16)),
            SizedBox(height: 8),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                hintText: "Enter your Email ID",
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 20),
            Text("Phone Number", style: TextStyle(fontSize: 16)),
            SizedBox(height: 8),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: "Enter your Phone Number",
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                Navigator.pushReplacementNamed(context, '/geofencingscreen');
              },
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
                backgroundColor: Colors.red,
              ),
              child: Text("Set Location"),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                print("Create Organization Clicked");
                print("Org Name: ${_orgNameController.text}");
                print("Email: ${_emailController.text}");
                print("Phone: ${_phoneController.text}");
                Navigator.pushReplacementNamed(context, "/home");
              },
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
                backgroundColor: Colors.amber,
              ),
              child: Text("Create Organization"),
            ),
          ],
        ),
      ),
    );
  }
}
