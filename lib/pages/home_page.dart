import 'package:flutter/material.dart';
import 'location_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/CustomAppBar.dart';
import '../widgets/CustomDrawer.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final supabase = Supabase.instance.client;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      LocationService.checkAndRequestLocation(context);
    });
  }

  Future<void> _signOut() async {
    await supabase.auth.signOut();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: CustomAppBar(title: "Presence Point", scaffoldKey: _scaffoldKey),
      drawer: CustomDrawer(),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 50),
            ElevatedButton(
                onPressed: () {}, child: Text("Check Detailed Report")),
            SizedBox(
              height: 20,
            ),
            ElevatedButton(
              onPressed: _signOut,
              child: const Text("Sign out"),
            ),
          ],
        ),
      ),
    );
  }
}
