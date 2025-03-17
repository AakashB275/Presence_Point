import 'package:flutter/material.dart';
import 'package:presence_point_2/pages/home_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:supabase/supabase.dart';
import 'package:presence_point_2/pages/login.dart';
import 'package:presence_point_2/pages/register.dart';

class GetStarted extends StatefulWidget {
  const GetStarted({super.key});

  @override
  State<GetStarted> createState() => _GetStartedState();
}

class _GetStartedState extends State<GetStarted> {
  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _checkIfUserIsLoggedIn();
  }

  void _checkIfUserIsLoggedIn() {
    if (supabase.auth.currentSession != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    }
  }

  Future<void> _googleSignIn() async {
    try {
      await supabase.auth.signInWithOAuth(
        OAuthProvider.google,
      );
      _showMessageDialog("Registration successful. You can now log in.");
      if (mounted) {
        Navigator.pushReplacementNamed(context, "/home");
      }
    } catch (e) {
      _showMessageDialog("Error signing in with Google: $e");
    }
  }

  Future<void> _showMessageDialog(String message) async {
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
    return Scaffold(
      body: Container(
        color: Colors.white,
        child: Center(
          child: Column(children: [
            const SizedBox(height: 60),
            const Text(
              "Welcome To PresencePoint",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 30),
            const Image(
              image: AssetImage("assets/GetStarted.png"),
              height: 300,
              width: double.infinity,
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildButton("Login", () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const LoginPage()));
                }),
                const SizedBox(width: 20),
                _buildButton("Register", () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const RegisterScreen()));
                }),
              ],
            ),
            const SizedBox(height: 30),
            const Divider(
                color: Colors.black, thickness: 1, indent: 50, endIndent: 50),
            const SizedBox(height: 30),
            SizedBox(
              width: 300,
              height: 50,
              child: ElevatedButton(
                onPressed: _googleSignIn,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Image(
                        image: AssetImage('assets/google.png'),
                        height: 20,
                        width: 20),
                    const SizedBox(width: 10),
                    const Text(
                      "Sign in with Google",
                      style: TextStyle(fontSize: 18, color: Colors.black),
                    ),
                  ],
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildButton(String text, VoidCallback onPressed) {
    return SizedBox(
      width: 130,
      height: 60,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(35)),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 18, color: Colors.black),
        ),
      ),
    );
  }
}
