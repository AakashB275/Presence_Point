import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pie_chart/pie_chart.dart';
import 'package:intl/intl.dart';
import 'package:presence_point_2/pages/admin_home_page.dart';
import '../../services/attendance_service.dart';
import '../../services/location_service.dart';
import '../../Widgets/CustomAppBar.dart';
import '../../Widgets/CustomDrawer.dart';
import '../../Widgets/WeeklyAttendanceChart.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({
    super.key,
  });

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();
  late final AttendanceService _attendanceService;
  final LocationService _locationService = LocationService();

  // Data state
  Map<String, double> _attendanceData = {};
  Map<int, double> _dailyHours = {};
  double _totalHours = 0;
  double _averageDailyHours = 0;
  bool _isLoading = true;
  String _errorMessage = '';
  bool _showUpdateIndicator = false;
  Timer? _refreshDebounceTimer;

  // Time period selection
  TimePeriod _selectedTimePeriod = TimePeriod.weekly;
  DateTime _rangeStart = DateTime.now();
  DateTime _rangeEnd = DateTime.now();

  @override
  void initState() {
    super.initState();
    _attendanceService = AttendanceService();
    _initializePage();
  }

  Future<void> _initializePage() async {
    await LocationService.checkAndRequestLocation(context);
    _setupRealtimeUpdates();
    await _loadAttendanceData();
  }

  @override
  void dispose() {
    _attendanceService.dispose();
    _refreshDebounceTimer?.cancel();
    super.dispose();
  }

  void _setupRealtimeUpdates() {
    _attendanceService.setupRealtimeUpdates(
      onDataChanged: _handleRealtimeUpdate,
      onError: (error) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Real-time error: $error';
          });
        }
      },
    );
  }

  void _handleRealtimeUpdate() {
    _refreshDebounceTimer?.cancel();
    _refreshDebounceTimer = Timer(const Duration(seconds: 1), () {
      if (mounted) {
        _loadAttendanceData(showIndicator: true);
      }
    });
  }

  Future<void> _loadAttendanceData({bool showIndicator = false}) async {
    if (showIndicator && mounted) {
      setState(() => _showUpdateIndicator = true);
    }

    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _errorMessage = '';
        });
      }

      // Calculate date range based on selected period
      final now = DateTime.now();
      switch (_selectedTimePeriod) {
        case TimePeriod.weekly:
          _rangeStart = now.subtract(Duration(days: now.weekday - 1));
          _rangeEnd = _rangeStart.add(const Duration(days: 6));
          break;
        case TimePeriod.monthly:
          _rangeStart = DateTime(now.year, now.month, 1);
          _rangeEnd = DateTime(now.year, now.month + 1, 0);
          break;
        case TimePeriod.custom:
          // _rangeStart and _rangeEnd already set by date picker
          break;
      }

      // Fetch data
      final combinedData =
          await _attendanceService.fetchCombinedAttendanceData();
      final data = _selectedTimePeriod == TimePeriod.monthly
          ? combinedData['monthly']
          : combinedData['weekly'];

      if (mounted) {
        setState(() {
          if (_selectedTimePeriod == TimePeriod.monthly) {
            _dailyHours = _generateMonthlyDays(_rangeStart, _rangeEnd);
          } else {
            _dailyHours = Map<int, double>.from(
              (data['dailyHours'] as Map<dynamic, dynamic>).map(
                (key, value) => MapEntry(int.parse(key.toString()), value),
              ),
            );
          }

          _attendanceData = {
            'Present': data['pieData']['present'],
            'Absent': data['pieData']['absent'],
          };

          // Calculate totals and averages
          _totalHours = _dailyHours.values.fold(0, (sum, hours) => sum + hours);
          final daysWithData = _dailyHours.values.where((h) => h > 0).length;
          _averageDailyHours =
              daysWithData > 0 ? _totalHours / daysWithData : 0;

          _isLoading = false;
          if (showIndicator) {
            _showUpdateIndicator = false;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load data: ${e.toString()}';
          _isLoading = false;
          _showUpdateIndicator = false;
        });
      }
    }
  }

  Map<int, double> _generateMonthlyDays(DateTime start, DateTime end) {
    final days = <int, double>{};
    for (int i = 1; i <= end.day; i++) {
      days[i] = 0.0;
    }
    return days;
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(start: _rangeStart, end: _rangeEnd),
    );

    if (picked != null &&
        picked != DateTimeRange(start: _rangeStart, end: _rangeEnd)) {
      setState(() {
        _rangeStart = picked.start;
        _rangeEnd = picked.end;
        _selectedTimePeriod = TimePeriod.custom;
      });
      await _loadAttendanceData();
    }
  }

  void _changeTimePeriod(TimePeriod period) {
    setState(() {
      _selectedTimePeriod = period;
    });
    _loadAttendanceData();
  }

  void _navigateToAdminEmployeePage() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => AdminHomePage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        _navigateToAdminEmployeePage();
      },
      child: Scaffold(
        key: scaffoldKey,
        appBar: CustomAppBar(
          title: "Analytics Dashboard",
          scaffoldKey: scaffoldKey,
        ),
        drawer: CustomDrawer(),
        body: Stack(
          children: [
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage.isNotEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _errorMessage,
                                style: const TextStyle(color: Colors.red),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton(
                                onPressed: _loadAttendanceData,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _buildContent(),
            if (_showUpdateIndicator)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.refresh, color: Colors.white, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Updating...',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return RefreshIndicator(
      onRefresh: _loadAttendanceData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            _buildTimePeriodSelector(),
            const SizedBox(height: 16),
            _buildSummaryCards(),
            const SizedBox(height: 16),
            _buildChartsSection(),
            const SizedBox(height: 20),
            _buildDetailedDataSection(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTimePeriodSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildTimePeriodButton(
            label: 'Weekly',
            isSelected: _selectedTimePeriod == TimePeriod.weekly,
            onTap: () => _changeTimePeriod(TimePeriod.weekly),
          ),
          _buildTimePeriodButton(
            label: 'Monthly',
            isSelected: _selectedTimePeriod == TimePeriod.monthly,
            onTap: () => _changeTimePeriod(TimePeriod.monthly),
          ),
          _buildTimePeriodButton(
            label: 'Custom',
            isSelected: _selectedTimePeriod == TimePeriod.custom,
            onTap: () => _selectDateRange(context),
          ),
        ],
      ),
    );
  }

  Widget _buildTimePeriodButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: Material(
          color: isSelected ? Theme.of(context).primaryColor : Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          Row(
            children: [
              _buildSummaryCard(
                title: "Total Hours",
                value: _totalHours.toStringAsFixed(1),
                unit: "hours",
                icon: Icons.access_time,
                color: Colors.blue,
              ),
              const SizedBox(width: 10),
              _buildSummaryCard(
                title: "Daily Avg",
                value: _averageDailyHours.toStringAsFixed(1),
                unit: "hours/day",
                icon: Icons.timeline,
                color: Colors.green,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildSummaryCard(
                title: "Present Days",
                value: _attendanceData['Present']?.toStringAsFixed(0) ?? '0',
                unit: "days",
                icon: Icons.check_circle,
                color: Colors.green,
              ),
              const SizedBox(width: 10),
              _buildSummaryCard(
                title: "Absent Days",
                value: _attendanceData['Absent']?.toStringAsFixed(0) ?? '0',
                unit: "days",
                icon: Icons.cancel,
                color: Colors.red,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required String unit,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                unit,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChartsSection() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedTimePeriod == TimePeriod.monthly
                        ? "Monthly Hours Breakdown"
                        : "Weekly Hours Breakdown",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _selectedTimePeriod == TimePeriod.monthly
                        ? "Month of ${_getMonthName()}"
                        : "Week of ${_getWeekRange()}",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 250,
                    child: WeeklyAttendanceChart(
                      weeklyHours: _dailyHours,
                      showWeekends: _selectedTimePeriod == TimePeriod.weekly,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedTimePeriod == TimePeriod.monthly
                        ? "Monthly Attendance Overview"
                        : "Weekly Attendance Overview",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _selectedTimePeriod == TimePeriod.monthly
                        ? "Month of ${_getMonthName()}"
                        : "Week of ${_getWeekRange()}",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 250,
                    child: PieChart(
                      dataMap: _attendanceData,
                      animationDuration: const Duration(milliseconds: 800),
                      chartLegendSpacing: 32,
                      chartRadius: MediaQuery.of(context).size.width / 2.5,
                      colorList: [
                        Colors.green.shade400,
                        Colors.red.shade400,
                      ],
                      initialAngleInDegree: 0,
                      chartType: ChartType.ring,
                      ringStrokeWidth: 32,
                      centerText: "Attendance",
                      legendOptions: const LegendOptions(
                        showLegendsInRow: false,
                        legendPosition: LegendPosition.right,
                        showLegends: true,
                        legendTextStyle: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      chartValuesOptions: const ChartValuesOptions(
                        showChartValueBackground: true,
                        showChartValues: true,
                        showChartValuesInPercentage: true,
                        showChartValuesOutside: false,
                        decimalPlaces: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailedDataSection() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Detailed Attendance Data",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _selectedTimePeriod == TimePeriod.monthly
                    ? "Month of ${_getMonthName()}"
                    : "Week of ${_getWeekRange()}",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 300,
                child: ListView.builder(
                  itemCount: _dailyHours.length,
                  itemBuilder: (context, index) {
                    final day = _dailyHours.keys.elementAt(index);
                    final hours = _dailyHours[day] ?? 0;

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: hours > 0
                            ? Colors.green.shade100
                            : Colors.red.shade100,
                        child: Icon(
                          hours > 0 ? Icons.check : Icons.close,
                          color: hours > 0 ? Colors.green : Colors.red,
                        ),
                      ),
                      title: Text(
                        _selectedTimePeriod == TimePeriod.monthly
                            ? "Day $day"
                            : _getWeekdayName(day),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        hours > 0
                            ? "${hours.toStringAsFixed(2)} hours"
                            : "Absent",
                      ),
                      trailing: Text(
                        "${(hours > 0 ? (hours / 8 * 100) : 0).toStringAsFixed(1)}%",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: hours > 0 ? Colors.green : Colors.red,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getWeekRange() {
    return '${_rangeStart.day}/${_rangeStart.month} - ${_rangeEnd.day}/${_rangeEnd.month}';
  }

  String _getMonthName() {
    return [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ][_rangeStart.month - 1];
  }

  String _getWeekdayName(int weekday) {
    return [
      'Sunday',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday'
    ][weekday - 1];
  }
}

enum TimePeriod {
  weekly,
  monthly,
  custom,
}
