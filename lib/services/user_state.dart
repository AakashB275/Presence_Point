import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserState extends ChangeNotifier {
  final SupabaseClient supabase = Supabase.instance.client;

  // Authentication state
  bool _isLoading = true;
  bool _isFirstTime = true;
  bool _hasJoinedOrg = false;
  String? _userRole;

  // Organization state
  String? _currentOrgId;
  String? _currentOrgName;
  String? _currentOrgCode;

  // Getters
  bool get isLoggedIn => supabase.auth.currentUser != null;
  bool get isLoading => _isLoading;
  bool get isFirstTime => _isFirstTime;
  bool get hasJoinedOrg => _hasJoinedOrg;
  String? get userRole => _userRole;
  String? get currentOrgId => _currentOrgId;
  String? get currentOrgName => _currentOrgName;
  String? get currentOrgCode => _currentOrgCode;

  UserState() {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      _isFirstTime = prefs.getBool('first_time') ?? true;
      _hasJoinedOrg = prefs.getBool('joined_org') ?? false;

      if (_hasJoinedOrg) {
        _currentOrgId = prefs.getString('current_org_id');
        _currentOrgName = prefs.getString('current_org_name');
        _currentOrgCode = prefs.getString('current_org_code');
        _userRole = prefs.getString('user_role');

        // If we have an org but no role, or if we're logged in, fetch fresh data
        if (isLoggedIn && _currentOrgId != null) {
          final freshRole = await _fetchUserRole(_currentOrgId!);
          if (freshRole != null) {
            _userRole = freshRole;
            await prefs.setString('user_role', _userRole!);
          }
        }
      }

      debugPrint(
          "UserState initialized - Role: $_userRole, OrgID: $_currentOrgId");
    } catch (e) {
      debugPrint("UserState initialization error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> _fetchUserRole(String orgId) async {
    try {
      final userId = supabase.auth.currentUser!.id;
      debugPrint("Fetching role for user $userId in org $orgId");

      final response = await supabase
          .from('users')
          .select('role')
          .eq('auth_user_id', userId)
          .eq('org_id', orgId)
          .maybeSingle();

      if (response == null) {
        debugPrint("No user record found for this org");
        return null;
      }

      final role = response['role']?.toString().toLowerCase();
      debugPrint("Fetched role: $role");

      if (role == null) {
        debugPrint("Role is null in database record");
      }

      return role;
    } catch (e) {
      debugPrint("Error fetching user role: $e");
      return null;
    }
  }

  Future<void> handleUserRegistration() async {
    _userRole = 'employee';
    notifyListeners();
  }

  Future<Map<String, dynamic>?> verifyOrganization(String orgCode) async {
    try {
      final response = await supabase
          .from('organization')
          .select('org_id, org_name, org_code')
          .eq('org_code', orgCode)
          .maybeSingle();

      if (response != null) {
        return {
          'org_id': response['org_id'],
          'org_name': response['org_name'],
          'org_code': response['org_code'],
        };
      }
      return null;
    } catch (e) {
      debugPrint("Organization verification error: $e");
      return null;
    }
  }

  Future<void> createJoinRequest({required String orgId}) async {
    try {
      final currentUser = supabase.auth.currentUser!;
      final authUserId = currentUser.id;

      // First check if user exists
      final existingUser = await supabase
          .from('users')
          .select('auth_user_id')
          .eq('auth_user_id', authUserId)
          .maybeSingle();

      if (existingUser == null) {
        throw Exception("User not registered. Please contact admin.");
      }

      // Now check if a join request already exists
      final existingRequest = await supabase
          .from('organization_join_requests')
          .select('id')
          .eq('user_id', authUserId)
          .eq('org_id', orgId)
          .eq('status', 'pending')
          .maybeSingle();

      if (existingRequest != null) {
        throw Exception("Join request already sent and pending.");
      }

      // Create the join request
      await supabase.from('organization_join_requests').insert({
        'user_id': authUserId,
        'org_id': orgId,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      });

      debugPrint("Join request sent successfully.");
    } catch (e) {
      debugPrint("Error creating join request: $e");
      rethrow;
    }
  }

  Future<void> createOrganization({
    required String orgName,
    required String orgCode,
  }) async {
    try {
      final userId = supabase.auth.currentUser!.id;

      final orgData = await supabase
          .from('organization')
          .insert({
            'org_name': orgName,
            'org_code': orgCode,
            'createdby': userId,
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      debugPrint("Organization created with ID: ${orgData['org_id']}");

      // Make sure to wait for joinOrganization to complete
      await joinOrganization(
        orgId: orgData['org_id'],
        orgName: orgName,
        orgCode: orgCode,
        role: 'admin', // Set role to admin for org creator
      );

      // Force refresh user state to ensure role is updated
      await refreshUserState();

      debugPrint("After create org - Role: $_userRole, isAdmin: $isAdmin");

      notifyListeners();
    } catch (e) {
      debugPrint("Error creating organization: $e");
      rethrow;
    }
  }

  Future<void> joinOrganization({
    required String orgId,
    required String orgName,
    required String orgCode,
    String role = 'employee',
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final authUserId = supabase.auth.currentUser!.id;

      debugPrint("Joining organization with role: $role");

      // First, check if user exists in the users table
      final existingUser = await supabase
          .from('users')
          .select('id')
          .eq('auth_user_id', authUserId)
          .maybeSingle();

      // If user doesn't exist, create the user first
      if (existingUser == null) {
        await supabase.from('users').insert({
          'auth_user_id': authUserId,
          'org_id': orgId,
          'role': role,
          'created_at': DateTime.now().toIso8601String(),
        });
        debugPrint("Created new user with role: $role");
      } else {
        // Update existing user's org and role
        await supabase.from('users').update({
          'org_id': orgId,
          'role': role,
        }).eq('auth_user_id', authUserId);
        debugPrint("Updated existing user with role: $role");
      }

      // Save to SharedPreferences
      await prefs.setBool('joined_org', true);
      await prefs.setString('current_org_id', orgId);
      await prefs.setString('current_org_name', orgName);
      await prefs.setString('current_org_code', orgCode);
      await prefs.setString(
          'user_role', role); // Add this line to save role to prefs

      // Update state
      _currentOrgId = orgId;
      _currentOrgName = orgName;
      _currentOrgCode = orgCode;
      _hasJoinedOrg = true;
      _userRole = role;

      debugPrint("Join organization complete - Role set to: $_userRole");

      notifyListeners();
    } catch (e) {
      debugPrint("Error joining organization: $e");
      rethrow;
    }
  }

  Future<void> leaveOrganization() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.remove('current_org_id');
      await prefs.remove('current_org_name');
      await prefs.remove('current_org_code');
      await prefs.remove('user_role'); // Also remove role
      await prefs.setBool('joined_org', false);

      _currentOrgId = null;
      _currentOrgName = null;
      _currentOrgCode = null;
      _hasJoinedOrg = false;
      _userRole = 'employee';

      notifyListeners();
    } catch (e) {
      debugPrint("Error leaving organization: $e");
      rethrow;
    }
  }

  Future<void> completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('first_time', false);
    _isFirstTime = false;
    notifyListeners();
  }

  Future<void> refreshUserState() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();

      if (_currentOrgId != null) {
        // Try to fetch role from database
        _userRole = await _fetchUserRole(_currentOrgId!);

        // If still null, check if this user created the organization
        if (_userRole == null) {
          final orgData = await supabase
              .from('organization')
              .select('createdby')
              .eq('org_id', _currentOrgId!)
              .maybeSingle();

          if (orgData != null &&
              orgData['createdby'] == supabase.auth.currentUser?.id) {
            _userRole = 'admin';
            debugPrint("Assigning admin role as org creator");
          } else {
            _userRole = 'employee'; // Default fallback
            debugPrint("Assigning default employee role");
          }

          // Save the determined role
          await prefs.setString('user_role', _userRole!);
        } else {
          // Save fetched role to prefs
          await prefs.setString('user_role', _userRole!);
        }

        debugPrint("Refreshed user state - Current role: $_userRole");
      }
    } catch (e) {
      debugPrint("Error refreshing user state: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  bool get isAdmin => _userRole?.toLowerCase() == 'admin';
  bool get isEmployee => !isAdmin && _userRole != null;

  Future<bool> checkPermission(String requiredRole) async {
    if (_currentOrgId == null) return false;

    if (_userRole == null) {
      _userRole = await _fetchUserRole(_currentOrgId!);

      // Also save to prefs if we had to fetch it
      if (_userRole != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_role', _userRole!);
      }
    }

    switch (requiredRole.toLowerCase()) {
      case 'admin':
        return isAdmin;
      default:
        return true;
    }
  }
}
