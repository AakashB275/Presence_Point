import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserState extends ChangeNotifier {
  final SupabaseClient supabase = Supabase.instance.client;
  bool get isLoggedIn => supabase.auth.currentUser != null;
  bool isFirstTime = true;
  bool hasJoinedOrg = false;
  bool isLoading = true;

  // Organization properties
  String? _currentOrgId;
  String? _currentOrgName;
  String? _currentOrgCode;

  // Getters
  String? get currentOrgId => _currentOrgId;
  String? get currentOrgName => _currentOrgName;
  String? get currentOrgCode => _currentOrgCode;

  UserState() {
    initialize();
  }
  Future<String?> getUserRole(String orgId) async {
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) return null;

    final response = await supabase
        .from('user_roles')
        .select('role')
        .eq('user_id', currentUser.id)
        .eq('org_id', orgId)
        .maybeSingle();

    return response?['role'];
  }

  Future<bool> isUserAdmin(String orgId) async {
    final role = await getUserRole(orgId);
    return role == 'admin';
  }

  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      isFirstTime = prefs.getBool('first_time') ?? true;
      hasJoinedOrg = prefs.getBool('joined_org') ?? false;

      if (hasJoinedOrg) {
        _currentOrgId = prefs.getString('current_org_id');
        _currentOrgName = prefs.getString('current_org_name');
        _currentOrgCode = prefs.getString('current_org_code');
      }
    } catch (e) {
      debugPrint("Error initializing user state: $e");
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> verifyOrganization(String orgCode) async {
    try {
      final response = await supabase
          .from('organization')
          .select('org_id, org_name, org_code')
          .eq('org_code', orgCode)
          .maybeSingle();
      return response;
    } catch (e) {
      debugPrint("Error verifying organization: $e");
      return null;
    }
  }

  Future<void> joinOrganization({
    required String orgId,
    required String orgName,
    required String orgCode,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('joined_org', true);
    await prefs.setString('current_org_id', orgId);
    await prefs.setString('current_org_name', orgName);
    await prefs.setString('current_org_code', orgCode);

    _currentOrgId = orgId;
    _currentOrgName = orgName;
    _currentOrgCode = orgCode;
    hasJoinedOrg = true;

    notifyListeners();
  }

  Future<void> leaveOrganization() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_org_id');
    await prefs.remove('current_org_name');
    await prefs.remove('current_org_code');
    await prefs.setBool('joined_org', false);

    _currentOrgId = null;
    _currentOrgName = null;
    _currentOrgCode = null;
    hasJoinedOrg = false;

    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('first_time', false);
    isFirstTime = false;
    notifyListeners();
  }
}
