import 'package:flutter/material.dart';
import 'package:presence_point_2/pages/home_page.dart';
import 'package:presence_point_2/pages/login.dart';
import 'package:presence_point_2/pages/onboarding_screen.dart'; // Add onboarding screen
import 'package:presence_point_2/pages/new_organisation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Wrapper extends StatefulWidget {
  @override
  _WrapperState createState() => _WrapperState();
}

class _WrapperState extends State<Wrapper> {
  final SupabaseClient supabase = Supabase.instance.client;
  bool? hasJoinedOrg;
  bool? isFirstTime;

  @override
  void initState() {
    super.initState();
    _checkUserStatus();
  }

  Future<void> _checkUserStatus() async {
    final prefs = await SharedPreferences.getInstance();
    bool firstTime = prefs.getBool('first_time') ?? true;
    bool joinedOrg = prefs.getBool('joined_org') ?? false;

    setState(() {
      isFirstTime = firstTime;
      hasJoinedOrg = joinedOrg;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isFirstTime == null || hasJoinedOrg == null) {
      return Scaffold(
          body: Center(child: CircularProgressIndicator())); // Loading state
    }

    if (isFirstTime!) {
      return OnboardingScreen();
    } else if (supabase.auth.currentUser == null) {
      return LoginPage();
    } else if (!hasJoinedOrg!) {
      return NewOrganisation();
    } else {
      return HomePage();
    }
  }
}
