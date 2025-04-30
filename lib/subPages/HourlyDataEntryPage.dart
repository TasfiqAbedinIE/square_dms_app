import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class HourlyDataEntryScreen extends StatefulWidget {
  const HourlyDataEntryScreen({super.key});

  @override
  State<HourlyDataEntryScreen> createState() => _HourlyDataEntryScreenState();
}

class _HourlyDataEntryScreenState extends State<HourlyDataEntryScreen> {
  String? selectedBlock;
  bool isLoading = true;

  List<String> blockOptions = [];
  bool isMasterUser = false;
  Map<int, TextEditingController> productionControllers = {};
  Map<int, TextEditingController> targetControllers = {};
  Map<int, TextEditingController> remarksControllers = {};
  List<int> linesToShow = [];
  String currentDate = '';
  String currentHour = '';

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

  @override
  void initState() {
    super.initState();
    _fetchUserWorkingArea();
    _initializeDateTime();
  }

  void _initializeDateTime() {
    final now = DateTime.now();
    currentDate = DateFormat(
      'MMMM dd, yyyy',
    ).format(now); // Example: April 29, 2025
    currentHour = DateFormat('HH:00:00').format(now); // Example: 10 AM
  }

  Future<void> _fetchUserWorkingArea() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedUserId = prefs.getString('userID') ?? '';

      if (storedUserId.isEmpty) {
        setState(() => isLoading = false);
        return;
      }

      final client = Supabase.instance.client;
      final response =
          await client
              .from('USERS')
              .select('working_area')
              .eq('org_id', storedUserId)
              .maybeSingle();

      if (response == null || response['working_area'] == null) {
        debugPrint('No working area found for user $storedUserId');
        _showNoWorkingAreaSnackbar();
        setState(() {
          blockOptions = [];
          isLoading = false;
        });
        return;
      }

      final rawArea = response['working_area'];
      List<dynamic> parsedArea = [];

      if (rawArea is String) {
        parsedArea = jsonDecode(rawArea);
      } else if (rawArea is List) {
        parsedArea = rawArea;
      }
      print(parsedArea);

      List<String> areaList = parsedArea.map((e) => e.toString()).toList();

      setState(() {
        isMasterUser = areaList.contains('MASTER');
        blockOptions = isMasterUser ? blockLines.keys.toList() : areaList;

        if (blockOptions.isNotEmpty) {
          selectedBlock = blockOptions.first;
          _initControllers(selectedBlock!);
        }
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching working area: $e');
      _showNoWorkingAreaSnackbar();
      setState(() {
        blockOptions = [];
        isLoading = false;
      });
    }
  }

  void _initControllers(String block) {
    final lines = blockLines[block] ?? [];
    setState(() {
      linesToShow = lines;
      for (var line in lines) {
        productionControllers[line] ??= TextEditingController();
        targetControllers[line] ??= TextEditingController();
        remarksControllers[line] ??= TextEditingController();
      }
    });

    // 🆕 After controllers are ready, fetch previous target values
    _fetchLatestTargetForBlock(block);
  }

