import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

class LostTimeReportPage extends StatefulWidget {
  const LostTimeReportPage({super.key});

  @override
  State<LostTimeReportPage> createState() => _LostTimeReportPageState();
}

class _LostTimeReportPageState extends State<LostTimeReportPage> {
  final SupabaseClient client = Supabase.instance.client;
  DateTimeRange dateRange = DateTimeRange(
    start: DateTime.now(),
    end: DateTime.now(),
  );

  List<Map<String, dynamic>> reportData = [];
  bool isLoading = true;
  int totalLostMinutes = 0;
  double totalLostPcs = 0.0;
  Map<String, int> reasonWiseMinutes = {};

  String? selectedBlock; // null = all blocks
  final Map<String, List<int>> blockLines = {
    '1-6': [1, 6],
    '7-15': [7, 15],
    '16-21': [16, 21],
    '22-30': [22, 30],
    '31-36': [31, 36],
    '37-45': [37, 45],
    '46-49': [46, 49],
    '50-55': [50, 55],
    '56-62': [56, 62],
    '63-69': [63, 69],
    '70-76': [70, 76],
    '77-81': [77, 81],
    '82-86': [82, 86],
    '87-91': [87, 91],
    '92-96': [92, 96],
    '97-105': [97, 105],
    '106-114': [106, 114],
    '115-124': [115, 124],
  };

  @override
  void initState() {
    super.initState();
    fetchReport();
  }

  Future<void> fetchReport() async {
    setState(() {
      isLoading = true;
    });

    try {
      final from = DateFormat('yyyy-MM-dd').format(dateRange.start);
      final to = DateFormat('yyyy-MM-dd').format(dateRange.end);

      var query = client
          .from('non_productive_time')
          .select()
          .gte('date', from)
          .lte('date', to);

      if (selectedBlock != null && blockLines.containsKey(selectedBlock)) {
        final range = blockLines[selectedBlock]!;
        query = query.gte('lineNo', range[0]).lte('lineNo', range[1]);
      }

      final response = await query;

      totalLostMinutes = 0;
      totalLostPcs = 0.0;
      reasonWiseMinutes.clear();

      for (final row in response) {
        final int duration = (row['durationMinutes'] ?? 0).toInt();
        final double lostPcs = (row['totalLostPcs'] ?? 0).toDouble();

        totalLostMinutes += duration;
        totalLostPcs += lostPcs;

        final reason = row['reason'] ?? 'Unknown';
        reasonWiseMinutes[reason] = (reasonWiseMinutes[reason] ?? 0) + duration;
      }

      setState(() {
        reportData = response;
        isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to fetch report: $e")));
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Lost Time Report"),
        backgroundColor: const Color.fromARGB(255, 255, 179, 193),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 🔹 Date Range Picker Row
            Row(
              children: [
                Expanded(
                  child: Text(
                    "${DateFormat('yyyy-MM-dd').format(dateRange.start)} to ${DateFormat('yyyy-MM-dd').format(dateRange.end)}",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    final picked = await showDateRangePicker(
                      context: context,
                      initialDateRange: dateRange,
                      firstDate: DateTime(2023),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() => dateRange = picked);
                      await fetchReport();
                    }
                  },
                  icon: const Icon(Icons.calendar_today),
                  label: const Text("Change"),
                ),
              ],
            ),

            const SizedBox(height: 16),
            DropdownButton<String>(
              value: selectedBlock,
              hint: const Text("Select Block"),
              isExpanded: true,
              onChanged: (value) {
                setState(() => selectedBlock = value);
                fetchReport(); // update chart and cards
              },
              items: [
                const DropdownMenuItem(value: null, child: Text("All Blocks")),
                ...blockLines.keys.map((block) {
                  return DropdownMenuItem(
                    value: block,
                    child: Text("Block $block"),
                  );
                }).toList(),
              ],
            ),

            const SizedBox(height: 16),

            // 🔹 Summary Cards
            Row(
              children: [
                Expanded(
                  child: Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Text("Lost Minutes"),
                          const SizedBox(height: 8),
                          Text(
                            "$totalLostMinutes",
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Text("Lost Pieces"),
                          const SizedBox(height: 8),
                          Text(
                            totalLostPcs.toStringAsFixed(2),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text("Factor Wise Lost Minutes", style: TextStyle(fontSize: 18)),
            const SizedBox(height: 20),
            // 🔹 Bar Chart (Fixed Height)
            reasonWiseMinutes.isEmpty
                ? const Center(child: Text("No data to show in chart"))
                : SizedBox(
                  height: 300, // Adjust height as needed
                  child: BarChart(
                    BarChartData(
                      gridData: FlGridData(show: false),
                      barTouchData: BarTouchData(enabled: true),
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
                            reservedSize: 42,
                            interval: 1,
                            getTitlesWidget: (value, meta) {
                              final items = reasonWiseMinutes.entries.toList();
                              if (value.toInt() >= items.length)
                                return const SizedBox();
                              return Transform.rotate(
                                angle: -0.5,
                                child: Text(
                                  items[value.toInt()].key,
                                  style: const TextStyle(fontSize: 10),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: List.generate(reasonWiseMinutes.length, (
                        index,
                      ) {
                        final entry = reasonWiseMinutes.entries.elementAt(
                          index,
                        );
                        return BarChartGroupData(
                          x: index,
                          barRods: [
                            BarChartRodData(
                              toY: entry.value.toDouble(), // ✅ Natural scaling
                              width: 30,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
                ),
            SizedBox(height: 30),
            Text("Lost Minutes Details", style: TextStyle(fontSize: 18)),
            SizedBox(height: 15),
            // List View of the lost time analysis --------------->
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: reportData.length,
              itemBuilder: (context, index) {
                final entry = reportData[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: ListTile(
                    title: Text("Line ${entry['lineNo']} - ${entry['reason']}"),
                    subtitle: Text(
                      "${entry['date']} | ${entry['startTime']} - ${entry['endTime']}\n"
                      "Duration: ${entry['durationMinutes']} min | "
                      "NP: ${entry['totalNP']} | Lost Pcs: ${entry['totalLostPcs'].toStringAsFixed(2)}",
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
