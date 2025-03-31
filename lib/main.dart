import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:presence_point_2/services/user_state.dart';
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
    url: 'https://sejizobigqffizryqshy.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNlaml6b2JpZ3FmZml6cnlxc2h5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDMxODQ0NTEsImV4cCI6MjA1ODc2MDQ1MX0.M-rsy0lDi9EbZOpRoCiDnrpH11yuX2bYCNeW4EadJMo',
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
          '/home': (context) => HomePage(),
          '/analytics': (context) => AnalyticsPage(),
          '/login': (context) => LoginPage(),
          '/register': (context) => RegisterScreen(),
          '/organisationdetails': (context) => OrganisationDetails(),
          '/leave': (context) => LeavesScreen(),
          '/usercheckin': (context) => UserCheckin(),
          '/organizationlocation': (context) => OrganizationLocationScreen(),
          '/neworganisation': (context) => NewOrganisation(),
          '/profile': (context) => ProfileScreen(),
          '/geofencing': (context) => GeofencingPage(),
        },
      ),
    );
  }
}
