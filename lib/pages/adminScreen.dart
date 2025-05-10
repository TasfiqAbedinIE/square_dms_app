import 'package:flutter/material.dart';
import 'package:square_dms_trial/sidebar/side_bar.dart';
import 'package:square_dms_trial/subPages/userListPage.dart';
import 'package:square_dms_trial/subPages/userSewingProcessPage.dart';
// Add more import files for other features as you create them

class AdminPage extends StatelessWidget {
  const AdminPage({super.key});

  void _navigate(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  Widget _buildCard({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 4,
        margin: const EdgeInsets.symmetric(vertical: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Icon(icon, size: 30),
              const SizedBox(width: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Panel')),
      drawer: AppSideBar(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            _buildCard(
              icon: Icons.people,
              title: 'Users List',
              onTap: () => _navigate(context, const UserListPage()),
            ),
            _buildCard(
              icon: Icons.switch_access_shortcut_add,
              title: 'Register Sewing Process',
              onTap: () => _navigate(context, const RegisterProcessPage()),
            ),
            // _buildCard(
            //   icon: Icons.map,
            //   title: 'Register NP Factors',
            //   onTap: () {
            //     // You can link to a page where working areas are added/edited
            //     ScaffoldMessenger.of(context).showSnackBar(
            //       const SnackBar(content: Text('Working Areas Clicked')),
            //     );
            //   },
            // ),
            // _buildCard(
            //   icon: Icons.list_alt,
            //   title: 'System Logs',
            //   onTap: () {
            //     // You can link to logs or activity tracking screen
            //     ScaffoldMessenger.of(context).showSnackBar(
            //       const SnackBar(content: Text('System Logs Clicked')),
            //     );
            //   },
            // ),
            // _buildCard(
            //   icon: Icons.settings,
            //   title: 'Settings',
            //   onTap: () {
            //     // Link to admin settings
            //     ScaffoldMessenger.of(context).showSnackBar(
            //       const SnackBar(content: Text('Settings Clicked')),
            //     );
            //   },
            // ),
            // _buildCard(
            //   icon: Icons.home,
            //   title: 'Back to Home',
            //   onTap: () {
            //     Navigator.pop(context); // or push to HomeScreen if separate
            //   },
            // ),
          ],
        ),
      ),
    );
  }
}
