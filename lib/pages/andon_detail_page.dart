// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';

// import '../models/andon_issue_model.dart';
// import '../service/andon_service.dart';

// class AndonDetailPage extends StatefulWidget {
//   final AndonIssue issue;
//   final String currentUserId;

//   const AndonDetailPage({
//     super.key,
//     required this.issue,
//     required this.currentUserId,
//   });

//   @override
//   State<AndonDetailPage> createState() => _AndonDetailPageState();
// }

// class _AndonDetailPageState extends State<AndonDetailPage> {
//   late AndonIssue _issue;
//   bool _isUpdatingStatus = false;
//   bool _isLoadingComments = true;
//   List<AndonComment> _comments = [];
//   final _commentCtrl = TextEditingController();

//   String? _creatorName;
//   Map<String, String> _userNameById = {}; // org_id -> name

//   final _timeFormatter = DateFormat('dd MMM, HH:mm');

//   @override
//   void initState() {
//     super.initState();
//     _issue = widget.issue;
//     _loadCreatorName();
//     _loadComments();
//   }

//   @override
//   void dispose() {
//     _commentCtrl.dispose();
//     super.dispose();
//   }

//   /// Load creator name from USERS table using org_id
//   Future<void> _loadCreatorName() async {
//     try {
//       final client = Supabase.instance.client;
//       final resp = await client
//           .from('USERS') // adjust case if your table name is different
//           .select('name')
//           .eq('org_id', _issue.createdById)
//           .limit(1);

//       if (resp is List && resp.isNotEmpty) {
//         final row = resp.first as Map<String, dynamic>;
//         final name = row['name']?.toString();
//         if (name != null && mounted) {
//           setState(() {
//             _creatorName = name;
//           });
//         }
//       }
//     } catch (e) {
//       debugPrint('Error loading creator name: $e');
//     }
//   }

//   Future<void> _loadComments() async {
//     setState(() => _isLoadingComments = true);
//     try {
//       final list = await AndonService.instance.fetchComments(_issue.id);
//       setState(() => _comments = list);

//       // After we have comments, fetch names for all distinct userIds
//       await _loadCommentUserNames(list);
//     } catch (e) {
//       debugPrint('Error loading comments: $e');
//     } finally {
//       if (mounted) setState(() => _isLoadingComments = false);
//     }
//   }

//   /// Fetch all comment user names in a single query
//   Future<void> _loadCommentUserNames(List<AndonComment> comments) async {
//     try {
//       final userIds = comments.map((c) => c.userId).toSet().toList();
//       if (userIds.isEmpty) return;

//       final client = Supabase.instance.client;
//       final resp = await client
//           .from('USERS')
//           .select('org_id, name')
//           .inFilter('org_id', userIds);

//       final map = <String, String>{};
//       if (resp is List) {
//         for (final row in resp) {
//           final r = row as Map<String, dynamic>;
//           final orgId = r['org_id']?.toString();
//           final name = r['name']?.toString();
//           if (orgId != null && name != null) {
//             map[orgId] = name;
//           }
//         }
//       }

//       if (mounted) {
//         setState(() {
//           _userNameById = map;
//         });
//       }
//     } catch (e) {
//       debugPrint('Error loading comment user names: $e');
//     }
//   }

//   Future<void> _changeStatus(String newStatus) async {
//     if (_isUpdatingStatus) return;
//     setState(() => _isUpdatingStatus = true);
//     try {
//       await AndonService.instance.updateStatus(
//         issueId: _issue.id,
//         newStatus: newStatus,
//         userId: widget.currentUserId,
//         fromStatus: _issue.status,
//       );

//       // re-fetch issue for updated timestamps/status
//       final refreshed = await AndonService.instance
//           .fetchIssuesByDate(date: _issue.createdAt)
//           .then(
//             (list) =>
//                 list.firstWhere((i) => i.id == _issue.id, orElse: () => _issue),
//           );

//       setState(() {
//         _issue = refreshed;
//       });
//     } catch (e) {
//       debugPrint('Status change error: $e');
//       if (mounted) {
//         ScaffoldMessenger.of(
//           context,
//         ).showSnackBar(SnackBar(content: Text('Failed to update status: $e')));
//       }
//     } finally {
//       if (mounted) setState(() => _isUpdatingStatus = false);
//     }
//   }

//   String _formatDuration(Duration d) {
//     if (d.inMinutes < 60) return '${d.inMinutes}m';
//     final h = d.inHours;
//     final m = d.inMinutes % 60;
//     return '${h}h ${m}m';
//   }

//   @override
//   Widget build(BuildContext context) {
//     final isSolved = _issue.solvedAt != null;
//     final dur = isSolved ? _issue.timeToSolve! : _issue.timeOpen;
//     final timeText =
//         isSolved
//             ? 'Solved in ${_formatDuration(dur)}'
//             : 'Open for ${_formatDuration(dur)}';

