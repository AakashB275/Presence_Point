import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class AttendanceService {
  final SupabaseClient _supabase = Supabase.instance.client;
  RealtimeChannel? _attendanceChannel;

  String? get currentUserId => _supabase.auth.currentUser?.id;

  void setupRealtimeUpdates({
    required void Function() onDataChanged,
    required void Function(String) onError,
  }) {
    // 1. Unsubscribe from any existing channel
    _attendanceChannel?.unsubscribe();

    if (currentUserId == null) {
      onError('User not authenticated');
      return;
    }

    try {
      // 2. Create and configure the channel
      _attendanceChannel = _supabase
          .channel('attendance_$currentUserId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'attendance',
            filter: PostgresChangeFilter(
              column: 'user_id',
              value: currentUserId!,
              type: PostgresChangeFilterType.eq,
            ),
            callback: (payload) => onDataChanged(),
          )
          .subscribe(
        (status, [_]) {
          if (status == 'SUBSCRIBED') {
            debugPrint('Realtime connected');
          } else if (status == 'CHANNEL_ERROR') {
            onError('Realtime error occurred');
          }
        },
      );
    } catch (e) {
      onError('Setup failed: ${e.toString()}');
    }
  }

  void dispose() {
    _attendanceChannel?.unsubscribe();
    _attendanceChannel = null;
  }

  Future<Map<String, dynamic>> fetchCombinedAttendanceData() async {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final startOfMonth = DateTime(now.year, now.month, 1);

    try {
      // 1. Fetch data with date range filtering
      final response = await _supabase
          .from('attendance')
          .select()
          .eq('user_id', currentUserId!)
          .gte('check_in_time', startOfMonth.toIso8601String())
          .order('check_in_time', ascending: true);

      // 2. Initialize data structures
      final dailyHours = <int, double>{1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
      final presentDaysWeekly = <String>{}; // Using dates instead of weekdays
      final presentDaysMonthly = <String>{};

      // 3. Process each record
      for (final record in response) {
        final checkInDate = DateTime.parse(record['check_in_time']).toLocal();
        final dateKey = DateFormat('yyyy-MM-dd').format(checkInDate);
        final hours = (record['total_hours'] as num?)?.toDouble() ?? 0;

        // Monthly processing
        if (hours > 0) presentDaysMonthly.add(dateKey);

        // Weekly processing (only weekdays)
        if (checkInDate.isAfter(startOfWeek)) {
          final weekday = checkInDate.weekday;
          if (weekday <= 5) {
            // Only Monday(1) to Friday(5)
            dailyHours[weekday] = (dailyHours[weekday] ?? 0) + hours;
            if (hours > 0) presentDaysWeekly.add(dateKey);
          }
        }
      }

      // 4. Calculate business days in month
      final endOfMonth = DateTime(now.year, now.month + 1, 0);
      final businessDays = _countBusinessDays(startOfMonth, endOfMonth);

      // 5. Prepare results
      return {
        'weekly': {
          'dailyHours': dailyHours,
          'pieData': {
            'present': _calculatePercentage(presentDaysWeekly.length, 5),
            'absent': _calculatePercentage(5 - presentDaysWeekly.length, 5),
          },
        },
        'monthly': {
          'pieData': {
            'present':
                _calculatePercentage(presentDaysMonthly.length, businessDays),
            'absent': _calculatePercentage(
                businessDays - presentDaysMonthly.length, businessDays),
          },
        },
      };
    } catch (e) {
      throw Exception('Failed to fetch attendance data: ${e.toString()}');
    }
  }

// Helper function to count business days
  int _countBusinessDays(DateTime start, DateTime end) {
    int days = 0;
    while (start.isBefore(end) || start.isAtSameMomentAs(end)) {
      if (start.weekday <= 5) days++;
      start = start.add(const Duration(days: 1));
    }
    return days;
  }

// Helper function for percentage calculation
  double _calculatePercentage(int value, int total) {
    return total > 0 ? ((value / total) * 100).roundToDouble() : 0;
  }
}
