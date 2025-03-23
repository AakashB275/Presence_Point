import 'package:flutter/material.dart';
import 'package:presence_point_2/pages/home_page.dart';
import 'package:presence_point_2/pages/leaves.dart';
import 'package:presence_point_2/pages/login.dart';
import 'package:presence_point_2/wrapper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import './pages/analytics_page.dart';
import './pages/register.dart';
import './pages/profile.dart';
import './pages/geofencing-implementation.dart';
import 'pages/new_organisation.dart';
import './pages/organisation_details.dart';
import './pages/user_checkin.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://gmnswrptuwhegutbsesb.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdtbnN3cnB0dXdoZWd1dGJzZXNiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDIyMjIzMjYsImV4cCI6MjA1Nzc5ODMyNn0.9-DwmzLXxJSiM0C9baDTQp_1Kq0W8PYeOWZmV8q4jbA',
  );

  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    initialRoute: '/',
    routes: {
      '/': (context) => Wrapper(),
      '/home': (context) => HomePage(),
      '/analytics': (context) => AnalyticsPage(),
      '/login': (context) => LoginPage(),
      '/register': (context) => RegisterScreen(),
      '/organisationdetails': (context) => OrganisationDetails(),
      '/leave': (context) => LeavesScreen(),
      '/usercheckin': (context) => UserCheckin(),
      '/geofencingscreen': (context) => GeofencingMapScreen(),
      '/neworganisation': (context) => NewOrganisation(),
      '/profile': (context) => ProfileScreen(),
    },
  ));
}
