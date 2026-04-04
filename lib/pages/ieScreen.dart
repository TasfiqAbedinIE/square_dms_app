import 'package:flutter/material.dart';
import 'package:square_dms_trial/sidebar/side_bar.dart';

class IEScreen extends StatelessWidget {
  const IEScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Industrial Engineering'),
        backgroundColor: const Color.fromARGB(255, 94, 43, 255),
        foregroundColor: Colors.white,
      ),
      drawer: const AppSideBar(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            _buildCard(
              context,
              'Hourly Production',
              Icons.production_quantity_limits,
              '/production',
            ),
            _buildCard(
              context,
              'Skill Matrix',
              Icons.local_activity,
              '/skill_matrix',
            ),
            _buildCard(
              context,
              'Non Productive Time',
              Icons.timelapse,
              '/nonProductive',
            ),
            _buildCard(
              context,
              'Manpower Optimization',
              Icons.people,
              '/manpowerOpt',
            ),
            _buildCard(
              context,
              'Andon Board',
              Icons.policy_sharp,
              '/andonBoardPage',
            ),
            _buildCard(
              context,
              'Process Video',
              Icons.video_camera_back,
              '/processVideo',
            ),
            _buildCard(
              context,
              'Preproduction Record',
              Icons.fact_check_outlined,
              '/preproductionMeeting',
            ),
            // _buildCard(
            //   context,
            //   '5S Audit',
            //   Icons.rule_folder_outlined,
            //   '/fiveSAudit',
            // ),
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
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 48, color: Colors.blue),
                const SizedBox(height: 10),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
