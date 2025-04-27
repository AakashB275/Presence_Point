import 'package:flutter/material.dart';
import 'package:presence_point_2/pages/Admin_Pages/join_admin_page.dart';
import 'package:presence_point_2/pages/Admin_Pages/org_list_page.dart';
import 'package:presence_point_2/pages/Features/notices.dart';
import 'package:presence_point_2/pages/admin_home_page.dart';
import 'package:presence_point_2/pages/employee_home_page.dart';
import 'package:provider/provider.dart';
import 'package:presence_point_2/services/user_state.dart';
import 'package:presence_point_2/pages/Features/leaves.dart';
import 'package:presence_point_2/pages/Auth/login.dart';
import 'package:presence_point_2/wrapper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'pages/Features/analytics_page.dart';
import 'pages/Auth/register.dart';
import 'pages/User_Pages/profile.dart';
import 'pages/Organization/organization_location_page.dart';
import 'pages/Organization/new_organisation.dart';
import 'pages/Organization/organisation_details.dart';
import 'pages/User_Pages/user_checkin.dart';
import 'pages/geoloc.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://sejizobigqffizryqshy.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNlaml6b2JpZ3FmZml6cnlxc2h5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDMxODQ0NTEsImV4cCI6MjA1ODc2MDQ1MX0.M-rsy0lDi9EbZOpRoCiDnrpH11yuX2bYCNeW4EadJMo',
  );

  runApp(const MyApp());
}

class YourScreen extends StatelessWidget {
  const YourScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pushReplacementNamed(context, '/home');
        return false; // prevent default back action
      },
      child: Scaffold(
        appBar: AppBar(title: Text('Your Screen')),
        body: Center(child: Text('Screen Content')),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => UserState(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        initialRoute: '/',
        routes: {
          '/': (context) => const Wrapper(),
          '/home': (context) {
            final userState = Provider.of<UserState>(context, listen: false);
            return userState.isAdmin
                ? const AdminHomePage()
                : const EmployeeHomePage();
          },
          '/analytics': (context) => AnalyticsPage(),
          '/login': (context) => LoginPage(),
          '/register': (context) => RegisterScreen(),
          '/organisationdetails': (context) => const OrganisationDetails(),
          '/leave': (context) => LeavesScreen(),
          '/usercheckin': (context) => UserCheckin(),
          '/organizationlocation': (context) => OrganizationLocationScreen(),
          '/neworganisation': (context) => const NewOrganisation(),
          '/profile': (context) => ProfileScreen(),
          '/geofencing': (context) => GeoAttendancePage(),
          '/notices': (context) => NoticesPage(),
          '/team': (context) => AdminEmployeesPage(),
        },
        onGenerateRoute: (settings) {
          return MaterialPageRoute(
            builder: (context) => Scaffold(
              appBar: AppBar(title: const Text('Page Not Found')),
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.pushNamed(context, '/'),
                  child: const Text('Go Home'),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
