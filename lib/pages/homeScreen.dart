import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:square_dms_trial/sidebar/side_bar.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:square_dms_trial/service/pushnotificationsend.dart';

class DashboardScreen extends StatefulWidget {
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String selectedDepartment = 'Sewing';
  DateTime selectedDate = DateTime.now();

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

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  Future<void> _refreshDashboard() async {
    await Future.delayed(Duration(seconds: 1));

    // Just refresh UI, no push notification sending here.
    setState(() {
      // Refresh any data if needed
    });
  }

  DateTime shipmentSelectedDate = DateTime.now();

  Future<void> _selectShipmentDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: shipmentSelectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        shipmentSelectedDate = picked;
      });
    }
  }

  DateTime overtimeSelectedDate = DateTime.now();

  Future<void> _selectOvertimeDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: overtimeSelectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        overtimeSelectedDate = picked;
      });
    }
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text(
          'DASHBOARD',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
        centerTitle: true,
        backgroundColor: const Color.fromARGB(255, 94, 43, 255),
        foregroundColor: const Color.fromARGB(255, 252, 247, 255),
      ),
      drawer: AppSideBar(), // 👉 your custom drawer function
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshDashboard,
          child: SingleChildScrollView(
            physics: BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Top Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Department Dropdown
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
                                    .map<DropdownMenuItem<String>>(
                                      (String value) =>
                                          DropdownMenuItem<String>(
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

                      // Date Picker Icon Button
                      IconButton(
                        onPressed: _selectDate,
                        icon: Icon(
                          Icons.calendar_today,
                          color: Colors.blueAccent,
                          size: 28,
                        ),
                        tooltip: 'Select Date',
                      ),
                    ],
                  ),
                  // Section Title
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20.0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Production Status',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),

                  // Horizontal Scroll Cards
                  Container(
                    height: 150,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      physics: BouncingScrollPhysics(),
                      itemCount: productionStatusData.length,
                      itemBuilder: (context, index) {
                        return Container(
                          width: 140,
                          margin: EdgeInsets.only(right: 16),
                          decoration: BoxDecoration(
                            color: productionStatusData[index]['color'],
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.2),
                                blurRadius: 8,
                                spreadRadius: 2,
                                offset: Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  productionStatusData[index]['icon'],
                                  color: Colors.white,
                                  size: 32,
                                ),
                                SizedBox(height: 10),
                                Text(
                                  productionStatusData[index]['title'],
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
                        );
                      },
                    ),
                  ),
                  // Section Title: Production Trend
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20.0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Production Trend',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),

                  // Line Chart Container
                  Container(
                    height: 300,
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blueAccent.withAlpha(30),
                          blurRadius: 10,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                    child: LineChart(
                      LineChartData(
                        minX: 0,
                        maxX: 6,
                        minY: 0,
                        maxY: 2000,
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: true,
                          getDrawingHorizontalLine:
                              (value) => FlLine(
                                color: Colors.grey.withAlpha(30),
                                strokeWidth: 1,
                              ),
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: bottomTitleWidgets,
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: true),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
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
                              colors: [
                                Colors.blueAccent,
                                Colors.lightBlueAccent,
                              ],
                            ),
                            barWidth: 5,
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                colors: [
                                  Colors.lightBlueAccent.withAlpha(30),
                                  Colors.blueAccent.withAlpha(30),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                            dotData: FlDotData(show: true),
                          ),
                        ],
                        lineTouchData: LineTouchData(
                          enabled: true,
                          touchTooltipData: LineTouchTooltipData(
                            getTooltipItems:
                                (spots) =>
                                    spots
                                        .map(
                                          (spot) => LineTooltipItem(
                                            '${spot.y.toInt()} pcs',
                                            TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        )
                                        .toList(),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Shipment Status Header Row
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Shipment Status',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        IconButton(
                          onPressed: _selectShipmentDate, // we'll define this
                          icon: Icon(
                            Icons.calendar_today,
                            color: Colors.blueAccent,
                            size: 28,
                          ),
                          tooltip: 'Select Shipment Date',
                        ),
                      ],
                    ),
                  ),
                  // Horizontal Scroll Cards for Shipment Status
                  Container(
                    height: 150,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      physics: BouncingScrollPhysics(),
                      itemCount: shipmentStatusData.length,
                      itemBuilder: (context, index) {
                        return Container(
                          width: 160,
                          margin: EdgeInsets.only(right: 16),
                          decoration: BoxDecoration(
                            color: shipmentStatusData[index]['color'],
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withAlpha(30),
                                blurRadius: 8,
                                spreadRadius: 2,
                                offset: Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  shipmentStatusData[index]['icon'],
                                  color: Colors.white,
                                  size: 32,
                                ),
                                SizedBox(height: 10),
                                Text(
                                  shipmentStatusData[index]['title'],
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
                        );
                      },
                    ),
                  ),
                  // Section Title: Top 5 Buyer Shipment
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20.0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Top 5 Buyer Shipment',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),

                  // Bar Chart
                  Container(
                    height: 300,
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withAlpha(30),
                          blurRadius: 8,
                          spreadRadius: 2,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: 3000,
                        barTouchData: BarTouchData(
                          enabled: true,
                          touchTooltipData: BarTouchTooltipData(
                            // tooltipBgColor: Colors.blueAccent.withOpacity(0.8),
                            tooltipRoundedRadius: 8,
                          ),
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: bottomTitleWidgetsForBuyer,
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: true),
                          ),
                          topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (value) {
                            return FlLine(
                              color: Colors.grey.withAlpha(30),
                              strokeWidth: 1,
                            );
                          },
                        ),
                        borderData: FlBorderData(show: false),
                        barGroups:
                            buyerShipmentData.map((data) {
                              return BarChartGroupData(
                                x: data['x'],
                                barRods: [
                                  BarChartRodData(
                                    toY: data['y'].toDouble(),
                                    color: data['color'],
                                    width: 18,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ],
                              );
                            }).toList(),
                      ),
                    ),
                  ),
                  // Overtime Analysis Header Row
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Overtime Analysis',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        IconButton(
                          onPressed: _selectOvertimeDate, // we'll define this
                          icon: Icon(
                            Icons.calendar_today,
                            color: Colors.blueAccent,
                            size: 28,
                          ),
                          tooltip: 'Select Overtime Date',
                        ),
                      ],
                    ),
                  ),
                  // Overtime Bar Chart
                  Container(
                    height: 300,
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withAlpha(30),
                          blurRadius: 8,
                          spreadRadius: 2,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: 500,
                        barTouchData: BarTouchData(
                          enabled: true,
                          touchTooltipData: BarTouchTooltipData(
                            // tooltipBgColor: Colors.blueAccent.withOpacity(0.8),
                            tooltipRoundedRadius: 8,
                          ),
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: bottomTitleWidgetsForOvertime,
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: true),
                          ),
                        ),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (value) {
                            return FlLine(
                              color: Colors.grey.withAlpha(30),
                              strokeWidth: 1,
                            );
                          },
                        ),
                        borderData: FlBorderData(show: false),
                        barGroups:
                            overtimeData.map((data) {
                              return BarChartGroupData(
                                x: data['x'],
                                barRods: [
                                  BarChartRodData(
                                    toY: data['y'].toDouble(),
                                    color: data['color'],
                                    width: 18,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ],
                              );
                            }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Widget bottomTitleWidgets(double value, TitleMeta meta) {
  const style = TextStyle(fontWeight: FontWeight.bold, fontSize: 12);
  switch (value.toInt()) {
    case 0:
      return Text('Mon', style: style);
    case 1:
      return Text('Tue', style: style);
    case 2:
      return Text('Wed', style: style);
    case 3:
      return Text('Thu', style: style);
    case 4:
      return Text('Fri', style: style);
    case 5:
      return Text('Sat', style: style);
    case 6:
      return Text('Sun', style: style);
    default:
      return Text('', style: style);
  }
}

Widget bottomTitleWidgetsForBuyer(double value, TitleMeta meta) {
  final style = TextStyle(fontWeight: FontWeight.bold, fontSize: 12);

  String text;
  switch (value.toInt()) {
    case 0:
      text = 'A';
      break;
    case 1:
      text = 'B';
      break;
    case 2:
      text = 'C';
      break;
    case 3:
      text = 'D';
      break;
    case 4:
      text = 'E';
      break;
    default:
      text = '';
      break;
  }

  return Text(text, style: style);
}

Widget bottomTitleWidgetsForOvertime(double value, TitleMeta meta) {
  final style = TextStyle(fontWeight: FontWeight.bold, fontSize: 12);

  String text;
  switch (value.toInt()) {
    case 0:
      text = 'Cut';
      break;
    case 1:
      text = 'Print';
      break;
    case 2:
      text = 'Emb';
      break;
    case 3:
      text = 'Sew';
      break;
    default:
      text = '';
      break;
  }

  return Text(text, style: style);
}
