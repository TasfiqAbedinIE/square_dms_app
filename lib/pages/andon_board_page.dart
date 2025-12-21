import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/andon_issue_model.dart';
import '../service/andon_service.dart';
import 'andon_detail_page.dart';
import '../subPages/andon_new_issue_sheet.dart';

class AndonBoardPage extends StatefulWidget {
  const AndonBoardPage({super.key});

  @override
  State<AndonBoardPage> createState() => _AndonBoardPageState();
}

class _AndonBoardPageState extends State<AndonBoardPage> {
  String? _userId;
  bool _isLoading = true;
  List<AndonIssue> _issues = [];
  DateTime _selectedDate = DateTime.now();

  String _selectedResponsibleDept = 'All';

  final List<String> _responsibleDeptOptions = [
    'All',
    'Cutting',
    'Printing',
    'Embroidery',
    'Washing',
    'Maintenance',
    'Quality',
    'Planning',
    'IE',
    'Store',
    'TPD',
    'Marketing',
  ];

  final _dateFormat = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    _initUserAndLoad();
  }

  Future<void> _initUserAndLoad() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('userID') ?? '';
    await _loadIssues();
  }

  Future<void> _loadIssues() async {
    setState(() => _isLoading = true);

    try {
      final list = await AndonService.instance.fetchIssuesFiltered(
        date: _selectedDate,
        responsibleDept:
            _selectedResponsibleDept == 'All' ? null : _selectedResponsibleDept,
      );

      setState(() {
        _issues = list;
      });
    } catch (e) {
      debugPrint('Error loading issues: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load issues: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDuration(Duration d) {
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    final h = d.inHours;
    final m = d.inMinutes % 60;
    return '${h}h ${m}m';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'OPEN':
        return Colors.redAccent;
      case 'NOTICED':
        return Colors.orange;
      case 'IN_PROGRESS':
        return Colors.blue;
      case 'SOLVED':
        return Colors.green;
      case 'CLOSED':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
      _loadIssues();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = _dateFormat.format(_selectedDate);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Production Issues (Andon)'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadIssues),
        ],
      ),
      body: Column(
        children: [
          // Date filter row
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Row(
              children: [
                // DATE BUTTON
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_month, size: 18),
                    label: Text(
                      DateFormat('dd MMM yyyy').format(_selectedDate),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // RESPONSIBLE DEPARTMENT FILTER
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedResponsibleDept,
                    decoration: const InputDecoration(
                      labelText: 'Dept',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                    ),
                    items:
                        _responsibleDeptOptions
                            .map(
                              (dept) => DropdownMenuItem(
                                value: dept,
                                child: Text(dept),
                              ),
                            )
                            .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _selectedResponsibleDept = value;
                      });
                      _loadIssues();
                    },
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _issues.isEmpty
                    ? Center(
                      child: Text(
                        'No issues found for $dateLabel',
                        textAlign: TextAlign.center,
                      ),
                    )
                    : RefreshIndicator(
                      onRefresh: _loadIssues,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(
                          12,
                          8,
                          12,
                          80, // 👈 extra bottom padding so FAB doesn't overlap last card
                        ),
                        itemCount: _issues.length,
                        itemBuilder: (context, index) {
                          final issue = _issues[index];
                          final isSolved = issue.solvedAt != null;
                          final dur =
                              isSolved ? issue.timeToSolve! : issue.timeOpen;
                          final subtitleTime =
                              isSolved
                                  ? 'Solved in ${_formatDuration(dur)}'
                                  : 'Open for ${_formatDuration(dur)}';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              onTap: () async {
                                await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder:
                                        (_) => AndonDetailPage(
                                          issue: issue,
                                          currentUserId: _userId ?? '',
                                        ),
                                  ),
                                );
                                _loadIssues(); // refresh after detail
                              },
                              title: Text(
                                issue.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(
                                    '${issue.section ?? ''}'
                                    '${issue.lineNo != null ? ' / Line ${issue.lineNo}' : ''}',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    subtitleTime,
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                              trailing: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _statusColor(
                                        issue.status,
                                      ).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      issue.status,
                                      style: TextStyle(
                                        color: _statusColor(issue.status),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    issue.priority,
                                    style:
                                        Theme.of(context).textTheme.labelSmall,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add_alert_rounded),
        label: const Text('New Issue'),
        onPressed: () async {
          if (_userId == null || _userId!.isEmpty) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('User ID not found')));
            return;
          }

          final created = await showModalBottomSheet<bool>(
            context: context,
            isScrollControlled: true,
            builder: (_) => AndonNewIssueSheet(currentUserId: _userId!),
          );

          if (created == true) {
            _loadIssues();
          }
        },
      ),
    );
  }
}
