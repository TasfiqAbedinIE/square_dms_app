import 'package:flutter/material.dart';
import 'package:square_dms_trial/sidebar/side_bar.dart';

class IEScreen extends StatelessWidget {
  const IEScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Industrial Engineering")),
      drawer: AppSideBar(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            _buildCard(context, "Efficiency", Icons.show_chart, "/efficiency"),
            _buildCard(
              context,
              "Production",
              Icons.production_quantity_limits,
              "/production",
            ),
            _buildCard(
              context,
              "Skill Matrix",
              Icons.local_activity,
              "/skill_matrix",
            ),
            _buildCard(context, "SMV", Icons.timer, "/smv"),
            _buildCard(context, "Target", Icons.track_changes, "/target"),
            _buildCard(context, "Line Plan", Icons.timeline, "/lineplan"),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(
    BuildContext context,
    String title,
    IconData icon,
    String routeName,
  ) {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(context, routeName);
      },
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 4,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: Colors.blue),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
