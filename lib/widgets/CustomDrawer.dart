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
            leading: Icon(Icons.analytics_rounded),
            title: const Text('Analytics'),
            onTap: () {
              Navigator.pushReplacementNamed(context, '/analytics');
            },
          ),
          ListTile(
            leading: Icon(Icons.dashboard),
            title: const Text('Dashboard'),
            onTap: () {
              Navigator.pushReplacementNamed(context, '/dashboard');
            },
          ),
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
            leading: Icon(Icons.home),
            title: const Text('Home'),
            onTap: () {
              Navigator.pushReplacementNamed(context, '/home');
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
