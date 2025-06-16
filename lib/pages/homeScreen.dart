import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';
import 'package:intl/intl.dart';
import 'package:square_dms_trial/sidebar/side_bar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DashboardScreen extends StatefulWidget {
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DateTimeRange? dashboardDateRange;
  bool isLoading = false;
  Map<String, dynamic> summary = {};
  List<FlSpot> _productionTrendSpots = [];
  List<String> _trendLabels = [];

  final numberFormatter = NumberFormat('#,##0');

  // ------------------ Motivational Quote Banner ---------------------
  final Map<String, String> motivationalQuotes = {
    'success.png':
        'Success is not the key to happiness. Happiness is the key to success.',
    'focus.png': 'Focus on being productive instead of busy.',
    'fire.png': 'Keep going, You are on fire.',
    'believe.png': 'Believe you can and you are halfway there.',
    'stronger.png': 'You are stronger than you think.',
    'proud.png': "Don't stop until you are proud.",
    'begining.png': 'The best time for new beginnings is now.',
    'clock.png': "Don't watch the clock; do what it does. Keep going.",
    'running.png': "Don't stop when you are tired, STOP WHEN YOU ARE DONE.",
    'treem.png': "THE FUTURE DEPENDS ON WHAT YOU DO TODAY.",
    'stairs.png':
        "Success is sum of small efforts, repeated day in and day out.",
  };

  late final MapEntry<String, String> selectedQuote = getRandomQuote(
    motivationalQuotes,
  );

  MapEntry<String, String> getRandomQuote(Map<String, String> quotes) {
    final keys = quotes.keys.toList();
    final randomKey = keys[Random().nextInt(keys.length)];
    return MapEntry(randomKey, quotes[randomKey]!);
  }

  Widget motivationalBanner(MapEntry<String, String> quoteEntry) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 20),
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            Colors.blueAccent,
            Colors.cyanAccent,
            const Color.fromARGB(255, 194, 255, 125),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blueAccent.withOpacity(0.3),
            blurRadius: 12,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.asset(
              // 'assets/images/stairs.png',
              'assets/images/${quoteEntry.key}',
              width: 70,
              height: 70,
              fit: BoxFit.cover,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              quoteEntry.value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black,
                shadows: [Shadow(color: Colors.black12, blurRadius: 3)],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------- PRODUCTION DATA FETCH HELPERS --------------------

  Future<DateTime?> fetchLatestProductionDate() async {
    final List<dynamic> result = await Supabase.instance.client
        .from('sewing_production_data')
        .select('date')
        .order('date', ascending: false)
        .limit(1);

    if (result.isNotEmpty && result[0]['date'] != null) {
      return DateTime.parse(result[0]['date']);
    }
    return null;
  }

  Future<Map<String, dynamic>> fetchProductionSummary(
    DateTimeRange range,
  ) async {
    final String start = range.start.toIso8601String().split('T')[0];
    final String end = range.end.toIso8601String().split('T')[0];

    final List<Map<String, dynamic>> data = await Supabase.instance.client
        .from('sewing_production_data')
        .select()
        .gte('date', start)
        .lte('date', end);

    int totalProduction = 0;
    double totalTarget = 0;
    double availableMinutes = 0;
    double earnedMinutes = 0;
    double totalSMV = 0;
    int totalManpower = 0;
    int dayCount = data.length;

    for (final row in data) {
      final without = row['without'] as int? ?? 0;
      final production = row['production'] as int? ?? 0;
      final rejection = row['rejection'] as int? ?? 0;
      final due = row['due'] as int? ?? 0;
      final target10 = (row['target10'] as num?)?.toDouble() ?? 0;
      final hourMinusTNC = (row['hourMinusTNC'] as num?)?.toDouble() ?? 0;
      final hourTNC = (row['hourTNC'] as num?)?.toDouble() ?? 0;
      final hour = (row['hour'] as num?)?.toDouble() ?? 0;
      final manpower = row['manpower'] as int? ?? 0;
      final smv = (row['SMV'] as num?)?.toDouble() ?? 0;

      final thisProduction = without + production + rejection - due;
      final thisTarget = (target10 / 10.0) * hourMinusTNC;
      final thisAvailableMin = (hourTNC / 10.0) * hour * manpower * 60;

      totalProduction += thisProduction;
      totalTarget += thisTarget;
      availableMinutes += thisAvailableMin;
      earnedMinutes += thisProduction * smv;
      totalSMV += smv;
      totalManpower += manpower;
    }

    final achievement =
        totalTarget > 0 ? (totalProduction / totalTarget * 100) : 0;
    final efficiency =
        availableMinutes > 0 ? (earnedMinutes / availableMinutes * 100) : 0;
    final avgSMV = totalProduction > 0 ? (earnedMinutes / totalProduction) : 0;
    final avgManpower = dayCount > 0 ? (totalManpower / dayCount).round() : 0;

    return {
      'Production': totalProduction,
      'Target': totalTarget.toInt(),
      'Achievement %': achievement.toInt(),
      'Manpower': avgManpower,
      'Avg. SMV': avgSMV,
      'Efficiency %': efficiency.toInt(),
    };
  }

  Future<List<Map<String, dynamic>>> fetchProductionTrend({
    DateTimeRange? range,
    int? days,
  }) async {
    // If a range is given, use it; otherwise, use the last `days` days.
    DateTime endDate, startDate;
    if (range != null) {
      startDate = range.start;
      endDate = range.end;
    } else if (days != null) {
      endDate = DateTime.now();
      startDate = endDate.subtract(Duration(days: days));
    } else {
      // Default to last 30 days
      endDate = DateTime.now();
      startDate = endDate.subtract(Duration(days: 30));
    }

    final startStr = startDate.toIso8601String().split('T')[0];
    final endStr = endDate.toIso8601String().split('T')[0];

    final List<Map<String, dynamic>> data = await Supabase.instance.client
        .from('sewing_production_data')
        .select('date, production')
        .gte('date', startStr)
        .lte('date', endStr);

    // Group by date
    final Map<String, int> grouped = {};
    for (final row in data) {
      final day = (row['date'] as String).split('T')[0];
      final prod = (row['production'] ?? 0) as int;
      grouped[day] = (grouped[day] ?? 0) + prod;
    }

    // Sort days
    final daysList = grouped.keys.toList()..sort();
    return [
      for (final day in daysList)
        {'day': day, 'totalProduction': grouped[day] ?? 0},
    ];
  }

  // ----------- LOAD/UPDATE FUNCTIONS -------------

  Future<void> loadInitialDashboard() async {
    setState(() => isLoading = true);
    final latestDate = await fetchLatestProductionDate();
    if (latestDate == null) {
      setState(() => isLoading = false);
      return;
    }
    dashboardDateRange = DateTimeRange(start: latestDate, end: latestDate);
    await loadProductionSummary();
    await loadProductionTrend();
    setState(() => isLoading = false);
  }

  Future<void> loadProductionSummary() async {
    if (dashboardDateRange == null) return;
    setState(() => isLoading = true);
    summary = await fetchProductionSummary(dashboardDateRange!);
    setState(() => isLoading = false);
  }

  Future<void> loadProductionTrend() async {
    // If dashboardDateRange is null or single-day, default to last 30 days
    if (dashboardDateRange == null ||
        dashboardDateRange!.start == dashboardDateRange!.end) {
      final trendData = await fetchProductionTrend(days: 30);
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
    } else {
      final trendData = await fetchProductionTrend(range: dashboardDateRange!);
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
  }

  Future<void> _selectDashboardDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: dashboardDateRange,
    );
    if (picked != null) {
      setState(() {
        dashboardDateRange = picked;
      });
      await loadProductionSummary();
      await loadProductionTrend();
    }
  }

  // Shipment Data Analysis Section ----------------->
  int totalShippedQty = 0;
  int totalExcessQty = 0;
  int totalShortQty = 0;
  List<MapEntry<String, int>> topBuyers = [];
  DateTimeRange? shipmentDateRange;

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
  Future<DateTime?> getLatestShipmentDate() async {
    final response =
        await Supabase.instance.client
            .from('shipment_data')
            .select('Date')
            .order('Date', ascending: false)
            .limit(1)
            .maybeSingle();

    if (response != null && response['Date'] != null) {
      // Parse Supabase date string, e.g. "2025-05-28 00:00:00+00"
      return DateTime.parse(response['Date']);
    }
    return null;
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
          icon: Icon(
            Icons.calendar_today,
            color: const Color.fromARGB(255, 53, 144, 243),
            size: 28,
          ),
        ),
      ],
    ),
  );

  Widget horizontalCards(List<Map<String, dynamic>> data) => Container(
    height: 130,
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

  Widget buyerBarChartWidget() => Container(
    height: 320,
    padding: EdgeInsets.fromLTRB(16, 16, 16, 26),
    decoration: BoxDecoration(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
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
                      53,
                      144,
                      243,
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

  // XXXXXXX----------------------------------XXXXXXX

  // --------------------- Overtime Data Analysis ------------------------ //
  Future<String?> fetchLatestOvertimeDate() async {
    final rows = await Supabase.instance.client
        .from('overtime_data')
        .select('date')
        .order('date', ascending: false)
        .limit(1);
    if (rows.isNotEmpty) {
      return rows.first['date'].toString().split('T')[0];
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> fetchSectionWiseOvertime({
    required String startDate,
    required String endDate,
  }) async {
    final data = await Supabase.instance.client
        .from('overtime_data')
        .select('section, org_id, OT')
        .gte('date', startDate)
        .lte('date', endDate);

    // Map<section, Map<org_id, total OT for this org_id>>
    final Map<String, Map<dynamic, int>> sectionOrgOt = {};

    for (final row in data) {
      final section = row['section'] ?? 'Unknown';
      final orgId = row['org_id'];
      final ot = (row['OT'] ?? 0) as int;

      if (orgId == null) continue;

      sectionOrgOt.putIfAbsent(section, () => {});
      sectionOrgOt[section]![orgId] = (sectionOrgOt[section]![orgId] ?? 0) + ot;
    }

    // Now calculate section-wise average OT
    return sectionOrgOt.entries.map((entry) {
      final section = entry.key;
      final orgMap = entry.value;
      final totalOt = orgMap.values.fold<int>(0, (a, b) => a + b);
      final uniqueOrgCount = orgMap.keys.length;
      final avgOt = uniqueOrgCount > 0 ? totalOt / uniqueOrgCount : 0.0;
      return {'section': section, 'avgOt': avgOt};
    }).toList();
  }

  DateTimeRange? overtimeDateRange;
  List<Map<String, dynamic>> sectionOtData = [];
  bool isLoadingOt = false;

  Future<void> loadInitialOvertimeData() async {
    setState(() => isLoadingOt = true);
    final latestDate = await fetchLatestOvertimeDate();
    if (latestDate != null) {
      overtimeDateRange = DateTimeRange(
        start: DateTime.parse(latestDate),
        end: DateTime.parse(latestDate),
      );
      sectionOtData = await fetchSectionWiseOvertime(
        startDate: latestDate,
        endDate: latestDate,
      );
    }
    setState(() => isLoadingOt = false);
  }

  Future<void> pickOvertimeDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: overtimeDateRange,
    );
    if (picked != null) {
      setState(() {
        overtimeDateRange = picked;
        isLoadingOt = true;
      });
      sectionOtData = await fetchSectionWiseOvertime(
        startDate: picked.start.toIso8601String().split('T')[0],
        endDate: picked.end.toIso8601String().split('T')[0],
      );
      setState(() => isLoadingOt = false);
    }
  }

  Widget sectionOvertimeBarChart() {
    if (isLoadingOt) return Center(child: CircularProgressIndicator());
    if (sectionOtData.isEmpty) return Text('No data available');
    return Container(
      height: 320,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Container(
          padding: EdgeInsets.fromLTRB(0, 16, 0, 30),
          width: max(
            sectionOtData.length * 60.0,
            MediaQuery.of(context).size.width,
          ),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: BarChart(
            BarChartData(
              barGroups: List.generate(sectionOtData.length, (idx) {
                final item = sectionOtData[idx];
                return BarChartGroupData(
                  x: idx,
                  barRods: [
                    BarChartRodData(
                      toY: (item['avgOt'] as num?)?.toDouble() ?? 0.0,
                      color: const Color.fromARGB(255, 202, 60, 255),
                      width: 30,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ],
                );
              }),
              borderData: FlBorderData(show: false),
              gridData: FlGridData(show: true),
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
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= sectionOtData.length)
                        return SizedBox();
                      return SideTitleWidget(
                        meta: meta,
                        child: Transform.rotate(
                          angle: -0.6,
                          child: Text(
                            sectionOtData[idx]['section'],
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              barTouchData: BarTouchData(
                // enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (group) => Colors.transparent,
                  // getTooltipColor: (touchedSpot) => _getColor(interval, value),
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  tooltipPadding: const EdgeInsets.all(0),
                  tooltipMargin: 0,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    // final section = sectionOtData[group.x.toInt()]['section'];
                    final avgOt = (sectionOtData[group.x.toInt()]['avgOt']
                            as num)
                        .toStringAsFixed(2);
                    return BarTooltipItem(
                      rod.toY.toStringAsFixed(2), // value label
                      // avgOt,
                      TextStyle(color: Colors.black),
                    );
                  },
                ),
              ),
              // minY: 0,
            ),
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      DateTime? latestDate = await getLatestShipmentDate();
      if (latestDate != null) {
        setState(() {
          shipmentDateRange = DateTimeRange(start: latestDate, end: latestDate);
        });

        await loadInitialDashboard();
        await loadShipmentStats();
        await loadProductionTrend();
        await loadInitialOvertimeData();
      }
    });
  }

  // ----------- WIDGETS ----------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.blueAccent,
      ),
      drawer: AppSideBar(),
      backgroundColor: Colors.white,
      body: SafeArea(
        child:
            isLoading
                ? Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                  onRefresh: loadProductionSummary,
                  child: SingleChildScrollView(
                    physics: BouncingScrollPhysics(),
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        motivationalBanner(selectedQuote),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                "SEWING PRODUCTION",
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
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

                        if (dashboardDateRange != null &&
                            !dashboardDateRange!.start.isAtSameMomentAs(
                              dashboardDateRange!.end,
                            )) ...[
                          sectionTitle('PRODUCTION TREND'),
                          lineChartWidget(),
                        ],

                        sectionTitleWithIcon(
                          'SHIPMENT STATUS',
                          _selectShipmentDateRange,
                        ),
                        horizontalCards(shipmentStatusData),
                        sectionTitle('Top 5 Buyer Shipment'),
                        buyerBarChartWidget(),
                        SizedBox(height: 30),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "SECTION WISE OVERTIME (Hrs)",
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.calendar_today,
                                color: const Color.fromARGB(255, 202, 60, 255),
                                size: 28,
                              ),
                              onPressed: pickOvertimeDateRange,
                            ),
                          ],
                        ),
                        sectionOvertimeBarChart(),
                        SizedBox(height: 30),
                        // ... Other sections like shipment, etc
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

  Widget _buildCard(String title, dynamic value, Color color, IconData icon) {
    final formattedValue =
        value is num ? numberFormatter.format(value) : value?.toString() ?? '-';

    return Container(
      width: 140,
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

  Widget lineChartWidget() => Container(
    height: 280,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
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
                      interval: 5,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= _trendLabels.length)
                          return SizedBox();
                        if (idx % 5 != 0 && idx != _trendLabels.length - 1)
                          return SizedBox();
                        return SideTitleWidget(
                          meta: meta,
                          child: Text(
                            _trendLabels[idx].substring(5), // MM-DD
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
}
