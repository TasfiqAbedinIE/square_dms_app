import 'package:flutter/material.dart';
import 'package:square_dms_trial/globals.dart';

class AppSideBar extends StatelessWidget {
  const AppSideBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            height: 180, // 👈 custom height
            color: const Color.fromARGB(255, 180, 255, 237),
            padding: const EdgeInsets.all(16),
            alignment: Alignment.centerLeft,
            child: Text(
              'Welcome, $userID',
              style: TextStyle(
                color: Colors.black,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard),
            title: const Text('DASHBOARD'),
            onTap: () {
              Navigator.pop(context); // Close drawer
              Navigator.pushReplacementNamed(context, '/home');
            },
          ),

          ListTile(
            leading: const Icon(Icons.workspaces_outline),
            title: const Text('IE & WORKSTUDY'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/IE');
            },
          ),

          if (userAuthority == "ADMIN")
            ListTile(
              leading: const Icon(Icons.admin_panel_settings),
              title: const Text('ADMIN'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacementNamed(context, '/admin');
              },
            ),

          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
    );
  }
}
