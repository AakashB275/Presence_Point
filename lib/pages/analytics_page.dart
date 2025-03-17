import 'package:flutter/material.dart';
import 'package:pie_chart/pie_chart.dart';
import 'location_service.dart';
import '../Widgets/BarChartWidget.dart';
import '../Widgets/CustomAppBar.dart';
import '../Widgets/CustomDrawer.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPage();
}

class _AnalyticsPage extends State<AnalyticsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      LocationService.checkAndRequestLocation(context);
    });
  }

  final GlobalKey<ScaffoldState> MyKey = GlobalKey<ScaffoldState>();
  Map<String, double> dataMap = {"absent": 30, "present": 70};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        key: MyKey,
        appBar: CustomAppBar(title: "Presence Point", scaffoldKey: MyKey),
        drawer: CustomDrawer(),
        body: SingleChildScrollView(
          child: Column(
            children: [
              SizedBox(height: 50),
              SizedBox(
                height: 300,
                child: BarChartWidget(),
              ),
              SizedBox(height: 50),
              PieChart(
                dataMap: dataMap,
                animationDuration: Duration(milliseconds: 800),
                chartLegendSpacing: 32,
                chartRadius: MediaQuery.of(context).size.width / 2,
                initialAngleInDegree: 0,
                chartType: ChartType.ring,
                ringStrokeWidth: 32,
                legendOptions: LegendOptions(
                  showLegendsInRow: false,
                  legendPosition: LegendPosition.right,
                  showLegends: true,
                  legendTextStyle: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                chartValuesOptions: ChartValuesOptions(
                  showChartValueBackground: true,
                  showChartValues: true,
                  showChartValuesInPercentage: false,
                  showChartValuesOutside: false,
                  decimalPlaces: 1,
                ),
              ),
              SizedBox(
                height: 30,
              ),
              Center(
                child: Text(
                  "Attendance Report",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(
                height: 30,
              ),
              ElevatedButton(
                  onPressed: () {}, child: Text("Check Detailed Report")),
              SizedBox(
                height: 20,
              ),
            ],
          ),
        ));
  }
}
