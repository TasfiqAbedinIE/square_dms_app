import 'package:flutter/material.dart';
import 'package:square_dms_trial/subPages/SkillMatrixRecordPage.dart';

class SkillMatrixScreen extends StatefulWidget {
  const SkillMatrixScreen({super.key});

  @override
  State<SkillMatrixScreen> createState() => _SkillMatrixScreenState();
}

class _SkillMatrixScreenState extends State<SkillMatrixScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    SkillMatrixRecordPage(),
    const Center(child: Text("Skill Matrix Report Page")),
  ];

  // final List<String> _titles = ["Capacity Record", "Skill Matrix Report"];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(title: Text(_titles[_selectedIndex])),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.blue,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.assessment),
            label: 'Capacity Record',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_on),
            label: 'Skill Matrix Report',
          ),
        ],
      ),
    );
  }
}
