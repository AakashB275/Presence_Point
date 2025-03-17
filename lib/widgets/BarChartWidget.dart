import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class BarChartWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Weekly')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: 10,
            barGroups: [
              BarChartGroupData(x: 1, barRods: [
                BarChartRodData(toY: 8, color: Colors.cyanAccent, width: 16),
              ]),
              BarChartGroupData(x: 2, barRods: [
                BarChartRodData(toY: 6, color: Colors.cyanAccent, width: 16),
              ]),
              BarChartGroupData(x: 3, barRods: [
                BarChartRodData(toY: 5, color: Colors.cyanAccent, width: 16),
              ]),
              BarChartGroupData(x: 4, barRods: [
                BarChartRodData(toY: 5, color: Colors.cyanAccent, width: 16),
              ]),
              BarChartGroupData(x: 5, barRods: [
                BarChartRodData(toY: 5, color: Colors.cyanAccent, width: 16),
              ]),
              BarChartGroupData(x: 6, barRods: [
                BarChartRodData(toY: 5, color: Colors.cyanAccent, width: 16),
              ]),
              BarChartGroupData(x: 7, barRods: [
                BarChartRodData(toY: 5, color: Colors.cyanAccent, width: 16),
              ]),
            ],
            titlesData: FlTitlesData(
              rightTitles:
                  AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (double value, TitleMeta meta) {
                    switch (value.toInt()) {
                      case 1:
                        return Text('Mon');
                      case 2:
                        return Text('Tues');
                      case 3:
                        return Text('Wed');
                      case 4:
                        return Text('Thu');
                      case 5:
                        return Text('Fri');
                      case 6:
                        return Text('Sat');
                      case 7:
                        return Text('Sun');

                      default:
                        return Text('');
                    }
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
