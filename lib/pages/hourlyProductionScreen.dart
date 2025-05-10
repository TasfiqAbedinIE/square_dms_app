import 'package:flutter/material.dart';
import 'package:square_dms_trial/subPages/hourlyReportPage.dart';
import 'package:square_dms_trial/subPages/HourlyDataEntryPage.dart';
import 'package:square_dms_trial/globals.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HourlyProductionScreen extends StatefulWidget {
  const HourlyProductionScreen({super.key});

  @override
  State<HourlyProductionScreen> createState() => _HourlyProductionScreenState();
}

class _HourlyProductionScreenState extends State<HourlyProductionScreen> {
  int _selectedIndex = 0;

  // These always contain 2 items to avoid index or length issues
  late final List<Widget> _screens;
  late final List<String> _titles;
  // String userID = '';
  String authority = '';

  @override
  void initState() {
    super.initState();
    loadUserInfo();

    _screens = [const DashboardScreen(), const HourlyDataEntryScreen()];

    _titles = ["Hourly Report", "Production Entry"];
  }

  Future<void> loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      // userID = prefs.getString('userID') ?? '';
      authority = prefs.getString('authority') ?? '';
    });
  }

  void _onItemTapped(int index) {
    if (index == 1 && authority == 'GUEST') {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Access Denied")));
      return;
    }

    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        backgroundColor: const Color.fromARGB(255, 52, 54, 51),
        foregroundColor: Colors.white,
      ),
      body:
          _selectedIndex == 1 && userAuthority == 'GUEST'
              ? const Center(child: Text("Access Denied"))
              : _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Color.fromARGB(255, 52, 54, 51),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.analytics), label: 'Report'),
          BottomNavigationBarItem(
            icon: Icon(Icons.edit),
            label: 'Production Entry',
          ),
        ],
      ),
    );
  }
}
