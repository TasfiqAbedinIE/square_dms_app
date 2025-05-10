import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:square_dms_trial/sidebar/side_bar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DashboardScreen extends StatefulWidget {
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String selectedDepartment = 'Sewing';
  DateTimeRange? dashboardDateRange;
  DateTimeRange? shipmentDateRange;
  DateTimeRange? overtimeDateRange;

  int totalShippedQty = 0;
  int totalExcessQty = 0;
  int totalShortQty = 0;
  List<MapEntry<String, int>> topBuyers = [];

  final numberFormatter = NumberFormat('#,##0');

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

  List<Map<String, dynamic>> get shipmentStatusData => [
    {
      'title': 'Total Shipment',
      'value': totalShippedQty,
      'icon': Icons.local_shipping,
      'color': Colors.blue,
    },
    {
      'title': 'Excess Shipment',
      'value': totalExcessQty,
      'icon': Icons.add_circle,
      'color': Colors.green,
    },
    {
      'title': 'Short Shipment',
      'value': totalShortQty,
      'icon': Icons.remove_circle,
      'color': Colors.redAccent,
    },
  ];

  List<Map<String, dynamic>> get buyerShipmentData => List.generate(
    topBuyers.length,
    (index) => {
      'x': index,
      'buyer': topBuyers[index].key,
      'y': topBuyers[index].value,
      'color': Colors.primaries[index % Colors.primaries.length],
    },
  );

  final List<Map<String, dynamic>> overtimeData = [
    {'x': 0, 'dept': 'Cutting', 'y': 120, 'color': Colors.blue},
    {'x': 1, 'dept': 'Printing', 'y': 80, 'color': Colors.green},
    {'x': 2, 'dept': 'Embroidery', 'y': 150, 'color': Colors.orange},
    {'x': 3, 'dept': 'Sewing', 'y': 300, 'color': Colors.redAccent},
  ];

  // Shipment data Calculation ------------------------------>>>>>>>>>>>>>

  Future<Map<String, dynamic>> calculateShipmentStats(
    DateTimeRange range,
  ) async {
    // final dateFormat = DateFormat('yyyy-M-d');

    // final startDate = dateFormat.format(range.start);
    // final endDate = dateFormat.format(range.end);
    final startDate =
        range.start.toIso8601String().split('T')[0]; // '2025-05-01'
    final endDate = range.end.toIso8601String().split('T')[0]; // '2025-05-05'

    final List<Map<String, dynamic>> data = await Supabase.instance.client
        .from('shipment_data')
        .select()
        .gte('Date', startDate)
        .lte('Date', endDate);

    int totalShipped = 0;
    int totalExcess = 0;
    int totalShort = 0;
    Map<String, int> buyerShipment = {};

    for (final record in data) {
      final shippedQty = (record['ShippedQty'] ?? 0) as num;
      final excessQty = (record['Excess'] ?? 0) as num;
      final shortQty = (record['Short'] ?? 0) as num;

      totalShipped += shippedQty.toInt();
      totalExcess += excessQty.toInt();
      totalShort += shortQty.toInt();

      final buyerName = record['BuyerName'] ?? 'Unknown';
      buyerShipment[buyerName] =
          (buyerShipment[buyerName] ?? 0) + shippedQty.toInt();
    }

    print(startDate);
    print(endDate);

    final top5Buyers =
        buyerShipment.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    return {
      'totalShipped': totalShipped,
      'totalExcess': totalExcess,
      'totalShort': totalShort,
      'top5Buyers': top5Buyers.take(5).toList(),
    };
  }

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

  // End of shipment data calculation -------------------------------->>>>>>>>>>

  // Loading shipment State ------------>>>>>>>>>>>
  Future<void> loadShipmentStats() async {
    final range =
        shipmentDateRange ??
        DateTimeRange(
          start: DateTime(DateTime.now().year, DateTime.now().month, 1),
          end: DateTime.now(),
        );

    final result = await calculateShipmentStats(range);

    setState(() {
      totalShippedQty = result['totalShipped'];
      totalExcessQty = result['totalExcess'];
      totalShortQty = result['totalShort'];
      topBuyers = result['top5Buyers']; // List<MapEntry<String, int>>
    });
  }

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();
    shipmentDateRange = DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: now,
    );

    loadShipmentStats();
  }

  Future<void> _selectShipmentDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: shipmentDateRange,
    );
    if (picked != null) {
      setState(() {
        shipmentDateRange = picked;
      });
      await loadShipmentStats(); // reload stats on date change
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
                    //     Container(
                    //       padding: EdgeInsets.symmetric(
                    //         horizontal: 16,
                    //         vertical: 8,
                    //       ),
                    //       decoration: BoxDecoration(
                    //         color: Colors.white,
                    //         borderRadius: BorderRadius.circular(12),
                    //         boxShadow: [
                    //           BoxShadow(
                    //             color: Colors.blueAccent.withAlpha(30),
                    //             blurRadius: 10,
                    //             spreadRadius: 3,
                    //           ),
                    //         ],
                    //       ),
                    //       child: DropdownButtonHideUnderline(
                    //         child: DropdownButton<String>(
                    //           value: selectedDepartment,
                    //           icon: Icon(Icons.arrow_drop_down),
                    //           onChanged: (String? newValue) {
                    //             setState(() {
                    //               selectedDepartment = newValue!;
                    //             });
                    //           },
                    //           items:
                    //               departments
                    //                   .map(
                    //                     (String value) => DropdownMenuItem<String>(
                    //                       value: value,
                    //                       child: Text(
                    //                         value,
                    //                         style: TextStyle(
                    //                           fontSize: 16,
                    //                           fontWeight: FontWeight.bold,
                    //                         ),
                    //                       ),
                    //                     ),
                    //                   )
                    //                   .toList(),
                    //         ),
                    //       ),
                    //     ),
                    //     IconButton(
                    //       onPressed: _selectDashboardDateRange,
                    //       icon: Icon(
                    //         Icons.calendar_today,
                    //         color: Colors.blueAccent,
                    //         size: 28,
                    //       ),
                    //     ),
                  ],
                ),

                // sectionTitle('Production Status'),
                // horizontalCards(productionStatusData),

                // sectionTitle('Production Trend'),
                // lineChartWidget(),
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
                    numberFormatter.format(data[index]['value']),
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
    height: 350,
    padding: EdgeInsets.fromLTRB(16, 16, 16, 26),
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
            topBuyers.asMap().entries.map((entry) {
              final index = entry.key;
              final buyer = entry.value.key;
              final value = entry.value.value;

              return BarChartGroupData(
                x: index,
                barRods: [
                  BarChartRodData(
                    toY: value.toDouble(),
                    color: const Color.fromARGB(
                      255,
                      25,
                      109,
                      255,
                    ), // ✅ One consistent color
                    width: 30,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ],
              );
            }).toList(),

        titlesData: FlTitlesData(
          show: true,
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false), // ❌ Hide vertical axis
          ),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (double value, TitleMeta meta) {
                final index = value.toInt();
                if (index < 0 || index >= topBuyers.length) return SizedBox();
                return SideTitleWidget(
                  meta: meta,
                  child: Transform.rotate(
                    angle: -0.6,
                    child: Text(
                      topBuyers[index].key,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
                // return Padding(
                //   padding: const EdgeInsets.only(top: 8.0),
                //   child: Text(
                //     topBuyers[index].key,
                //     style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                //   ),
                // );
              },
            ),
          ),
        ),

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
