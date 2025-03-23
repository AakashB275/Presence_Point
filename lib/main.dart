import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:presence_point_2/services/user_state.dart'; // You'll need to create this file
import 'package:presence_point_2/pages/home_page.dart';
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
import 'pages/Features/geofencing_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://gmnswrptuwhegutbsesb.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdtbnN3cnB0dXdoZWd1dGJzZXNiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDIyMjIzMjYsImV4cCI6MjA1Nzc5ODMyNn0.9-DwmzLXxJSiM0C9baDTQp_1Kq0W8PYeOWZmV8q4jbA',
  );

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => UserState(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        initialRoute: '/',
        routes: {
          '/': (context) => Wrapper(),
          '/home': (context) => GeofencingPage(),
          '/analytics': (context) => AnalyticsPage(),
          '/login': (context) => LoginPage(),
          '/register': (context) => RegisterScreen(),
          '/organisationdetails': (context) => OrganisationDetails(),
          '/leave': (context) => LeavesScreen(),
          '/usercheckin': (context) => UserCheckin(),
          '/organizationlocation': (context) => OrganizationLocationScreen(),
          '/neworganisation': (context) => NewOrganisation(),
          '/profile': (context) => ProfileScreen(),
        },
      ),
    );
  }
}
