import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
// import 'package:intl/intl.dart';
import 'package:square_dms_trial/sidebar/side_bar.dart';

class DashboardScreen extends StatefulWidget {
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String selectedDepartment = 'Sewing';
  DateTimeRange? dashboardDateRange;
  DateTimeRange? shipmentDateRange;
  DateTimeRange? overtimeDateRange;

  final List<String> departments = [
    'Cutting',
    'Printing',
    'Embroidery',
    'Sewing',
  ];

  final List<Map<String, dynamic>> productionStatusData = [
    {'title': 'Production', 'icon': Icons.factory, 'color': Colors.blueAccent},
    {'title': 'Target', 'icon': Icons.flag, 'color': Colors.greenAccent},
    {
      'title': 'Achievement %',
      'icon': Icons.percent,
      'color': Colors.deepOrangeAccent,
    },
    {
      'title': 'Defects',
      'icon': Icons.report_problem,
      'color': Colors.redAccent,
    },
    {'title': 'Manpower', 'icon': Icons.group, 'color': Colors.purpleAccent},
    {'title': 'Efficiency', 'icon': Icons.speed, 'color': Colors.tealAccent},
  ];

  final List<Map<String, dynamic>> shipmentStatusData = [
    {
      'title': 'Total Shipment',
      'icon': Icons.local_shipping,
      'color': Colors.blue,
    },
    {
      'title': 'Excess Shipment',
      'icon': Icons.add_circle,
      'color': Colors.green,
    },
    {
      'title': 'Short Shipment',
      'icon': Icons.remove_circle,
      'color': Colors.redAccent,
    },
  ];

  final List<Map<String, dynamic>> buyerShipmentData = [
    {'x': 0, 'buyer': 'Buyer A', 'y': 2500, 'color': Colors.blue},
    {'x': 1, 'buyer': 'Buyer B', 'y': 2000, 'color': Colors.green},
    {'x': 2, 'buyer': 'Buyer C', 'y': 1800, 'color': Colors.orange},
    {'x': 3, 'buyer': 'Buyer D', 'y': 1500, 'color': Colors.purple},
    {'x': 4, 'buyer': 'Buyer E', 'y': 1300, 'color': Colors.redAccent},
  ];

  final List<Map<String, dynamic>> overtimeData = [
    {'x': 0, 'dept': 'Cutting', 'y': 120, 'color': Colors.blue},
    {'x': 1, 'dept': 'Printing', 'y': 80, 'color': Colors.green},
    {'x': 2, 'dept': 'Embroidery', 'y': 150, 'color': Colors.orange},
    {'x': 3, 'dept': 'Sewing', 'y': 300, 'color': Colors.redAccent},
  ];