//     final isCreator = _issue.createdById == widget.currentUserId;

//     // IN_PROGRESS button logic
//     final bool canStartInProgress =
//         !isCreator &&
//         _issue.status != 'IN_PROGRESS' &&
//         _issue.status != 'SOLVED' &&
//         _issue.status != 'CLOSED';

//     // SOLVED button logic
//     final bool canMarkSolved = isCreator && _issue.status == 'IN_PROGRESS';

//     final creatorDisplay = _creatorName ?? _issue.createdById;

//     return Scaffold(
//       appBar: AppBar(title: const Text('Issue Details')),
//       body: Column(
//         children: [
//           // Top info card
//           Padding(
//             padding: const EdgeInsets.all(12),
//             child: Card(
//               child: Padding(
//                 padding: const EdgeInsets.all(12),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       _issue.title,
//                       style: Theme.of(context).textTheme.titleMedium,
//                     ),
//                     const SizedBox(height: 8),
//                     Text(_issue.description),
//                     const SizedBox(height: 8),
//                     Text(
//                       '${_issue.section ?? '-'}'
//                       '${_issue.lineNo != null ? ' / Line ${_issue.lineNo}' : ''}',
//                       style: Theme.of(context).textTheme.bodySmall,
//                     ),
//                     const SizedBox(height: 4),
//                     Text(
//                       'Status: ${_issue.status} | Priority: ${_issue.priority}',
//                       style: Theme.of(context).textTheme.bodySmall,
//                     ),
//                     const SizedBox(height: 4),
//                     Text(
//                       timeText,
//                       style: Theme.of(context).textTheme.bodySmall,
//                     ),
//                     const SizedBox(height: 4),
//                     Text(
//                       'Created by: $creatorDisplay',
//                       style: Theme.of(context).textTheme.bodySmall,
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ),

//           // Status buttons row
//           Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 12),
//             child: Row(
//               children: [
//                 Expanded(
//                   child: ElevatedButton(
//                     onPressed:
//                         (_isUpdatingStatus || !canStartInProgress)
//                             ? null
//                             : () => _changeStatus('IN_PROGRESS'),
//                     child:
//                         _isUpdatingStatus && canStartInProgress
//                             ? const SizedBox(
//                               height: 16,
//                               width: 16,
//                               child: CircularProgressIndicator(strokeWidth: 2),
//                             )
//                             : const Text('IN PROGRESS'),
//                   ),
//                 ),
//                 const SizedBox(width: 8),
//                 Expanded(
//                   child: ElevatedButton(
//                     onPressed:
//                         (_isUpdatingStatus || !canMarkSolved)
//                             ? null
//                             : () => _changeStatus('SOLVED'),
//                     child:
//                         _isUpdatingStatus && canMarkSolved
//                             ? const SizedBox(
//                               height: 16,
//                               width: 16,
//                               child: CircularProgressIndicator(strokeWidth: 2),
//                             )
//                             : const Text('SOLVED'),
//                   ),
//                 ),
//               ],
//             ),
//           ),

//           const SizedBox(height: 8),

//           // Comments + input
//           Expanded(
//             child: Column(
//               children: [
//                 Padding(
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 12,
//                     vertical: 4,
//                   ),
//                   child: Row(
//                     children: [
//                       Text(
//                         'Comments',
//                         style: Theme.of(context).textTheme.titleSmall,
//                       ),
//                       const Spacer(),
//                       if (_isLoadingComments)
//                         const SizedBox(
//                           height: 16,
//                           width: 16,
//                           child: CircularProgressIndicator(strokeWidth: 2),
//                         ),
//                     ],
//                   ),
//                 ),
//                 Expanded(
//                   child:
//                       _comments.isEmpty
//                           ? const Center(child: Text('No comments yet.'))
//                           : ListView.builder(
//                             padding: const EdgeInsets.symmetric(
//                               horizontal: 12,
//                               vertical: 4,
//                             ),
//                             itemCount: _comments.length,
//                             itemBuilder: (context, index) {
//                               final c = _comments[index];
//                               final displayName =
//                                   _userNameById[c.userId] ??
//                                   c.userName ??
//                                   c.userId;
//                               final timeStr = _timeFormatter.format(
//                                 c.createdAt,
//                               );

