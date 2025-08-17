import 'package:flutter/material.dart';
import 'package:square_dms_trial/subPages/manpowerSamEarnerPage.dart';
import 'package:square_dms_trial/subPages/manpowerMinuteAllocationPage.dart';
import 'package:square_dms_trial/subPages/manpowerOtherAllocationPage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:square_dms_trial/database/manpower_summary_database.dart';
import 'package:intl/intl.dart';

class ManpowerOptimizationScreen extends StatefulWidget {
  @override
  _ManpowerOptimizationScreenState createState() =>
      _ManpowerOptimizationScreenState();
}

class _ManpowerOptimizationScreenState
    extends State<ManpowerOptimizationScreen> {
  int _selectedIndex = 0;
  int? totalPresentCount;
  bool isDownloading = false;

  String? selectedBlock;
  late final String todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

  int samEarnerTotal = 0;
  int minuteAllocationTotal = 0;
  int otherAllocationTotal = 0;

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

  void _handleBlockChange(String block) async {
    setState(() => selectedBlock = block);
    await _updateTotalPresentForSelectedBlock();
  }

  int samAllocated = 0;
  int minuteAllocated = 0;
  int otherAllocated = 0;

  void _calculateSamAllocated(int total) {
    samAllocated = total;
    _updateTotalAllocated();
  }

  void _calculateMinuteAllocated(int total) {
    minuteAllocated = total;
    _updateTotalAllocated();
  }

  void _calculateOtherAllocated(int total) {
    otherAllocated = total;
    _updateTotalAllocated();
  }

  int totalAllocatedManpower = 0;
  void _updateTotalAllocated() {
    setState(() {
      totalAllocatedManpower = samAllocated + minuteAllocated + otherAllocated;
    });
  }

  // void _calculateAllocatedManpower(int newTotal) {
  //   setState(() {
  //     totalAllocatedManpower = newTotal;
  //   });
  // }

  List<Widget> _getSegments() {
    return [
      SamEarnerPage(
        onBlockChanged: _handleBlockChange,
        // onAllocationChanged: _calculateAllocatedManpower,
        onAllocationChanged: _calculateSamAllocated,
      ),
      ManpowerMinuteAllocationPage(
        onBlockChanged: _handleBlockChange,
        onAllocationChanged: _calculateMinuteAllocated,
      ),
      ManpowerOtherAllocationPage(
        selectedBlock: selectedBlock ?? '',
        selectedDate: DateTime.now(),
        onAllocationChanged: _calculateOtherAllocated,
      ),
    ];
  }

  final List<String> _titles = ['SAM EARNER', 'MINUTE ALLOCATION', 'OTHERS'];

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  Future<void> _downloadAttendanceData() async {
    if (selectedBlock == null) return;

    setState(() => isDownloading = true);

    final blockLinesList = blockLines[selectedBlock!] ?? [];
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    try {
      final client = Supabase.instance.client;
      final response = await client
          .from('sewing_daily_attendance')
          .select()
          .eq('date', todayStr)
          .filter('line_no', 'in', '(${blockLinesList.join(",")})');

      if (response == null || response.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No attendance data available for today')),
        );
        setState(() => isDownloading = false);
        return;
      }

      // Sum all present values
      int totalPresent = 0;
      for (final row in response) {
        totalPresent += (row['operator_present'] ?? 0) as int;
        totalPresent += (row['helper_present'] ?? 0) as int;
        totalPresent += (row['input_girl_present'] ?? 0) as int;
        totalPresent += (row['sup_present'] ?? 0) as int;
        totalPresent += (row['tech_present'] ?? 0) as int;
        totalPresent += (row['OA_present'] ?? 0) as int;
      }

      // Save to SQLite
      await ManpowerSummaryDatabase.instance.insertSummary(
        todayStr,
        selectedBlock!,
        totalPresent,
      );

      setState(() {
        totalPresentCount = totalPresent;
        isDownloading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Manpower data saved successfully')),
      );
    } catch (e) {
      debugPrint('Error downloading attendance: $e');
      setState(() => isDownloading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch attendance data')),
      );
    }
  }

  Future<void> _updateTotalPresentForSelectedBlock() async {
    if (selectedBlock == null) return;

    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final total = await ManpowerSummaryDatabase.instance.fetchTotalPresent(
      todayStr,
      selectedBlock!,
    );

    setState(() => totalPresentCount = total);
  }

  Widget _buildInfoChip(String label, int value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blue[100],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text('$label: $value', style: const TextStyle(fontSize: 9)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Manpower Optimization'),
            if (totalPresentCount != null)
              Column(
                children: [
                  _buildInfoChip('Allocated', totalAllocatedManpower),
                  const SizedBox(height: 6),
                  _buildInfoChip('Present', totalPresentCount!),
                ],
              ),
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: isDownloading ? null : _downloadAttendanceData,
              tooltip: 'Download Attendance',
            ),
          ],
        ),
      ),
      body: _getSegments()[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.group), label: 'SAM EARNER'),
          BottomNavigationBarItem(
            icon: Icon(Icons.access_time),
            label: 'MINUTE ALLOCATION',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.more_horiz),
            label: 'OTHERS',
          ),
        ],
      ),
    );
  }
}
