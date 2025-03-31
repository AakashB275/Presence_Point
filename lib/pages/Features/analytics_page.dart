import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pie_chart/pie_chart.dart';
import '../../services/attendance_service.dart';
import '../../services/location_service.dart';
import '../../Widgets/CustomAppBar.dart';
import '../../Widgets/CustomDrawer.dart';
import '../../Widgets/WeeklyAttendanceChart.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPage();
}

class _AnalyticsPage extends State<AnalyticsPage> {
  final GlobalKey<ScaffoldState> myKey = GlobalKey<ScaffoldState>();
  final AttendanceService _attendanceService = AttendanceService();

  // Data state
  Map<String, double> attendanceData = {"absent": 30, "present": 70};
  Map<int, double> weeklyHours = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0};
  bool _isLoading = true;
  String _errorMessage = '';
  bool _showUpdateIndicator = false;
  Timer? _refreshDebounceTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      LocationService.checkAndRequestLocation(context);
      _loadAttendanceData();
      _setupRealtimeUpdates();
    });
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
            _errorMessage = 'Real-time connection error: $error';
          });
        }
      },
    );
  }

  void _handleRealtimeUpdate() {
    _refreshDebounceTimer?.cancel();
    _refreshDebounceTimer =
        Timer(const Duration(seconds: 1), _loadAttendanceData);

    if (mounted) {
      setState(() => _showUpdateIndicator = true);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _showUpdateIndicator = false);
      });
    }
  }

  Future<void> _loadAttendanceData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      final combinedData =
          await _attendanceService.fetchCombinedAttendanceData();

      setState(() {
        weeklyHours =
            Map<int, double>.from(combinedData['weekly']['dailyHours']);
        attendanceData = combinedData['monthly']['pieData'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load attendance data: ${e.toString()}';
        _isLoading = false;
      });
      debugPrint('Error loading attendance data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: myKey,
      appBar: CustomAppBar(title: "Presence Point", scaffoldKey: myKey),
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
                child: const Text(
                  'Updated',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
        ],
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
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: const Text(
                "Your Attendance Analytics",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20),
            // Weekly Hours Chart
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
                      const Text(
                        "Weekly Hours",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 250,
                        child: WeeklyAttendanceChart(weeklyHours: weeklyHours),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Monthly Attendance Pie Chart
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
                      const Text(
                        "Monthly Attendance",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 250,
                        child: PieChart(
                          dataMap: attendanceData,
                          animationDuration: const Duration(milliseconds: 800),
                          chartLegendSpacing: 32,
                          chartRadius: MediaQuery.of(context).size.width / 2.5,
                          colorList: [
                            Colors.green.shade400,
                            Colors.red.shade300,
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
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
