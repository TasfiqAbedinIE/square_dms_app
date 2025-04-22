import 'package:flutter/material.dart';
import 'package:square_dms_trial/sidebar/side_bar.dart';
import 'package:square_dms_trial/subPages/userListPage.dart';

class AdminPage extends StatelessWidget {
  const AdminPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Panel')),
      drawer: AppSideBar(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            GestureDetector(
              onTap: () {
                // Navigate to user list page or perform action
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const UserListPage()),
                );
              },
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  child: const Row(
                    children: [
                      Icon(Icons.people, size: 30),
                      SizedBox(width: 16),
                      Text(
                        'Users List',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
