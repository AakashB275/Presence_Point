import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final supabase = Supabase.instance.client;
  bool _isObscure = true;
  bool _isLoading = false;

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    String username = _usernameController.text.trim();
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();

    try {
      // Step 1: Create the authentication account
      final AuthResponse response = await supabase.auth.signUp(
        email: email,
        password: password,
        data: {'username': username}, // Basic data in auth metadata
      );

      if (response.user != null) {
        try {
          // Step 2: Insert user data into your existing table
          // Using a separate try-catch for better error isolation
          await _insertUserData(
            authUser: response.user!,
            username: username,
            email: email,
            password: password,
          );

          await _showMessageDialog(
              "Registration successful. Please verify your email before logging in.");
          if (mounted) {
            Navigator.pushReplacementNamed(context, "/login");
          }
        } catch (dbError) {
          // Handle database insertion errors specifically
          print("Database error: $dbError");
          await _showMessageDialog(
              "User created but profile data couldn't be stored: ${dbError.toString()}");
        }
      }
    } on AuthException catch (e) {
      String errorMessage = e.message;
      await _showMessageDialog("Auth error: $errorMessage");
    } catch (e) {
      print("Unexpected error: $e");
      await _showMessageDialog("An unexpected error occurred: ${e.toString()}");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Function to insert user data into your Supabase table
  Future<void> _insertUserData({
    required User authUser,
    required String username,
    required String email,
    required String password,
  }) async {
    // Debug print to verify data
    print("Attempting to insert user data for ${authUser.id}");
    print("Name: $username, Email: $email");

    try {
      // Insert into 'users' table - adjust table name if needed
      final response = await supabase.from('users').insert({
        // 'id': authUser.id, // Uncomment if you want to use auth ID and your table accepts UUID
        'name': username,
        'email': email,
        'password': password,
        'role': "Employee",
        'created_at': DateTime.now().toIso8601String(),
      }).select();

      print("Insert successful: $response");
    } catch (e) {
      print("Database insertion error: $e");
      // Rethrow to handle in the calling function
      throw Exception('Failed to create user profile: ${e.toString()}');
    }
  }

  Future<void> _showMessageDialog(String message) async {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Message"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            "Presence Point",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          backgroundColor: Colors.amber,
        ),
        body: Container(
          color: Colors.white,
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    const Text(
                      "Register",
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Image(
                      image: AssetImage('assets/RegisterImg.png'),
                      height: 200,
                      width: 400,
                    ),
                    const SizedBox(height: 25),
                    TextFormField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        icon: const Icon(Icons.account_circle_rounded),
                        filled: true,
                        fillColor: Colors.white,
                        hintText: "Name",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      validator: (value) =>
                          value!.isEmpty ? "Name is required" : null,
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        icon: const Icon(Icons.email),
                        filled: true,
                        fillColor: Colors.white,
                        hintText: "Email",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value!.isEmpty) {
                          return "Email is required";
                        } else if (!RegExp(r'^[^@]+@[^@]+\.[^@]+')
                            .hasMatch(value)) {
                          return "Enter a valid email";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _isObscure,
                      decoration: InputDecoration(
                        icon: const Icon(Icons.lock),
                        filled: true,
                        fillColor: Colors.white,
                        hintText: "Password",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(_isObscure
                              ? Icons.visibility
                              : Icons.visibility_off),
                          onPressed: () {
                            setState(() {
                              _isObscure = !_isObscure;
                            });
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value!.isEmpty) {
                          return "Password is required";
                        } else if (value.length < 6) {
                          return "Password must be at least 6 characters";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _register,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 70,
                          vertical: 10,
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.black)
                          : const Text(
                              "Register",
                              style:
                                  TextStyle(fontSize: 18, color: Colors.black),
                            ),
                    ),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                      },
                      child: const Text(
                        "Already have an account? Login",
                        style: TextStyle(
                          color: Colors.black,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
