import 'dart:math';
import 'package:flutter/material.dart';
import 'package:square_dms_trial/sidebar/side_bar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({Key? key}) : super(key: key);

  @override
  _AboutScreenState createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  final SupabaseClient supabase = Supabase.instance.client;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _bugController = TextEditingController();

  List<Map<String, dynamic>> _myBugs = [];
  List<Map<String, dynamic>> _allBugs = [];
  bool _showAll = false;
  bool _isLoading = false;

  static const List<String> currentFeatures = [
    'Login & Authentication',
    'Production Dashboard',
    'Capacity Record Entry',
    'Skill Matrix Management',
    'Skill Matrix Report',
    'Time Study Module',
    'Push Notifications',
    'Non-Productive Time Tracking',
    'Standard Process Video',
  ];

  static const List<Map<String, String>> upcomingTimeline = [
    {'date': 'May 2025', 'description': 'Cutting Excess Booking Record'},
    {'date': 'June 2025', 'description': 'Efficiency Report Generation'},
    {'date': 'July 2025', 'description': 'RAG-Powered Q&A'},
    {'date': 'Aug 2025', 'description': 'KPI initialization'},
  ];

  @override
  void initState() {
    super.initState();
    _loadBugs();
  }

  Future<void> _loadBugs() async {
    final prefs = await SharedPreferences.getInstance();
    final userID = prefs.getString('userID');
    if (userID == null) return;
    final myRes = await supabase
        .from('bugReport')
        .select()
        .eq('user_id', userID)
        .order('created_at', ascending: false);
    final allRes = await supabase
        .from('bugReport')
        .select()
        .order('created_at', ascending: false);
    setState(() {
      _myBugs = List<Map<String, dynamic>>.from(myRes as List);
      _allBugs = List<Map<String, dynamic>>.from(allRes as List);
    });
  }

  void _openBugModal() async {
    final prefs = await SharedPreferences.getInstance();
    final userID = prefs.getString('userID');
    if (userID == null) return;

    final ref =
        '${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(1000000).toString().padLeft(6, '0')}';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 40,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Report a Bug',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Reference: $ref',
                    style: const TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _bugController,
                    minLines: 3,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      hintText: 'Describe the issue...',
                      border: OutlineInputBorder(),
                    ),
                    validator:
                        (val) =>
                            val == null || val.isEmpty
                                ? 'Please enter a description'
                                : null,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed:
                            _isLoading
                                ? null
                                : () async {
                                  if (!_formKey.currentState!.validate())
                                    return;
                                  setState(() => _isLoading = true);
                                  bool success = false;
                                  try {
                                    await supabase.from('bugReport').insert({
                                      'user_id': userID,
                                      'description': _bugController.text.trim(),
                                      'ref_num': ref,
                                      'up_vote': 0,
                                      'upvote_id': [],
                                      'down_vote': 0,
                                      'downvote_id': [],
                                      'status': 'Reviewing',
                                    });
                                    await _loadBugs();
                                    success = true;
                                  } catch (_) {
                                    success = false;
                                  } finally {
                                    setState(() => _isLoading = false);
                                    _bugController.clear();
                                    Navigator.of(ctx).pop(); // Close modal
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          success
                                              ? 'Bug reported successfully (Ref: $ref)'
                                              : 'Failed to report bug.',
                                        ),
                                        backgroundColor:
                                            success ? Colors.green : Colors.red,
                                      ),
                                    );
                                  }
                                },
                        child:
                            _isLoading
                                ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                                : const Text('Save'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBugList(List<Map<String, dynamic>> list) {
    if (list.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('No bug reports.', style: TextStyle(color: Colors.white)),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: list.length,
      itemBuilder: (context, idx) {
        final bug = list[idx];

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ref: ${bug['ref_num']}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(bug['description'], style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.thumb_up, color: Colors.green),
                      onPressed: () async {
                        await supabase
                            .from('bugReport')
                            .update({'up_vote': (bug['up_vote'] ?? 0) + 1})
                            .eq('ref_num', bug['ref_num']);
                        await _loadBugs();
                      },
                    ),
                    Text('${bug['up_vote'] ?? 0}'),
                    const SizedBox(width: 16),
                    IconButton(
                      icon: const Icon(Icons.thumb_down, color: Colors.red),
                      onPressed: () async {
                        await supabase
                            .from('bugReport')
                            .update({'down_vote': (bug['down_vote'] ?? 0) + 1})
                            .eq('ref_num', bug['ref_num']);
                        await _loadBugs();
                      },
                    ),
                    Text('${bug['down_vote'] ?? 0}'),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Status: ${bug['status'] ?? 'Unknown'}',
                  style: const TextStyle(color: Colors.blueGrey),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: AppSideBar(),
      appBar: AppBar(
        title: const Text('About'),
        backgroundColor: const Color.fromARGB(255, 94, 43, 255),
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<bool>(
            icon: const Icon(Icons.settings),
            onSelected: (val) => setState(() => _showAll = val),
            itemBuilder:
                (_) => [
                  const PopupMenuItem(value: false, child: Text('My Bugs')),
                  const PopupMenuItem(value: true, child: Text('All Bugs')),
                ],
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExpansionTile(
                    title: const Text('Current Functionality'),
                    children:
                        currentFeatures
                            .map<Widget>(
                              (f) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 2,
                                  horizontal: 16,
                                ),
                                child: Row(
                                  children: [
                                    const Text('• '),
                                    Expanded(child: Text(f)),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                  ),
                  const SizedBox(height: 16),
                  ExpansionTile(
                    title: const Text('Upcoming Development'),
                    children:
                        upcomingTimeline
                            .map<Widget>(
                              (item) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                  horizontal: 16,
                                ),
                                child: Row(
                                  children: [
                                    Column(
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.black,
                                          ),
                                        ),
                                        Container(
                                          width: 1,
                                          height: 40,
                                          color: Colors.grey,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item['date']!,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(item['description']!),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                  ),

                  const SizedBox(height: 16),
                  Container(
                    height: MediaQuery.of(context).size.height,
                    width: MediaQuery.of(context).size.width,
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(255, 40, 0, 172),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(25),
                        topRight: Radius.circular(25),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            _showAll ? 'All Reports' : 'My Reports',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        _buildBugList(_showAll ? _allBugs : _myBugs),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openBugModal,
        child: const Icon(Icons.bug_report),
      ),
    );
  }
}
