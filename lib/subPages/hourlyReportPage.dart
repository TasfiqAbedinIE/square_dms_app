import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String? selectedBlock = '1-6';
  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

  final Map<String, List<int>> blockLines = {
    '1-6': [1, 2, 3, 4, 5, 6],
    '7-15': [7, 8, 9, 10, 11, 12, 13, 14, 15],
    '16-21': [16, 17, 18, 19, 20, 21],
    '22-30': [22, 23, 24, 25, 26, 27, 28, 29, 30],
    '31-36': [31, 32, 33, 34, 35, 36],
    '37-45': [37, 38, 39, 40, 41, 42, 43, 44, 45],
    '46-49': [46, 47, 48, 49],
    '50-55': [50, 51, 52, 53, 54, 55],
    '56-62': [56, 57, 58, 59, 60, 61, 62],
    '63-69': [63, 64, 65, 66, 67, 68, 69],
    '70-76': [70, 71, 72, 73, 74, 75, 76],
    '77-81': [77, 78, 79, 80, 81],
    '82-86': [82, 83, 84, 85, 86],
    '87-91': [87, 88, 89, 90, 91],
    '92-96': [92, 93, 94, 95, 96],
    '97-105': [97, 98, 99, 100, 101, 102, 103, 104, 105],
    '106-114': [106, 107, 108, 109, 110, 111, 112, 113, 114],
    '115-124': [115, 116, 117, 118, 119, 120, 121, 122, 123, 124],
    // Add other blocks here
  };

  Map<int, List<Map<String, dynamic>>> lineData = {};
  bool isLoading = false;

  // Step 1: Fixed range of hours (you can adjust as needed)
  final expectedHours = List.generate(11, (i) => i + 8); // [8, 9, ..., 18]

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
    setState(() => isLoading = true);
    final client = Supabase.instance.client;

    try {
      final response = await client
          .from('Hourly_Production')
          .select()
          .eq('date', today)
          .eq('block', selectedBlock!);

      final Map<int, List<Map<String, dynamic>>> grouped = {};
      for (final record in response) {
        final line = record['line'];
        grouped.putIfAbsent(line, () => []).add(record);
      }

      setState(() {
        lineData = grouped;
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching data: $e');
      setState(() => isLoading = false);
    }
  }

  Widget buildLineCard(int line, List<Map<String, dynamic>> records) {
    final totalProduction = records.fold<int>(
      0,
      (sum, r) => sum + ((r['production_qty'] ?? 0) as num).toInt(),
    );
    final totalTarget = records.fold<int>(
      0,
      (sum, r) => sum + ((r['target'] ?? 0) as num).toInt(),
    );
    double achievement =
        totalTarget > 0 ? (totalProduction / totalTarget) * 100 : 0;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Line $line',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total Production: $totalProduction'),
                Text('Target: $totalTarget'),
              ],
            ),
            Text('Achievement: ${achievement.toStringAsFixed(1)}%'),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  barGroups: () {
                    final expectedHours = List.generate(
                      11,
                      (i) => i + 8,
                    ); // 8 to 18

                    // Map existing records by hour
                    final recordMap = {
                      for (var r in records)
                        int.tryParse((r['hour'] ?? '00:00').split(':')[0]) ?? 0:
                            r,
                    };

                    return expectedHours.map((hour) {
                      final record =
                          recordMap[hour] ??
                          {
                            'hour': '${hour.toString().padLeft(2, '0')}:00',
                            'production_qty': 0,
                            'target': 0,
                            'remarks': '',
                          };

                      final prod = (record['production_qty'] ?? 0) as num;
                      final target = (record['target'] ?? 0) as num;

                      return BarChartGroupData(
                        x: hour,
                        barRods: [
                          BarChartRodData(
                            toY: prod.toDouble(),
                            color:
                                recordMap.containsKey(hour)
                                    ? (prod >= target
                                        ? Colors.green
                                        : Colors.red)
                                    : Colors.grey, // gray if no data
                            borderRadius: BorderRadius.circular(4),
                            width: 14,
                          ),
                        ],
                        showingTooltipIndicators: [
                          0,
                        ], // changed it show tooltip
                      );
                    }).toList();
                  }(),

                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final hour = value.toInt().toString().padLeft(2, '0');
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '$hour:00',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        },
                        reservedSize: 40,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget:
                            (value, meta) => Text(
                              value.toInt().toString(),
                              style: const TextStyle(fontSize: 10),
                            ),
                        reservedSize: 32,
                      ),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),

                  gridData: FlGridData(show: true),
                  borderData: FlBorderData(show: false),

                  // barTouchData: BarTouchData(
                  //   touchCallback: (event, response) {
                  //     if (event is FlTapUpEvent &&
                  //         response != null &&
                  //         response.spot != null) {
                  //       final x = response.spot!.touchedBarGroup.x;
                  //       final hourKey = '${x.toString().padLeft(2, '0')}:00:00';

                  //       final record = records.firstWhere(
                  //         (r) =>
                  //             (r['hour'] ?? '').toString().startsWith(hourKey),
                  //         orElse: () => {'remarks': 'No remarks'},
                  //       );

                  //       final remarks = record['remarks'] ?? 'No remarks';

                  //       showDialog(
                  //         context: context,
                  //         builder:
                  //             (context) => AlertDialog(
                  //               title: Text('Remarks for $hourKey'),
                  //               content: Text(remarks.toString()),
                  //               actions: [
                  //                 TextButton(
                  //                   onPressed:
                  //                       () => Navigator.of(context).pop(),
                  //                   child: const Text('Close'),
                  //                 ),
                  //               ],
                  //             ),
                  //       );
                  //     }
                  //   },
                  //   touchTooltipData: BarTouchTooltipData(
                  //     tooltipPadding: EdgeInsets.zero,
                  //     tooltipMargin: 0,
                  //     getTooltipItem:
                  //         (_, __, ___, ____) => null, // disables tooltip
                  //   ),
                  // ),
                  barTouchData: BarTouchData(
                    // enabled: false, // disables touch interaction
                    touchCallback: (event, response) {
                      if (event is FlTapUpEvent &&
                          response != null &&
                          response.spot != null) {
                        final x = response.spot!.touchedBarGroup.x;
                        final hourKey = '${x.toString().padLeft(2, '0')}:00:00';

                        final record = records.firstWhere(
                          (r) =>
                              (r['hour'] ?? '').toString().startsWith(hourKey),
                          orElse: () => {'remarks': 'No remarks'},
                        );

                        final remarks = record['remarks'] ?? 'No remarks';

                        showDialog(
                          context: context,
                          builder:
                              (context) => AlertDialog(
                                title: Text('Remarks for $hourKey'),
                                content: Text(remarks.toString()),
                                actions: [
                                  TextButton(
                                    onPressed:
                                        () => Navigator.of(context).pop(),
                                    child: const Text('Close'),
                                  ),
                                ],
                              ),
                        );
                      }
                    },

                    // Section to show bar tooltip
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (group) => Colors.transparent,
                      // getTooltipColor: (touchedSpot) => _getColor(interval, value),
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                      tooltipPadding: const EdgeInsets.all(0),
                      tooltipMargin: 0,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem(
                          rod.toY.toStringAsFixed(0), // value label
                          const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                          // Optional: offset the label higher
                          textAlign: TextAlign.center,
                        );
                      },
                    ),
                    // touchTooltipThreshold: 999, // always shows tooltips
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lines = blockLines[selectedBlock] ?? [];

    return Scaffold(
      // appBar: AppBar(title: const Text("Dashboard")),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: selectedBlock,
              items:
                  blockLines.keys
                      .map(
                        (block) => DropdownMenuItem(
                          value: block,
                          child: Text("Block $block"),
                        ),
                      )
                      .toList(),
              onChanged: (value) {
                setState(() {
                  selectedBlock = value;
                });
                fetchData();
              },
              decoration: const InputDecoration(
                labelText: 'Select Block',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child:
                  isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ListView(
                        children:
                            lines.map((line) {
                              final records = lineData[line] ?? [];
                              return buildLineCard(line, records);
                            }).toList(),
                      ),
            ),
          ],
        ),
      ),
    );
  }
}
