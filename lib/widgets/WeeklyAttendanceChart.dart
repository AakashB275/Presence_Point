import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class WeeklyAttendanceChart extends StatelessWidget {
  final Map<int, double> weeklyHours;
  final bool showWeekends;

  const WeeklyAttendanceChart({
    super.key,
    required this.weeklyHours,
    this.showWeekends = false,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate chart parameters
    final maxHours = _calculateMaxHours();

    return AspectRatio(
      aspectRatio: 1.6,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxHours,
          minY: 0,
          groupsSpace: 12,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              tooltipPadding: const EdgeInsets.all(8),
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final day = _getWeekdayName(group.x.toInt());
                return BarTooltipItem(
                  '$day: ${rod.toY} hours',
                  const TextStyle(color: Colors.white),
                );
              },
            ),
          ),
          barGroups: _buildBarGroups(),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: _calculateYInterval(maxHours),
                getTitlesWidget: _leftTitleWidgets,
                reservedSize: 40,
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: _bottomTitleWidgets,
                reservedSize: 24,
              ),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: _calculateYInterval(maxHours),
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.grey.shade200,
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: Colors.grey.shade300),
          ),
        ),
      ),
    );
  }

  double _calculateMaxHours() {
    final maxValue =
        weeklyHours.values.fold(0.0, (max, e) => e > max ? e : max);
    // Ensure minimum scale of 8 hours if there's any data
    return maxValue < 8 && maxValue > 0 ? 8 : maxValue.ceilToDouble() + 2;
  }

  double _calculateYInterval(double maxHours) {
    if (maxHours <= 8) return 2;
    if (maxHours <= 16) return 4;
    return (maxHours / 4).ceilToDouble();
  }

  List<BarChartGroupData> _buildBarGroups() {
    final bars = <BarChartGroupData>[];
    final daysToShow = showWeekends ? 7 : 5;

    for (int i = 1; i <= daysToShow; i++) {
      bars.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: weeklyHours[i] ?? 0,
              color: _getBarColor(weeklyHours[i] ?? 0),
              width: 18,
              borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: _calculateMaxHours(),
                color: Colors.cyanAccent,
              ),
            ),
          ],
        ),
      );
    }
    return bars;
  }

  Widget _leftTitleWidgets(double value, TitleMeta meta) {
    if (value == 0) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Text(
        '${value.toInt()}h',
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade600,
        ),
      ),
    );
  }

  Widget _bottomTitleWidgets(double value, TitleMeta meta) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        _getWeekdayName(value.toInt()),
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade600,
          fontWeight: value.toInt() == DateTime.now().weekday
              ? FontWeight.bold
              : FontWeight.normal,
        ),
      ),
    );
  }

  String _getWeekdayName(int day) {
    switch (day) {
      case 1:
        return 'Mon';
      case 2:
        return 'Tue';
      case 3:
        return 'Wed';
      case 4:
        return 'Thu';
      case 5:
        return 'Fri';
      case 6:
        return 'Sat';
      case 7:
        return 'Sun';
      default:
        return '';
    }
  }

  Color _getBarColor(double hours) {
    if (hours == 0) return Colors.grey.shade300;

    final percentage = hours / 8; // 8 hours = 100%
    return HSLColor.fromAHSL(1, 120 * percentage, 0.7, 0.6).toColor();
  }
}
