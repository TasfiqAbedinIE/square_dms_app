import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HourlyDataEntryScreen extends StatefulWidget {
  const HourlyDataEntryScreen({super.key});

  @override
  State<HourlyDataEntryScreen> createState() => _HourlyDataEntryScreenState();
}

class _HourlyDataEntryScreenState extends State<HourlyDataEntryScreen> {
  String? selectedBlock;
  bool isLoading = true; // ✨ New loading state

  Map<int, TextEditingController> productionControllers = {};
  Map<int, TextEditingController> targetControllers = {};
  Map<int, TextEditingController> remarksControllers = {};
  List<int> linesToShow = [];
  bool isMasterUser = false; // 🔥 New flag

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

  String userId = '';

  @override
  void initState() {
    super.initState();
    _fetchUserWorkingArea();
  }

  Future<void> _fetchUserWorkingArea() async {
    try {
      final client = Supabase.instance.client;
      // final userId = client.auth.currentUser?.id;

      final prefs = await SharedPreferences.getInstance();
      final storedUserId = prefs.getString('userID') ?? '';

      if (storedUserId == null) {
        setState(() => isLoading = false);
        return;
      }

      final response =
          await client
              .from('USERS')
              .select('working_area')
              .eq('org_id', storedUserId)
              .maybeSingle();

      if (response != null && response['working_area'] != null) {
        final area = response['working_area'];

        setState(() {
          if (area == 'MASTER') {
            isMasterUser = true; // 🔥 user is MASTER
            selectedBlock = '1-6'; // set any default initially
            _initControllers(selectedBlock!);
          } else {
            isMasterUser = false;
            selectedBlock = area;
            _initControllers(selectedBlock!);
          }
        });
      }
    } catch (e) {
      // handle error
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _initControllers(String block) {
    final lines = blockLines[block] ?? [];
    linesToShow = lines;
    for (var line in lines) {
      productionControllers[line] ??= TextEditingController();
      targetControllers[line] ??= TextEditingController();
      remarksControllers[line] ??= TextEditingController();
    }
  }

  @override
  void dispose() {
    for (var controller in productionControllers.values) {
      controller.dispose();
    }
    for (var controller in targetControllers.values) {
      controller.dispose();
    }
    for (var controller in remarksControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void submitData() async {
    final client = Supabase.instance.client;
    final formattedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final now = DateTime.now();
    final oneHourBefore = now.subtract(Duration(hours: 0));
    final formattedTime = DateFormat('HH:00:00').format(oneHourBefore);

    List<int> skippedLines = [];

    for (var line in linesToShow) {
      final productionText = productionControllers[line]?.text ?? '';
      final targetText = targetControllers[line]?.text ?? '';
      final remarksText = remarksControllers[line]?.text ?? '';

      if (productionText.isEmpty || targetText.isEmpty) continue;

      final int production = int.tryParse(productionText) ?? 0;
      final int target = int.tryParse(targetText) ?? 0;

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
        skippedLines.add(line);
        continue;
      }

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

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final now = DateTime.now();
    final oneHourBefore = now.subtract(Duration(hours: 0));
    final formattedTime = DateFormat('HH:00:00').format(oneHourBefore);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Date: $today ($formattedTime)",
              style: const TextStyle(fontSize: 16),
            ),
            // Text($storedUserId),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedBlock,
                    items:
                        blockLines.keys.map((block) {
                          return DropdownMenuItem(
                            value: block,
                            child: Text("Block $block"),
                          );
                        }).toList(),
                    onChanged:
                        isMasterUser
                            ? (value) {
                              setState(() {
                                selectedBlock = value!;
                                _initControllers(selectedBlock!);
                              });
                            }
                            : null, // ❌ If not MASTER, disable dropdown
                    decoration: const InputDecoration(
                      labelText: 'Block',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
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
                              const SizedBox(width: 10),
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
                          const SizedBox(height: 10),
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
