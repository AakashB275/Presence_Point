import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CustomDrawer extends StatelessWidget {
  final supabase = Supabase.instance.client;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.amber),
            child: Text(
              'Menu',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            leading: Icon(Icons.home),
            title: const Text('Home'),
            onTap: () {
              Navigator.pushReplacementNamed(context, '/home');
            },
          ),
          ListTile(
            leading: Icon(Icons.analytics_rounded),
            title: const Text('Analytics'),
            onTap: () {
              Navigator.pushReplacementNamed(context, '/analytics');
            },
          ),
          // ListTile(
          //   leading: Icon(Icons.dashboard),
          //   title: const Text('Dashboard'),
          //   onTap: () {
          //     Navigator.pushReplacementNamed(context, '/dashboard');
          //   },
          // ),
          ListTile(
            leading: Icon(Icons.notification_important),
            title: const Text('Important Notice'),
            onTap: () {
              Navigator.pushReplacementNamed(context, '/notices');
            },
          ),
          ListTile(
            leading: Icon(Icons.settings),
            title: const Text('Settings'),
            onTap: () {
              Navigator.pushReplacementNamed(context, '/settings');
            },
          ),
          ListTile(
            leading: Icon(Icons.location_pin),
            title: const Text('Leave Application'),
            onTap: () {
              Navigator.pushReplacementNamed(context, '/leave');
            },
          ),
          ListTile(
            leading: Icon(Icons.timer),
            title: const Text('Track Time (CheckIn)'),
            onTap: () {
              Navigator.pushReplacementNamed(context, '/geofencing');
            },
          ),
          ListTile(
            leading: Icon(Icons.group),
            title: const Text('Organisation'),
            onTap: () {
              Navigator.pushReplacementNamed(context, '/neworganisation');
            },
          ),
          SizedBox(
            height: 40,
            child: ElevatedButton(
              onPressed: () async {
                await supabase.auth.signOut();
                if (context.mounted) {
                  Navigator.pushReplacementNamed(context, '/login');
                }
              },
              child: const Text("Sign Out"),
            ),
          ),
        ],
      ),
    );
  }
}
