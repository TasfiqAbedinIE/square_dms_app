import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HourlyDataEntryScreen extends StatefulWidget {
  const HourlyDataEntryScreen({super.key});

  @override
  State<HourlyDataEntryScreen> createState() => _DataEntryScreenState();
}

class _DataEntryScreenState extends State<HourlyDataEntryScreen> {
  String? selectedBlock;
  String? selectedHour;
  final List<String> hours = List.generate(9, (index) => '${8 + index}:00');
  Map<int, TextEditingController> productionControllers = {};
  Map<int, TextEditingController> targetControllers = {};
  Map<int, TextEditingController> remarksControllers = {};
  List<int> linesToShow = [];

  final Map<int, TextEditingController> lineControllers = {};
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
  };

  String convertToTime(String hourLabel) {
    final timeMap = {
      '8:00': '08:00:00',
      '9:00': '09:00:00',
      '10:00': '10:00:00',
      '11:00': '11:00:00',
      '12:00': '12:00:00',
      '13:00': '13:00:00',
      '14:00': '14:00:00',
      '15:00': '15:00:00',
      '16:00': '16:00:00',
    };

    return timeMap[hourLabel] ?? '00:00:00';
  }

  @override
  void initState() {
    super.initState();
    _initControllers('1-6'); // default block
    selectedBlock = '1-6';
  }

  void _fetchLatestTargetForLine(int line) async {
    final client = Supabase.instance.client;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    final response =
        await client
            .from('Hourly_Production')
            .select('target')
            .eq('line', line)
            .eq('block', selectedBlock!)
            .eq('date', today)
            .order('hour', ascending: false)
            .limit(1)
            .maybeSingle();

    if (response != null && response['target'] != null) {
      setState(() {
        targetControllers[line]?.text = response['target'].toString();
      });
    }
  }

  void _initControllers(String block) {
    final lines = blockLines[block] ?? [];
    setState(() {
      linesToShow = lines;
    });
    for (var line in lines) {
      productionControllers[line] ??= TextEditingController();
      targetControllers[line] ??= TextEditingController();
      _fetchLatestTargetForLine(line);
      remarksControllers[line] ??= TextEditingController();
    }
  }

  @override
  void dispose() {
    for (var controller in lineControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  // ✅ Add the function here
  // void submitData() async {
  //   final client = Supabase.instance.client;
  //   final formattedDate = DateTime.now().toIso8601String().substring(0, 10);
  //   // final formattedTime = convertToTime(selectedHour!);
  //   final now = DateTime.now();
  //   final formattedTime = DateFormat('HH:00:00').format(now);

  //   for (var line in linesToShow) {
  //     final productionText = productionControllers[line]?.text ?? '';
  //     final targetText = targetControllers[line]?.text ?? '';
  //     final remarksText = remarksControllers[line]?.text ?? '';

  //     if (productionText.isEmpty || targetText.isEmpty) continue;

  //     final int production = int.tryParse(productionText) ?? 0;
  //     final int target = int.tryParse(targetText) ?? 0;

  //     await client.from('Hourly_Production').insert({
  //       'date': formattedDate,
  //       'hour': formattedTime,
  //       'block': selectedBlock,
  //       'line': line,
  //       'production_qty': production,
  //       'target': target,
  //       'remarks': remarksText,
  //     });
  //   }

  //   ScaffoldMessenger.of(context).showSnackBar(
  //     const SnackBar(content: Text('Data submitted successfully')),
  //   );
  // }

  void submitData() async {
    final client = Supabase.instance.client;
    final formattedDate = DateTime.now().toIso8601String().substring(0, 10);
    final now = DateTime.now();
    final oneHourLater = now.add(Duration(hours: 1));
    final formattedTime = DateFormat('HH:00:00').format(oneHourLater);

    List<int> skippedLines = [];

    for (var line in linesToShow) {
      final productionText = productionControllers[line]?.text ?? '';
      final targetText = targetControllers[line]?.text ?? '';
      final remarksText = remarksControllers[line]?.text ?? '';

      if (productionText.isEmpty || targetText.isEmpty) continue;

      final int production = int.tryParse(productionText) ?? 0;
      final int target = int.tryParse(targetText) ?? 0;

      // 🔍 Check for duplicate record
      final existing =
          await client
              .from('Hourly_Production')
              .select()
              .eq('date', formattedDate)
              .eq('hour', formattedTime)
              .eq('block', selectedBlock!)
              .eq('line', line)
              .maybeSingle();

      if (existing != null) {
        skippedLines.add(line); // ⚠️ Mark line as skipped
        continue;
      }

      // ✅ Insert if not exists
      await client.from('Hourly_Production').insert({
        'date': formattedDate,
        'hour': formattedTime,
        'block': selectedBlock,
        'line': line,
        'production_qty': production,
        'target': target,
        'remarks': remarksText,
      });
    }

    // 🎉 Show result message
    if (skippedLines.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Data already exists for line(s): ${skippedLines.join(', ')}',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data submitted successfully')),
      );
    }
  }

  // ✅ Other lifecycle methods (initState, build, etc.)

  @override
  Widget build(BuildContext context) {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final linesToShow = blockLines[selectedBlock] ?? [];
    final now = DateTime.now();
    final oneHourLater = now.add(Duration(hours: 1));
    final formattedTime = DateFormat('HH:00:00').format(oneHourLater);

    return Scaffold(
      // appBar: AppBar(title: const Text("Hourly Production")),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Date: $today ($formattedTime)",
              style: const TextStyle(fontSize: 16),
            ),
            SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
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
                        _initControllers(value!);
                      });
                    },
                    decoration: const InputDecoration(
                      labelText: 'Select Block',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: linesToShow.length,
                itemBuilder: (context, index) {
                  final line = linesToShow[index];
                  final productionController = productionControllers[line]!;
                  final targetController = targetControllers[line]!;
                  final remarksController = remarksControllers[line]!;

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Line $line',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: productionController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Production Qty',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: targetController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Target',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 10),
                          TextField(
                            controller: remarksController,
                            keyboardType: TextInputType.text,
                            decoration: const InputDecoration(
                              labelText: 'Remarks',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            Center(
              child: ElevatedButton(
                onPressed: submitData,
                child: const Text("Submit"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
