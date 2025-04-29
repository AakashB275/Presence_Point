import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:presence_point_2/pages/Auth/get_started.dart';
import 'package:presence_point_2/services/user_state.dart';
import 'package:presence_point_2/pages/Auth/onboarding_screen.dart';
import 'package:presence_point_2/pages/Organization/new_organisation.dart';
import 'package:presence_point_2/pages/employee_home_page.dart';
import 'package:presence_point_2/pages/admin_home_page.dart';

class Wrapper extends StatefulWidget {
  const Wrapper({super.key});

  @override
  State<Wrapper> createState() => _WrapperState();
}

class _WrapperState extends State<Wrapper> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _verifyAuthState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _verifyAuthState();
    }
  }

  Future<void> _verifyAuthState() async {
    final userState = Provider.of<UserState>(context, listen: false);
    await userState.refreshUserState();

    if (!mounted) return;

    if (!userState.isLoggedIn) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/login',
        (route) => false,
      );
      return;
    }

    if (!userState.hasJoinedOrg) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/neworganisation',
        (route) => false,
      );
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final userState = Provider.of<UserState>(context);

    // Add this debug print
    debugPrint(
        "Wrapper build - isAdmin: ${userState.isAdmin}, role: ${userState.userRole}");

    if (userState.isLoading) {
      return _buildLoadingScreen();
    }

    if (userState.isFirstTime) {
      return OnboardingScreen();
    }

    if (!userState.isLoggedIn) {
      return const GetStarted();
    }

    if (!userState.hasJoinedOrg) {
      return const NewOrganisation();
    }

    // Role-based routing with additional verification
    return _RoleGuardedHomePage(userState: userState);
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              "Loading your workspace...",
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleGuardedHomePage extends StatelessWidget {
  final UserState userState;

  const _RoleGuardedHomePage({required this.userState});

  @override
  Widget build(BuildContext context) {
    debugPrint("Current user role: ${userState.userRole}");
    debugPrint("Is admin: ${userState.isAdmin}");

    // Double-check role before showing page
    if (userState.isAdmin) {
      return const AdminHomePage();
    } else {
      return const EmployeeHomePage();
    }
  }
}
