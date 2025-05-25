import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:square_dms_trial/sidebar/side_bar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:square_dms_trial/models/sewing_production_model.dart';

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

  bool isLoading = false;
  Map<String, dynamic> summary = {};
  final numberFormatter = NumberFormat('#,##0');

  final List<String> departments = [
    'Cutting',
    'Printing',
    'Embroidery',
    'Sewing',
  ];

  // Shipment Data Analysis Section ----------------->
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

  // Loading shipment State
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

  // Shipment data Calculation
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

  // Shipment Date Range Selection
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

  // XXXXXXX----------------------------------XXXXXXX

  // Overtime Data Analysis Section -------------------->
  final List<Map<String, dynamic>> overtimeData = [
    {'x': 0, 'dept': 'Cutting', 'y': 120, 'color': Colors.blue},
    {'x': 1, 'dept': 'Printing', 'y': 80, 'color': Colors.green},
    {'x': 2, 'dept': 'Embroidery', 'y': 150, 'color': Colors.orange},
    {'x': 3, 'dept': 'Sewing', 'y': 300, 'color': Colors.redAccent},
  ];

  // Over time date selection section
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

  // XXXXXXX----------------------------------XXXXXXX

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
      await loadProductionSummary();
    }
  }

  // Sewing Production Data analysis ------------------->
  List<Map<String, dynamic>> productionStatusDatabase = [];

  // Load production summary from SQLITE database
  Future<void> loadProductionSummary() async {
    if (dashboardDateRange == null) return;
    setState(() => isLoading = true);

    // Fetch summary from the database for the selected date range
    final result = await SewingDatabaseService.getProductionSummary(
      dashboardDateRange!,
    );

    setState(() {
      summary = result; // <-- this will populate your _buildCard calls
      isLoading = false;
    });
  }

  // Download data from supabase
  Future<void> downloadData() async {
    setState(() => isLoading = true);
    // await SewingDatabaseService.syncFromSupabaseForRange();
    await loadProductionSummary();
    await loadProductionTrend();
  }

  // Date picker for production data
  Future<void> pickDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: dashboardDateRange,
    );
    if (range != null) {
      setState(() => dashboardDateRange = range);
      await loadProductionSummary();
      await loadProductionTrend();
    }
  }

  // Building card to show production data
  Widget _buildCard(String title, dynamic value, Color color, IconData icon) {
    final formattedValue =
        value is num ? numberFormatter.format(value) : value.toString();

    return Container(
      width: 160,
      margin: EdgeInsets.only(right: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 32),
          SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 6),
          Text(
            formattedValue,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  List<FlSpot> _productionTrendSpots = [];
  List<String> _trendLabels = [];

  Future<void> loadProductionTrend() async {
    final trendData = await SewingDatabaseService.getProductionTrend(days: 15);
    setState(() {
      _productionTrendSpots = [];
      _trendLabels = [];
      for (int i = 0; i < trendData.length; i++) {
        final item = trendData[i];
        final prod = (item['totalProduction'] as num?)?.toDouble() ?? 0;
        _productionTrendSpots.add(FlSpot(i.toDouble(), prod));
        _trendLabels.add(item['day'] as String);
      }
    });
  }

  // Main inti function [[[[[[Very Important]]]]]] ---------->>>
  @override
  void initState() {
    super.initState();

    final now = DateTime.now();
    shipmentDateRange = DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: now,
    );

    dashboardDateRange = DateTimeRange(
      start: DateTime(DateTime.now().year, DateTime.now().month, 1),
      end: DateTime.now(),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // await SewingDatabaseService.syncFromSupabaseForRange();
      await loadProductionSummary();
      await loadProductionTrend();
      await loadShipmentStats(); // also make this async if needed
    });
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
          onRefresh: loadProductionSummary,
          child: SingleChildScrollView(
            physics: BouncingScrollPhysics(),
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "SEWING PRODUCTION",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(width: 10),
                      IconButton(
                        onPressed: _selectDashboardDateRange,
                        icon: Icon(
                          Icons.calendar_today,
                          color: Colors.blueAccent,
                          size: 28,
                        ),
                      ),
                      SizedBox(width: 12),
                      IconButton(
                        onPressed: () async {
                          if (dashboardDateRange == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Please select a date range first.',
                                ),
                              ),
                            );
                            return;
                          }
                          setState(() => isLoading = true);

                          await SewingDatabaseService.syncFromSupabaseForRange(
                            dashboardDateRange!,
                          );
                          await loadProductionSummary();

                          setState(() => isLoading = false);

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Sync completed for selected range.',
                              ),
                            ),
                          );
                        },
                        icon: Icon(
                          Icons.download,
                          color: Colors.blueAccent,
                          size: 28,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 18),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildCard(
                        "Production",
                        summary['Production'],
                        Colors.blue,
                        Icons.factory,
                      ),
                      _buildCard(
                        "Target",
                        summary['Target'],
                        Colors.green,
                        Icons.flag,
                      ),
                      _buildCard(
                        "Achievement %",
                        summary['Achievement %'],
                        Colors.orange,
                        Icons.percent,
                      ),
                      // _buildCard(
                      //   "Manpower",
                      //   summary['Manpower'],
                      //   Colors.purple,
                      //   Icons.group,
                      // ),
                      _buildCard(
                        "Efficiency %",
                        summary['Efficiency %'],
                        Colors.teal,
                        Icons.speed,
                      ),
                      _buildCard(
                        "Avg. SMV",
                        summary['Avg. SMV'] == null
                            ? '-'
                            : (summary['Avg. SMV'] is num
                                ? summary['Avg. SMV'].toStringAsFixed(2)
                                : summary['Avg. SMV'].toString()),
                        Colors.cyan,
                        Icons.timer,
                      ),
                    ],
                  ),
                ),

                // ---------------------------------->
                // sectionTitle('Production Status'),
                // horizontalCards(productionStatusDatabase),
                sectionTitle('PRODUCTION TREND'),
                lineChartWidget(),

                // ---------------------------------->
                sectionTitleWithIcon(
                  'SHIPMENT STATUS',
                  _selectShipmentDateRange,
                ),
                horizontalCards(shipmentStatusData),
                sectionTitle('Top 5 Buyer Shipment'),
                buyerBarChartWidget(),

                // sectionTitleWithIcon(
                //   'Overtime Analysis',
                //   _selectOvertimeDateRange,
                // ),
                // overtimeBarChartWidget(),
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
      itemBuilder: (context, index) {
        final value = data[index]['value'];
        final formattedValue =
            value is num
                ? numberFormatter.format(value)
                : value.toString(); // fallback for strings

        return Container(
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
                  formattedValue,
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
  );

  Widget lineChartWidget() => Container(
    height: 280,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      // boxShadow: [
      //   BoxShadow(
      //     color: Colors.blueAccent.withAlpha(30),
      //     blurRadius: 10,
      //     spreadRadius: 3,
      //   ),
      // ],
    ),
    child:
        _productionTrendSpots.isEmpty
            ? Center(child: Text("No trend data"))
            : LineChart(
              LineChartData(
                lineBarsData: [
                  LineChartBarData(
                    spots: _productionTrendSpots,
                    isCurved: true,
                    barWidth: 4,
                    color: Colors.blueAccent,
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          Colors.blueAccent.withOpacity(0.2),
                          Colors.blueAccent.withOpacity(0.01),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    dotData: FlDotData(show: true),
                  ),
                ],
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval:
                          9, // Show every 5th date for clarity (adjust as needed)
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= _trendLabels.length)
                          return SizedBox();
                        // Optionally only show every nth label for clarity:
                        if (idx % 5 != 0 && idx != _trendLabels.length - 1)
                          return SizedBox();
                        return SideTitleWidget(
                          meta: meta,
                          // axisSide: meta.axisSide,
                          child: Text(
                            _trendLabels[idx],
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(show: false),
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    // tooltipBgColor: Colors.blueAccent.withOpacity(0.8),
                    tooltipRoundedRadius: 10,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((touchedSpot) {
                        final index = touchedSpot.spotIndex;
                        final label =
                            (index < _trendLabels.length)
                                ? _trendLabels[index]
                                : '';
                        final value = touchedSpot.y.toInt();
                        return LineTooltipItem(
                          '$label\n$value',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        );
                      }).toList();
                    },
                  ),
                  handleBuiltInTouches: true,
                ),
                minY: 0,
              ),
            ),
  );

  Widget buyerBarChartWidget() => Container(
    height: 350,
    padding: EdgeInsets.fromLTRB(16, 16, 16, 26),
    decoration: BoxDecoration(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      // boxShadow: [
      //   BoxShadow(
      //     color: Colors.grey.withOpacity(0.2),
      //     blurRadius: 8,
      //     spreadRadius: 2,
      //   ),
      // ],
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
