import 'package:flutter/material.dart';
import 'package:square_dms_trial/sidebar/side_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('DASHBOARD')),
      drawer: AppSideBar(),
      body: const Center(child: Text('Home Screen')),
    );
  }
}
