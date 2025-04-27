import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:presence_point_2/widgets/CustomAppBar.dart';
import 'package:presence_point_2/widgets/CustomDrawer.dart';

class ProfileScreen extends StatefulWidget {
  static const routeName = '/profile';

  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final supabase = Supabase.instance.client;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final _formKey = GlobalKey<FormState>();

  late Future<Map<String, dynamic>> _profileFuture;
  bool _isEditing = false;
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;

  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _initializeNotifications();
    _loadProfile();
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    tz.initializeTimeZones();
  }

  void _loadProfile() {
    _profileFuture = _fetchUserProfile();
  }

  Future<Map<String, dynamic>> _fetchUserProfile() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      // Fetch user data
      final userResponse = await supabase
          .from('users')
          .select(
              'name, email, created_at, organization:org_id (org_name, org_code)')
          .eq('auth_user_id', userId)
          .single();

      // Fetch user's reminders
      final remindersResponse = await supabase
          .from('location_reminders')
          .select('id, notification_id, reminder_time, created_at, is_active')
          .eq('user_id', userId)
          .eq('is_active', true)
          .order('reminder_time');

      // Format the time for display
      final formattedReminders = remindersResponse.map((reminder) {
        return {
          ...reminder,
          'reminder_time': _formatTimeForDisplay(reminder['reminder_time']),
        };
      }).toList();

      return {
        ...userResponse,
        'reminders': formattedReminders,
      };
    } catch (e) {
      print("Failed to load profile: $e");
      throw Exception('Failed to load profile: ${e.toString()}');
    }
  }

  String _formatTimeForDisplay(dynamic timeValue) {
    if (timeValue == null) return 'Invalid time';

    if (timeValue is String) {
      // Handle different time string formats
      final parts = timeValue.split(':');
      if (parts.length >= 2) {
        return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
      }
      return timeValue;
    }

    return timeValue.toString();
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      setState(() => _isEditing = false);

      await supabase.from('users').update({
        'name': _nameController.text,
      }).eq('auth_user_id', supabase.auth.currentUser!.id);

      _loadProfile();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating profile: ${e.toString()}')),
      );
      setState(() => _isEditing = true);
    }
  }

  Future<void> _selectTimeAndScheduleNotification() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (picked != null && mounted) {
      final now = DateTime.now();
      final scheduledDateTime =
          DateTime(now.year, now.month, now.day, picked.hour, picked.minute);
      final notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      // Schedule the notification
      await _scheduleNotification(notificationId, scheduledDateTime);

      // Store reminder in Supabase
      try {
        final response = await supabase.from('location_reminders').insert({
          'user_id': supabase.auth.currentUser!.id,
          'notification_id': notificationId,
          'reminder_time':
              '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}:00',
          'created_at': DateTime.now().toIso8601String(),
          'is_active': true,
        }).select();

        // Refresh the profile
        setState(() {
          _profileFuture = _fetchUserProfile();
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Reminder set successfully!')),
          );
        }
      } catch (e) {
        print("Error saving reminder: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving reminder: ${e.toString()}')),
          );
        }
      }
    }
  }

  Future<void> _scheduleNotification(
      int notificationId, DateTime scheduledDateTime) async {
    tz.TZDateTime scheduledTime =
        tz.TZDateTime.from(scheduledDateTime, tz.local);

    await flutterLocalNotificationsPlugin.zonedSchedule(
      notificationId,
      'Turn on Live Location',
      'Reminder: Please turn on your live location for tracking!',
      scheduledTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'location_reminders_channel',
          'Location Reminders',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> _deleteReminder(int reminderId) async {
    try {
      // Get the notification ID to cancel it in the system
      final reminderData = await supabase
          .from('location_reminders')
          .select('notification_id')
          .eq('id', reminderId)
          .single();

      // Cancel the notification
      await flutterLocalNotificationsPlugin
          .cancel(reminderData['notification_id']);

      // Update is_active instead of deleting
      await supabase
          .from('location_reminders')
          .update({'is_active': false}).eq('id', reminderId);

      // Refresh profile
      setState(() {
        _profileFuture = _fetchUserProfile();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reminder deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting reminder: ${e.toString()}')),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_isEditing) {
          setState(() => _isEditing = false);
          return false;
        }
        return true;
      },
      child: Scaffold(
        key: _scaffoldKey,
        appBar: CustomAppBar(title: "My Profile", scaffoldKey: _scaffoldKey),
        drawer: CustomDrawer(),
        body: FutureBuilder<Map<String, dynamic>>(
          future: _profileFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return _buildErrorState(snapshot.error.toString());
            }

            if (!snapshot.hasData) {
              return _buildErrorState('No profile data found');
            }

            final profile = snapshot.data!;
            _nameController.text = profile['name']?.toString() ?? '';
            _emailController.text = profile['email']?.toString() ?? '';

            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildProfileHeader(profile),
                  const SizedBox(height: 24),
                  Expanded(
                    child: _isEditing
                        ? _buildEditForm()
                        : _buildProfileView(profile),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            error,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => setState(() => _loadProfile()),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(Map<String, dynamic> profile) {
    return Column(
      children: [
        CircleAvatar(
          radius: 60,
          backgroundColor: Colors.amber.withOpacity(0.2),
          child: Text(
            (profile['name']?.toString().substring(0, 1) ?? '?').toUpperCase(),
            style: const TextStyle(fontSize: 48),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          profile['organization']?['org_name']?.toString() ?? 'No Organization',
          style: const TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileView(Map<String, dynamic> profile) {
    return Column(
      children: [
        _buildProfileItem(
            'Name', profile['name']?.toString() ?? 'Not provided'),
        _buildProfileItem(
            'Email', profile['email']?.toString() ?? 'Not provided'),
        _buildProfileItem(
          'Member Since',
          profile['created_at'] != null
              ? DateFormat('MMM d, yyyy').format(
                  DateTime.parse(profile['created_at'].toString()),
                )
              : 'Unknown',
        ),

        // Reminders section
        const SizedBox(height: 20),
        const Text(
          'Location Reminders',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        _buildRemindersSection(profile),

        const Spacer(),
        ElevatedButton(
          onPressed: _selectTimeAndScheduleNotification,
          child: const Text('Set Live Location Reminder'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
            backgroundColor: Colors.blueAccent,
          ),
        ),
        const SizedBox(height: 10),
        ElevatedButton(
          onPressed: () => setState(() => _isEditing = true),
          child: const Text('Edit Profile'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
            backgroundColor: Colors.amber,
          ),
        ),
      ],
    );
  }

  Widget _buildRemindersSection(Map<String, dynamic> profile) {
    final reminders = profile['reminders'] as List<dynamic>? ?? [];

    if (reminders.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Text('No reminders set'),
      );
    }

    return Container(
      height: 150,
      child: ListView.builder(
        itemCount: reminders.length,
        itemBuilder: (context, index) {
          final reminder = reminders[index];
          return Card(
            elevation: 2,
            margin: const EdgeInsets.symmetric(vertical: 5),
            child: ListTile(
              leading: const Icon(Icons.alarm, color: Colors.blueAccent),
              title: Text('Daily reminder at ${reminder['reminder_time']}'),
              subtitle: Text('Turn on location tracking'),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _deleteReminder(reminder['id']),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEditForm() {
    return Form(
      key: _formKey,
      child: ListView(
        children: [
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
            ),
            validator: (value) =>
                value?.isEmpty ?? true ? 'Name is required' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emailController,
            enabled: false,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _isEditing = false),
                  child: const Text('Cancel'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 50),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _updateProfile,
                  child: const Text('Save Changes'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 50),
                    backgroundColor: Colors.green,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Divider(),
        ],
      ),
    );
  }
}
