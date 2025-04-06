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

      // Load persisted state
      _isFirstTime = prefs.getBool('first_time') ?? true;
      _hasJoinedOrg = prefs.getBool('joined_org') ?? false;

      if (_hasJoinedOrg) {
        _currentOrgId = prefs.getString('current_org_id');
        _currentOrgName = prefs.getString('current_org_name');
        _currentOrgCode = prefs.getString('current_org_code');

        // Load user role if logged in and has org
        if (isLoggedIn && _currentOrgId != null) {
          _userRole = await _fetchUserRole(_currentOrgId!);
        }
      }
    } catch (e) {
      debugPrint("UserState initialization error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> _fetchUserRole(String orgId) async {
    try {
      final response = await supabase
          .from('users')
          .select('role')
          .eq('auth_user_id', supabase.auth.currentUser!.id)
          .eq('org_id', orgId)
          .maybeSingle();

      return response?['role']?.toString().toLowerCase();
    } catch (e) {
      debugPrint("Error fetching user role: $e");
      return null;
    }
  }

// In your UserState class
  Future<Map<String, dynamic>?> verifyOrganization(String orgCode) async {
    try {
      final response = await supabase
          .from('organization') // Make sure this matches your table name
          .select('id, name, org_code')
          .eq('org_code', orgCode)
          .maybeSingle();

      if (response != null) {
        return {
          'org_id': response['id'],
          'org_name': response['name'],
          'org_code': response['org_code'],
        };
      }
      return null;
    } catch (e) {
      debugPrint("Organization verification error: $e");
      return null;
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
      final userId = supabase.auth.currentUser!.id;

      // Persist org data
      await prefs.setBool('joined_org', true);
      await prefs.setString('current_org_id', orgId);
      await prefs.setString('current_org_name', orgName);
      await prefs.setString('current_org_code', orgCode);

      // Assign role in Supabase
      await supabase.from('user_roles').upsert({
        'user_id': userId,
        'org_id': orgId,
        'role': role,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Update state
      _currentOrgId = orgId;
      _currentOrgName = orgName;
      _currentOrgCode = orgCode;
      _hasJoinedOrg = true;
      _userRole = role;

      notifyListeners();
    } catch (e) {
      debugPrint("Error joining organization: $e");
      rethrow;
    }
  }

  Future<void> leaveOrganization() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Clear persisted org data
      await prefs.remove('current_org_id');
      await prefs.remove('current_org_name');
      await prefs.remove('current_org_code');
      await prefs.setBool('joined_org', false);

      // Update state
      _currentOrgId = null;
      _currentOrgName = null;
      _currentOrgCode = null;
      _hasJoinedOrg = false;
      _userRole = null;

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
    await _initialize();
  }

  // Role checking helpers
  bool get isAdmin => _userRole == 'admin';
  bool get isEmployee => !isAdmin && _userRole != null;

  Future<bool> checkPermission(String requiredRole) async {
    if (_currentOrgId == null) return false;

    // Refresh role if not set
    _userRole ??= await _fetchUserRole(_currentOrgId!);

    // Simple role hierarchy check
    switch (requiredRole.toLowerCase()) {
      case 'admin':
        return isAdmin;
      default:
        return true;
    }
  }
}
