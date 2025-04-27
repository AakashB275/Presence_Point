import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/CustomAppBar.dart';
import '../widgets/CustomDrawer.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  final supabase = Supabase.instance.client;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isLoading = false;

  // Dynamic data variables
  int totalEmployees = 0;
  int presentToday = 0;
  int absentToday = 0;
  int locationsCount = 0;
  String orgName = '';

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    setState(() => _isLoading = true);
    try {
      // Get current organization ID from user state
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // Get user's org_id
      final userData = await supabase
          .from('users')
          .select('org_id')
          .eq('auth_user_id', user.id)
          .single();

      final orgId = userData['org_id'] as String;

      // Fetch all data in parallel
      final results = await Future.wait([
        _getTotalEmployees(orgId),
        _getPresentTodayCount(orgId),
        _getLocationsCount(orgId),
        _getOrgName(orgId),
      ]);

      setState(() {
        totalEmployees = results[0] as int;
        presentToday = results[1] as int;
        absentToday = totalEmployees - presentToday;
        locationsCount = results[2] as int;
        orgName = results[3] as String;
      });
    } catch (e) {
      debugPrint('Error fetching dashboard data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<int> _getTotalEmployees(String orgId) async {
    final response = await supabase
        .from('users')
        .select('auth_user_id')
        .eq('org_id', orgId)
        .count();

    return response.count;
  }

  Future<int> _getPresentTodayCount(String orgId) async {
    try {
      // Get UTC timestamps for today
      final now = DateTime.now().toUtc();
      final startOfDay = DateTime.utc(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      debugPrint('Fetching attendance between:');
      debugPrint('Start: ${startOfDay.toIso8601String()}');
      debugPrint('End: ${endOfDay.toIso8601String()}');

      final response = await supabase
          .from('attendance')
          .select('auth_user_id')
          .eq('org_id', orgId)
          .gte('check_in_time', startOfDay.toIso8601String())
          .lt('check_in_time', endOfDay.toIso8601String())
          .count(CountOption.exact);

      debugPrint('Found ${response.count} records');
      debugPrint('Data: ${response.data}');

      return response.count;
    } catch (e) {
      debugPrint('Error in _getPresentTodayCount: $e');
      return 0;
    }
  }

  Future<int> _getLocationsCount(String orgId) async {
    try {
      final response = await supabase
          .from('organization') // Try singular form if plural doesn't exist
          .select('locations_count')
          .eq('org_id', orgId)
          .single();

      return response['locations_count'] ?? 0;
    } catch (e) {
      debugPrint('Error fetching locations count: $e');
      return 0; // Return default value
    }
  }

  Future<String> _getOrgName(String orgId) async {
    try {
      final response = await supabase
          .from('organization') // Try singular form
          .select('org_name')
          .eq('org_id', orgId)
          .single();

      return response['org_name'] ?? 'Organization';
    } catch (e) {
      debugPrint('Error fetching organization name: $e');
      return 'Organization'; // Fallback name
    }
  }

  // Dynamic stats based on fetched data
  Map<String, Map<String, dynamic>> get stats => {
        'Total Employees': {'value': '$totalEmployees', 'color': Colors.indigo},
        'Present Today': {'value': '$presentToday', 'color': Colors.green},
        'Absent Today': {'value': '$absentToday', 'color': Colors.red},
        'Locations': {'value': '$locationsCount', 'color': Colors.orange},
      };

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final shouldPop = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Exit App?'),
            content: const Text('Are you sure you want to exit the app?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Yes'),
              ),
            ],
          ),
        );
        if (shouldPop ?? false) SystemNavigator.pop();
      },
      child: Scaffold(
        key: _scaffoldKey,
        appBar: CustomAppBar(
          title: "$orgName Dashboard",
          scaffoldKey: _scaffoldKey,
        ),
        drawer: CustomDrawer(),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "$orgName Dashboard",
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                  ),
                ),
                const SizedBox(height: 16),
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _buildStatsRow(),
                const SizedBox(height: 24),
                const Text(
                  "Quick Actions",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 1.2,
                    children: [
                      _buildActionCard(
                        title: "Manage Team",
                        icon: Icons.people_alt,
                        color: Colors.indigo,
                        onTap: () => Navigator.pushNamed(context, '/team'),
                      ),
                      _buildActionCard(
                        title: "Attendance Reports",
                        icon: Icons.analytics,
                        color: Colors.green,
                        onTap: () => Navigator.pushNamed(context, '/reports'),
                      ),
                      _buildActionCard(
                        title: "Geofence Settings",
                        icon: Icons.location_pin,
                        color: Colors.orange,
                        onTap: () =>
                            Navigator.pushNamed(context, '/geofencing'),
                      ),
                      _buildActionCard(
                        title: "System Settings",
                        icon: Icons.settings,
                        color: Colors.purple,
                        onTap: () => Navigator.pushNamed(context, '/settings'),
                      ),
                    ],
                  ),
                ),
                _buildSignOutButton(),
              ],
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _fetchDashboardData,
          tooltip: 'Refresh',
          child: const Icon(Icons.refresh),
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: stats.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          final key = stats.keys.elementAt(index);
          final value = stats[key]!['value'] as String;
          final color = stats[key]!['color'] as Color;

          return Container(
            width: 160,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  key,
                  style: TextStyle(
                    fontSize: 12,
                    color: color.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 28, color: color),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignOutButton() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _isLoading ? null : _signOut,
          icon: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.logout),
          label: const Text("Sign Out"),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red,
            padding: const EdgeInsets.symmetric(vertical: 14),
            side: const BorderSide(color: Colors.red),
          ),
        ),
      ),
    );
  }

  Future<void> _signOut() async {
    setState(() => _isLoading = true);
    try {
      await supabase.auth.signOut();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error signing out: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
