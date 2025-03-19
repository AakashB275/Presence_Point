import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import './wrapper.dart';
import './pages/login.dart';
import './pages/analytics_page.dart';
import './pages/home_page.dart';
import './pages/register.dart';
import './pages/profile.dart';
import './pages/geofencing-implementation.dart';

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
      '/login': (context) => LoginPage(),
      '/home': (context) => GeofencingMapScreen(),
      '/register': (context) => RegisterScreen(),
      '/profile': (context) => Profile(),
      '/analytics': (context) => AnalyticsPage(),
    },
  ));
}
