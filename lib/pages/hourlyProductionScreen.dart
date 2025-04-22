import 'package:flutter/material.dart';
import 'package:square_dms_trial/subPages/hourlyReportPage.dart';
import 'package:square_dms_trial/subPages/HourlyDataEntryPage.dart';
import 'package:square_dms_trial/globals.dart';

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

  @override
  void initState() {
    super.initState();

    _screens = [const DashboardScreen(), const HourlyDataEntryScreen()];

    _titles = ["Hourly Report", "Production Entry"];
  }

  void _onItemTapped(int index) {
    if (index == 1 && userAuthority == 'GUEST') {
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
      appBar: AppBar(title: Text(_titles[_selectedIndex])),
      body:
          _selectedIndex == 1 && userAuthority == 'GUEST'
              ? const Center(child: Text("Access Denied"))
              : _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.blue,
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
