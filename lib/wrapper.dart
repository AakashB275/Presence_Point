import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import './pages/home_page.dart';
import 'package:presence_point_2/pages/get_started.dart';

class Wrapper extends StatefulWidget {
  const Wrapper({super.key});

  @override
  _WrapperState createState() => _WrapperState();
}

class _WrapperState extends State<Wrapper> {
  final supabase = Supabase.instance.client;
  late Stream<AuthState> authStateStream;

  @override
  void initState() {
    super.initState();
    authStateStream = supabase.auth.onAuthStateChange;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<AuthState>(
        stream: authStateStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.connectionState == ConnectionState.none) {
            return const Center(child: Text('No internet connection'));
          }
          // If user is logged in, go to HomePage, otherwise show GetStarted screen
          final session = supabase.auth.currentSession;
          return session != null ? HomePage() : const GetStarted();
        },
      ),
    );
  }
}