  Future<void> _selectDashboardDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange:
          dashboardDateRange ??
          DateTimeRange(
            start: DateTime.now().subtract(Duration(days: 7)),
            end: DateTime.now(),
          ),
    );
    if (picked != null) {
      setState(() {
        dashboardDateRange = picked;
      });
    }
  }

  Future<void> _selectShipmentDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange:
          shipmentDateRange ??
          DateTimeRange(
            start: DateTime.now().subtract(Duration(days: 7)),
            end: DateTime.now(),
          ),
    );
    if (picked != null) {
      setState(() {
        shipmentDateRange = picked;
      });
    }
  }

  Future<void> _selectOvertimeDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange:
          overtimeDateRange ??
          DateTimeRange(
            start: DateTime.now().subtract(Duration(days: 7)),
            end: DateTime.now(),
          ),
    );
    if (picked != null) {
      setState(() {
        overtimeDateRange = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'DASHBOARD',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      drawer: AppSideBar(),
      backgroundColor: Colors.grey.shade100,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {},
          child: SingleChildScrollView(
            physics: BouncingScrollPhysics(),
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blueAccent.withAlpha(30),
                            blurRadius: 10,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedDepartment,
                          icon: Icon(Icons.arrow_drop_down),
                          onChanged: (String? newValue) {
                            setState(() {
                              selectedDepartment = newValue!;
                            });
                          },
                          items:
                              departments
                                  .map(
                                    (String value) => DropdownMenuItem<String>(
                                      value: value,
                                      child: Text(
                                        value,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _selectDashboardDateRange,
                      icon: Icon(
                        Icons.calendar_today,
                        color: Colors.blueAccent,
                        size: 28,
                      ),
                    ),
                  ],
                ),

                sectionTitle('Production Status'),
                horizontalCards(productionStatusData),

                sectionTitle('Production Trend'),
                lineChartWidget(),

                sectionTitleWithIcon(
                  'Shipment Status',
                  _selectShipmentDateRange,
                ),
                horizontalCards(shipmentStatusData),
                sectionTitle('Top 5 Buyer Shipment'),
                buyerBarChartWidget(),

                sectionTitleWithIcon(
                  'Overtime Analysis',
                  _selectOvertimeDateRange,
                ),
                overtimeBarChartWidget(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget sectionTitle(String title) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 20.0),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    ),
  );

  Widget sectionTitleWithIcon(String title, Function() onTap) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 20.0),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        IconButton(
          onPressed: onTap,
          icon: Icon(Icons.calendar_today, color: Colors.blueAccent, size: 28),
        ),
      ],
    ),
  );

  Widget horizontalCards(List<Map<String, dynamic>> data) => Container(
    height: 150,
    child: ListView.builder(
      scrollDirection: Axis.horizontal,
      physics: BouncingScrollPhysics(),
      itemCount: data.length,
      itemBuilder:
          (context, index) => Container(
            width: 140,
            margin: EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: data[index]['color'],
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(data[index]['icon'], color: Colors.white, size: 32),
                  SizedBox(height: 10),
                  Text(
                    data[index]['title'],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
    ),
  );

  Widget lineChartWidget() => Container(
    height: 300,
    padding: EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.grey.withOpacity(0.2),
          blurRadius: 8,
          spreadRadius: 2,
        ),
      ],
    ),
    child: LineChart(
      LineChartData(
        lineBarsData: [
          LineChartBarData(
            spots: [
              FlSpot(0, 1000),
              FlSpot(1, 1200),
              FlSpot(2, 900),
              FlSpot(3, 1500),
              FlSpot(4, 1400),
              FlSpot(5, 1600),
              FlSpot(6, 1300),
            ],
            isCurved: true,
            gradient: LinearGradient(
              colors: [Colors.blueAccent, Colors.lightBlueAccent],
            ),
            barWidth: 5,
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  Colors.lightBlueAccent.withOpacity(0.3),
                  Colors.blueAccent.withOpacity(0.1),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            dotData: FlDotData(show: true),
          ),
        ],
        titlesData: FlTitlesData(show: true),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(show: true),
      ),
    ),
  );

  Widget buyerBarChartWidget() => Container(
    height: 300,
    padding: EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.grey.withOpacity(0.2),
          blurRadius: 8,
          spreadRadius: 2,
        ),
      ],
    ),
    child: BarChart(
      BarChartData(
        barGroups:
            buyerShipmentData
                .map(
                  (data) => BarChartGroupData(
                    x: data['x'],
                    barRods: [
                      BarChartRodData(
                        toY: data['y'].toDouble(),
                        color: data['color'],
                        width: 18,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ],
                  ),
                )
                .toList(),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(show: true),
      ),
    ),
  );

  Widget overtimeBarChartWidget() => Container(
    height: 300,
    padding: EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.grey.withOpacity(0.2),
          blurRadius: 8,
          spreadRadius: 2,
        ),
      ],
    ),
    child: BarChart(
      BarChartData(
        barGroups:
            overtimeData
                .map(
                  (data) => BarChartGroupData(
                    x: data['x'],
                    barRods: [
                      BarChartRodData(
                        toY: data['y'].toDouble(),
                        color: data['color'],
                        width: 18,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ],
                  ),
                )
                .toList(),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(show: true),
      ),
    ),
  );
}
