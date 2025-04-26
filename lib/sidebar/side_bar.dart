import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSideBar extends StatefulWidget {
  const AppSideBar({super.key});

  @override
  State<AppSideBar> createState() => _AppSideBarState();
}

class _AppSideBarState extends State<AppSideBar> {
  String userID = '';
  String authority = '';

  @override
  void initState() {
    super.initState();
    loadUserInfo();
  }

  Future<void> loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userID = prefs.getString('userID') ?? '';
      authority = prefs.getString('authority') ?? '';
    });
  }

  Future<void> _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);
    await prefs.remove('userID');
    await prefs.remove('authority');

    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          Container(
            height: 155,
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 46, 16, 5),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color.fromARGB(255, 94, 43, 255),
                  Color.fromARGB(255, 142, 107, 255),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person, size: 20, color: Colors.deepPurple),
                ),
                const SizedBox(height: 12),
                Text(
                  "Welcome",
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                Text(
                  userID,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _buildTile(
            icon: Icons.dashboard,
            label: 'Dashboard',
            onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/home');
            },
          ),
          _buildTile(
            icon: Icons.workspaces_outline,
            label: 'IE & Workstudy',
            onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/IE');
            },
          ),
          if (authority == "ADMIN")
            _buildTile(
              icon: Icons.admin_panel_settings,
              label: 'Admin Panel',
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacementNamed(context, '/admin');
              },
            ),
          const Spacer(),
          const Divider(),
          _buildTile(
            icon: Icons.logout,
            label: 'Logout',
            color: Colors.red,
            onTap: () => _logout(context),
          ),
        ],
      ),
    );
  }

  Widget _buildTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return ListTile(
      leading: Icon(icon, color: color ?? Colors.deepPurple),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: color ?? Colors.black87,
        ),
      ),
      onTap: onTap,
      hoverColor: Colors.deepPurple.withOpacity(0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
    );
  }
}