  void _showNoWorkingAreaSnackbar() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No working area assigned. Please contact Admin.'),
          duration: Duration(seconds: 3),
        ),
      );
    });
  }

  @override
  void dispose() {
    for (var controller in productionControllers.values) {
      controller.dispose();
    }
    // for (var controller in targetControllers.values) {
    //   controller.dispose();
    // }
    for (var controller in remarksControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> submitHourlyData() async {
    final client = Supabase.instance.client;

    final now = DateTime.now();
    final todayDate = DateFormat('yyyy-MM-dd').format(now); // 2025-04-29
    final currentHourFormatted = DateFormat('HH:00:00').format(now); // 10:00:00

    int uploadedCount = 0; // 🆕 Counter to track uploads

    try {
      for (var line in linesToShow) {
        final productionQty =
            int.tryParse(productionControllers[line]?.text ?? '') ?? 0;
        final target = int.tryParse(targetControllers[line]?.text ?? '') ?? 0;
        final remarks = remarksControllers[line]?.text ?? '';

        if (productionQty == 0 && target == 0 && remarks.isEmpty) {
          continue; // 🚫 Skip empty lines
        }

        // 🔥 Step 1: Check if this line + date already exists
        final existing =
            await client
                .from('Hourly_Production')
                .select('id')
                .eq('date', todayDate)
                .eq('line', line)
                .eq('hour', currentHourFormatted)
                .maybeSingle();

        if (existing != null) {
          debugPrint('Skipping Line $line - Already exists.');
          continue; // 🚫 Skip if record exists
        }

        // 🔥 Step 2: Insert new record if not exists
        await client.from('Hourly_Production').insert({
          'date': todayDate,
          'hour': currentHourFormatted,
          'block': selectedBlock,
          'line': line,
          'production_qty': productionQty,
          'target': target,
          'remarks': remarks,
        });

        uploadedCount++; // ✅ Count successful uploads
      }

      if (uploadedCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully uploaded $uploadedCount entries!'),
          ),
        );

        // 🔥 Clear fields if something was uploaded
        for (var controller in productionControllers.values) {
          controller.clear();
        }
        for (var controller in targetControllers.values) {
          controller.clear();
        }
        for (var controller in remarksControllers.values) {
          controller.clear();
        }
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No new data uploaded!')));
      }
    } catch (e) {
      debugPrint('Error uploading data: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error uploading data: $e')));
    }
  }

  Future<void> _fetchLatestTargetForBlock(String block) async {
    final client = Supabase.instance.client;
    final now = DateTime.now();
    final todayDate = DateFormat(
      'yyyy-MM-dd',
    ).format(now); // Example: 2025-04-29

    final lines = blockLines[block] ?? [];

    for (var line in lines) {
      try {
        final todayTarget =
            await client
                .from('Hourly_Production')
                .select('target')
                .eq('date', todayDate) // ✅ Only today's data
                .eq('line', line)
                .order('hour', ascending: false) // Latest hour first
                .limit(1)
                .maybeSingle();

        if (todayTarget != null && todayTarget['target'] != null) {
          final latestTarget = todayTarget['target'].toString();
          targetControllers[line]?.text = latestTarget; // Auto-fill
        }
      } catch (e) {
        debugPrint("Error fetching today's target for Line $line: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (blockOptions.isEmpty) {
      return Scaffold(
        body: Center(
          child: Text(
            'No working area assigned.\nPlease contact Admin.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18),
          ),
        ),
      );
    }

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              // mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "$currentDate, $currentHour",
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: selectedBlock,
              items:
                  blockOptions.map((block) {
                    return DropdownMenuItem<String>(
                      value: block,
                      child: Text("$block"),
                    );
                  }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedBlock = value!;
                  _initControllers(value);
                });
              },
              decoration: const InputDecoration(
                labelText: 'Block',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            Expanded(
              child:
                  linesToShow.isNotEmpty
                      ? ListView.builder(
                        itemCount: linesToShow.length,
                        itemBuilder: (context, index) {
                          final line = linesToShow[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            elevation: 4, // 🌟 Slight shadow
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Line $line',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller:
                                              productionControllers[line],
                                          decoration: const InputDecoration(
                                            labelText: 'Production Qty',
                                            border: OutlineInputBorder(),
                                            isDense: true, // 🌟 Compact
                                          ),
                                          keyboardType: TextInputType.number,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: TextField(
                                          controller: targetControllers[line],
                                          decoration: const InputDecoration(
                                            labelText: 'Target',
                                            border: OutlineInputBorder(),
                                            isDense: true,
                                          ),
                                          keyboardType: TextInputType.number,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: remarksControllers[line],
                                    decoration: const InputDecoration(
                                      labelText: 'Remarks',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                    maxLines: 2,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      )
                      : const Center(child: Text('No lines available')),
            ),

            Center(
              child: ElevatedButton(
                onPressed: submitHourlyData,
                child: const Text('Submit'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
