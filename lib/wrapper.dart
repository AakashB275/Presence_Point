// lib/wrapper.dart
import 'package:flutter/material.dart';
import 'package:presence_point_2/pages/Auth/get_started.dart';
import 'package:provider/provider.dart';
import 'package:presence_point_2/services/user_state.dart';
import 'package:presence_point_2/pages/Auth/login.dart';
import 'package:presence_point_2/pages/Auth/onboarding_screen.dart';
import 'package:presence_point_2/pages/Organization/new_organisation.dart';
import 'package:presence_point_2/pages/home_page.dart';

class Wrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Access the user state
    final userState = Provider.of<UserState>(context);

    // Show loading indicator while initializing
    if (userState.isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text("Setting things up...",
                  style: TextStyle(fontSize: 16, color: Colors.grey[700]))
            ],
          ),
        ),
      );
    }

    // User flow decision tree
    if (userState.isFirstTime) {
      return OnboardingScreen();
    } else if (!userState.isLoggedIn) {
      return GetStarted();
    } else if (!userState.hasJoinedOrg) {
      return NewOrganisation();
    } else {
      return HomePage();
    }
  }
}