//                               return ListTile(
//                                 dense: true,
//                                 title: Text(c.commentText),
//                                 subtitle: Text(
//                                   '$displayName • $timeStr',
//                                   style: Theme.of(context).textTheme.bodySmall,
//                                 ),
//                               );
//                             },
//                           ),
//                 ),
//                 const Divider(height: 1),
//                 Padding(
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 8,
//                     vertical: 4,
//                   ),
//                   child: Row(
//                     children: [
//                       Expanded(
//                         child: TextField(
//                           controller: _commentCtrl,
//                           decoration: const InputDecoration(
//                             hintText: 'Add a comment...',
//                             border: InputBorder.none,
//                           ),
//                           minLines: 1,
//                           maxLines: 3,
//                         ),
//                       ),
//                       IconButton(
//                         icon: const Icon(Icons.send_rounded),
//                         onPressed: () async {
//                           final text = _commentCtrl.text.trim();
//                           if (text.isEmpty) return;
//                           await AndonService.instance.addComment(
//                             issueId: _issue.id,
//                             userId: widget.currentUserId,
//                             text: text,
//                           );
//                           _commentCtrl.clear();
//                           _loadComments();
//                         },
//                       ),
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/andon_issue_model.dart';
import '../service/andon_service.dart';

class AndonDetailPage extends StatefulWidget {
  final AndonIssue issue;
  final String currentUserId;

  const AndonDetailPage({
    super.key,
    required this.issue,
    required this.currentUserId,
  });

  @override
  State<AndonDetailPage> createState() => _AndonDetailPageState();
}

class _AndonDetailPageState extends State<AndonDetailPage> {
  late AndonIssue _issue;
  bool _isUpdatingStatus = false;
  bool _isLoadingComments = true;
  List<AndonComment> _comments = [];
  final _commentCtrl = TextEditingController();

  String? _creatorName;
  String? _currentUserName;
  Map<String, String> _userNameById = {}; // org_id -> name

  final _timeFormatter = DateFormat('dd MMM, HH:mm');

