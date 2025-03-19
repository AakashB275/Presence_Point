import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PersonalDetailsPage extends StatefulWidget {
  const PersonalDetailsPage({super.key});

  @override
  State<PersonalDetailsPage> createState() => _PersonalDetailsPageState();
}

class _PersonalDetailsPageState extends State<PersonalDetailsPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  bool _termsAccepted = false;
  final supabase = Supabase.instance.client;
  DateTime? _selectedDate;

  @override
  void dispose() {
    _nameController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dobController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  Future<void> _saveDetails() async {
    String name = _nameController.text.trim();
    String dob = _dobController.text.trim();

    if (name.isEmpty || dob.isEmpty) {
      _showErrorSnackbar("Please fill in all fields.");
      return;
    }

    if (!_termsAccepted) {
      _showErrorSnackbar("Please accept the terms and policies.");
      return;
    }

    try {
      // Get current user ID
      final String? userId = supabase.auth.currentUser?.id;

      if (userId == null) {
        _showErrorSnackbar("User not authenticated.");
        return;
      }

      // Update user profile in Supabase
      await supabase.from('profiles').upsert({
        'id': userId,
        'full_name': name,
        'date_of_birth': _selectedDate?.toIso8601String(),
        'terms_accepted': true,
        'updated_at': DateTime.now().toIso8601String(),
      });

      _showSuccessSnackbar("Details saved successfully!");
      Navigator.pushReplacementNamed(context, "/home");
    } catch (e) {
      _showErrorSnackbar("An error occurred while saving your details.");
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "PresencePoint",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.amber,
      ),
      body: SingleChildScrollView(
        child: Container(
          color: Colors.white,
          child: Column(
            children: [
              SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  SizedBox(width: 30),
                  Text(
                    "Personal Details",
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 25),
              Image(
                image: AssetImage('assets/ProfileImg.png'),
                height: 200,
                width: 400,
              ),
              SizedBox(height: 40),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    icon: Icon(Icons.person),
                    filled: true,
                    fillColor: Colors.white,
                    hintText: "Full Name",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 15),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: TextField(
                  controller: _dobController,
                  readOnly: true,
                  onTap: () => _selectDate(context),
                  decoration: InputDecoration(
                    icon: Icon(Icons.calendar_today),
                    filled: true,
                    fillColor: Colors.white,
                    hintText: "Date of Birth",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Row(
                  children: [
                    Checkbox(
                      value: _termsAccepted,
                      onChanged: (bool? value) {
                        setState(() {
                          _termsAccepted = value ?? false;
                        });
                      },
                      activeColor: Colors.amber,
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _termsAccepted = !_termsAccepted;
                          });
                        },
                        child: Text(
                          "I accept the Terms and Policies",
                          style: TextStyle(
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: GestureDetector(
                  onTap: () {
                    // Navigate to terms and policies page
                    // You can implement this later
                    Navigator.pushNamed(context, "/terms");
                  },
                  child: Text(
                    "View Terms and Policies",
                    style: TextStyle(
                      color: Colors.blue,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 35),
              ElevatedButton(
                onPressed: _saveDetails,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: 70,
                    vertical: 10,
                  ),
                ),
                child: Text(
                  "Save Details",
                  style: TextStyle(fontSize: 18, color: Colors.black),
                ),
              ),
              SizedBox(height: 20),
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                },
                child: Text(
                  "Go Back",
                  style: TextStyle(
                    color: Colors.black,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
