import 'package:shared_preferences/shared_preferences.dart';

class Prefs {
  static Future<void> setFirstTimeUser(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('first_time', value);
  }

  static Future<bool> isFirstTimeUser() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('first_time') ?? true;
  }

  static Future<void> setUserJoinedOrg(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('joined_org', value);
  }

  static Future<bool> hasJoinedOrg() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('joined_org') ?? false;
  }
}