  @override
  void initState() {
    super.initState();
    _issue = widget.issue;
    _loadCreatorName();
    _loadCurrentUserName();
    _loadComments();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  /// Load issue creator's name from USERS (org_id -> name)
  Future<void> _loadCreatorName() async {
    try {
      final client = Supabase.instance.client;
      final resp = await client
          .from('USERS')
          .select('name')
          .eq('org_id', _issue.createdById)
          .limit(1);

      if (resp is List && resp.isNotEmpty) {
        final row = resp.first as Map<String, dynamic>;
        final name = row['name']?.toString();
        if (name != null && mounted) {
          setState(() {
            _creatorName = name;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading creator name: $e');
    }
  }

  /// Load current (logged-in) user's name, used for auto comments
  Future<void> _loadCurrentUserName() async {
    try {
      final client = Supabase.instance.client;
      final resp = await client
          .from('USERS')
          .select('name')
          .eq('org_id', widget.currentUserId)
          .limit(1);

      if (resp is List && resp.isNotEmpty) {
        final row = resp.first as Map<String, dynamic>;
        final name = row['name']?.toString();
        if (name != null && mounted) {
          setState(() {
            _currentUserName = name;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading current user name: $e');
    }
  }

  Future<void> _loadComments() async {
    setState(() => _isLoadingComments = true);
    try {
      final list = await AndonService.instance.fetchComments(_issue.id);
      setState(() => _comments = list);

      await _loadCommentUserNames(list);
    } catch (e) {
      debugPrint('Error loading comments: $e');
    } finally {
      if (mounted) setState(() => _isLoadingComments = false);
    }
  }

  /// Fetch user names for all commenters in a single query
  Future<void> _loadCommentUserNames(List<AndonComment> comments) async {
    try {
      final userIds = comments.map((c) => c.userId).toSet().toList();
      if (userIds.isEmpty) return;

      final client = Supabase.instance.client;
      final resp = await client
          .from('USERS')
          .select('org_id, name')
          .inFilter('org_id', userIds);

      final map = <String, String>{};
      if (resp is List) {
        for (final row in resp) {
          final r = row as Map<String, dynamic>;
          final orgId = r['org_id']?.toString();
          final name = r['name']?.toString();
          if (orgId != null && name != null) {
            map[orgId] = name;
          }
        }
      }

      if (mounted) {
        setState(() {
          _userNameById = map;
        });
      }
    } catch (e) {
      debugPrint('Error loading comment user names: $e');
    }
  }

  Future<void> _changeStatus(String newStatus) async {
    if (_isUpdatingStatus) return;
    setState(() => _isUpdatingStatus = true);

    try {
      // 1) Update status & timestamps in DB
      await AndonService.instance.updateStatus(
        issueId: _issue.id,
        newStatus: newStatus,
        userId: widget.currentUserId,
        fromStatus: _issue.status,
      );

      // 2) Auto status comment text
      final displayName = _currentUserName ?? widget.currentUserId;
      final timeStr = _timeFormatter.format(DateTime.now());
      String? autoText;

      if (newStatus == 'IN_PROGRESS') {
        autoText = 'Problem noticed and solution in progress';
      } else if (newStatus == 'SOLVED') {
        autoText = 'the problem is solved.';
      }

      // 3) Insert auto comment if needed
      if (autoText != null) {
        await AndonService.instance.addComment(
          issueId: _issue.id,
          userId: widget.currentUserId,
          userName: _currentUserName,
          text: autoText,
        );
      }

      // 4) Refresh issue & comments
      final refreshed = await AndonService.instance
          .fetchIssuesByDate(date: _issue.createdAt)
          .then(
            (list) =>
                list.firstWhere((i) => i.id == _issue.id, orElse: () => _issue),
          );

      setState(() {
        _issue = refreshed;
      });

      await _loadComments();
    } catch (e) {
      debugPrint('Status change error: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update status: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUpdatingStatus = false);
    }
  }

  String _formatDuration(Duration d) {
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    final h = d.inHours;
    final m = d.inMinutes % 60;
    return '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final isSolved = _issue.solvedAt != null;
    final dur = isSolved ? _issue.timeToSolve! : _issue.timeOpen;
    final timeText =
        isSolved
            ? 'Solved in ${_formatDuration(dur)}'
            : 'Open for ${_formatDuration(dur)}';

    final isCreator = _issue.createdById == widget.currentUserId;

    // IN_PROGRESS button logic
    final bool canStartInProgress =
        !isCreator &&
        _issue.status != 'IN_PROGRESS' &&
        _issue.status != 'SOLVED' &&
        _issue.status != 'CLOSED';

    // SOLVED button logic
    final bool canMarkSolved = isCreator && _issue.status == 'IN_PROGRESS';

    final creatorDisplay = _creatorName ?? _issue.createdById;
    final responsibleDept = _issue.responsibleDept ?? '-';

    return Scaffold(
      appBar: AppBar(title: const Text('Issue Details')),
      body: Column(
        children: [
          // Top info card
          Padding(
            padding: const EdgeInsets.all(12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _issue.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(_issue.description),
                    const SizedBox(height: 8),
                    Text(
                      '${_issue.section ?? '-'}'
                      '${_issue.lineNo != null ? ' / Line ${_issue.lineNo}' : ''}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Responsible Dept: $responsibleDept',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Status: ${_issue.status} | Priority: ${_issue.priority}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      timeText,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Created by: $creatorDisplay',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Status buttons row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed:
                        (_isUpdatingStatus || !canStartInProgress)
                            ? null
                            : () => _changeStatus('IN_PROGRESS'),
                    child:
                        _isUpdatingStatus && canStartInProgress
                            ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Text('IN PROGRESS'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed:
                        (_isUpdatingStatus || !canMarkSolved)
                            ? null
                            : () => _changeStatus('SOLVED'),
                    child:
                        _isUpdatingStatus && canMarkSolved
                            ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Text('SOLVED'),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Comments + input
          Expanded(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      Text(
                        'Comments',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const Spacer(),
                      if (_isLoadingComments)
                        const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child:
                      _comments.isEmpty
                          ? const Center(child: Text('No comments yet.'))
                          : ListView.builder(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            itemCount: _comments.length,
                            itemBuilder: (context, index) {
                              final c = _comments[index];
                              final displayName =
                                  _userNameById[c.userId] ??
                                  c.userName ??
                                  c.userId;
                              final timeStr = _timeFormatter.format(
                                c.createdAt,
                              );

                              // Detect auto status comments and color them differently
                              final isStatusComment =
                                  c.commentText.contains(
                                    'solution in progress',
                                  ) ||
                                  c.commentText.contains('problem is solved');

                              final bgColor =
                                  isStatusComment
                                      ? Theme.of(context)
                                          .colorScheme
                                          .secondaryContainer
                                          .withOpacity(0.7)
                                      : Theme.of(context)
                                          .colorScheme
                                          .surfaceVariant
                                          .withOpacity(0.6);

                              return Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                decoration: BoxDecoration(
                                  color: bgColor,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: ListTile(
                                  dense: true,
                                  title: Text(c.commentText),
                                  subtitle: Text(
                                    '$displayName • $timeStr',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                ),
                              );
                            },
                          ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentCtrl,
                          decoration: const InputDecoration(
                            hintText: 'Add a comment...',
                            border: InputBorder.none,
                          ),
                          minLines: 1,
                          maxLines: 3,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send_rounded),
                        onPressed: () async {
                          final text = _commentCtrl.text.trim();
                          if (text.isEmpty) return;
                          await AndonService.instance.addComment(
                            issueId: _issue.id,
                            userId: widget.currentUserId,
                            userName: _currentUserName,
                            text: text,
                          );
                          _commentCtrl.clear();
                          _loadComments();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
