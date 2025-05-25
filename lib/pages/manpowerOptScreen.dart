import 'package:flutter/material.dart';
import 'package:square_dms_trial/subPages/manpowerSamEarnerPage.dart';

class ManpowerOptimizationScreen extends StatefulWidget {
  @override
  _ManpowerOptimizationScreenState createState() =>
      _ManpowerOptimizationScreenState();
}

class _ManpowerOptimizationScreenState
    extends State<ManpowerOptimizationScreen> {
  int _selectedIndex = 0;

  final List<Widget> _segments = [
    SamEarnerPage(), // Placeholder
    Center(child: Text('MINUTE ALLOCATION Screen (Coming Soon)')),
    Center(child: Text('OTHERS Screen (Coming Soon)')),
  ];

  final List<String> _titles = ['SAM EARNER', 'MINUTE ALLOCATION', 'OTHERS'];

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Manpower Optimization'), centerTitle: true),
      body: _segments[_selectedIndex],
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
