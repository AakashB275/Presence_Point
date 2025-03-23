// lib/services/user_state.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserState extends ChangeNotifier {
  final SupabaseClient supabase = Supabase.instance.client;
  bool isFirstTime = true;
  bool hasJoinedOrg = false;
  bool isLoading = true;

  UserState() {
    initialize();
  }

  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      isFirstTime = prefs.getBool('first_time') ?? true;
      hasJoinedOrg = prefs.getBool('joined_org') ?? false;

      // Optional: Check with Supabase if user has joined org
      final user = supabase.auth.currentUser;
      if (user != null && !hasJoinedOrg) {
        // You could verify with Supabase here
      }
    } catch (e) {
      print("Error initializing user state: $e");
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('first_time', false);
    isFirstTime = false;
    notifyListeners();
  }

  Future<void> joinOrganization() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('joined_org', true);
    hasJoinedOrg = true;
    notifyListeners();
  }

  // Check if user is logged in
  bool get isLoggedIn => supabase.auth.currentUser != null;

  // Reset org status (if user logs out)
  Future<void> resetOrgStatus() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('joined_org', false);
    hasJoinedOrg = false;
    notifyListeners();
  }
}
