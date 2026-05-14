// lib/services/andon_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/andon_issue_model.dart';
import 'pushnotificationsend.dart';

class AndonMentionUser {
  final String orgId;
  final String? name;
  final String? dept;
  final String? designation;

  const AndonMentionUser({
    required this.orgId,
    this.name,
    this.dept,
    this.designation,
  });

  String get displayName {
    final trimmedName = name?.trim();
    if (trimmedName != null && trimmedName.isNotEmpty) return trimmedName;
    return orgId;
  }

  String get mentionToken => '@$orgId';

  factory AndonMentionUser.fromMap(Map<String, dynamic> map) {
    return AndonMentionUser(
      orgId: map['org_id']?.toString() ?? '',
      name: map['name']?.toString(),
      dept: map['dept']?.toString(),
      designation: map['designation']?.toString(),
    );
  }
}

class AndonService {
  AndonService._();
  static final AndonService instance = AndonService._();

  final _client = Supabase.instance.client;

  Future<List<AndonIssue>> fetchIssues({
    String? status, // e.g. 'OPEN'
    String? block, // optional filter
  }) async {
    var query = _client
        .from('andon_issues')
        .select()
        .eq('is_active', true)
        .order('created_at', ascending: false);

    // if (status != null && status.isNotEmpty) {
    //   query = query.eq('status', status);
    // }
    // if (block != null && block.isNotEmpty) {
    //   query = query.eq('block', block);
    // }

    final resp = await query;
    final list = (resp as List).cast<Map<String, dynamic>>();
    return list.map((m) => AndonIssue.fromMap(m)).toList();
  }

  Future<List<AndonIssue>> fetchIssuesByDate({required DateTime date}) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));

    final resp = await _client
        .from('andon_issues')
        .select()
        .eq('is_active', true)
        .gte('created_at', start.toIso8601String())
        .lt('created_at', end.toIso8601String())
        .order('created_at', ascending: false);

    final list = (resp as List).cast<Map<String, dynamic>>();
    return list.map((m) => AndonIssue.fromMap(m)).toList();
  }

  Future<AndonIssue> createIssue(AndonIssue issue) async {
    final resp =
        await _client
            .from('andon_issues')
            .insert(issue.toInsertMap())
            .select()
            .single();
    return AndonIssue.fromMap(resp);
  }

  Future<void> updateStatus({
    required String issueId,
    required String newStatus,
    required String userId,
    String? fromStatus,
  }) async {
    final nowIso = DateTime.now().toUtc().toIso8601String();

    final data = <String, dynamic>{'status': newStatus};

    switch (newStatus) {
      case 'NOTICED':
        data['noticed_at'] = nowIso;
        data['noticed_by_id'] = userId;
        break;
      case 'IN_PROGRESS':
        data['in_progress_at'] = nowIso;
        data['in_progress_by_id'] = userId;
        break;
      case 'SOLVED':
        data['solved_at'] = nowIso;
        data['solved_by_id'] = userId;
        break;
      case 'CLOSED':
        data['closed_at'] = nowIso;
        data['closed_by_id'] = userId;
        break;
    }

    await _client.from('andon_issues').update(data).eq('id', issueId);

    // Optional: history table
    await _client.from('andon_issue_status_history').insert({
      'issue_id': issueId,
      'changed_by_id': userId,
      'from_status': fromStatus,
      'to_status': newStatus,
    });
  }

  Future<List<AndonComment>> fetchComments(String issueId) async {
    final resp = await _client
        .from('andon_issue_comments')
        .select()
        .eq('issue_id', issueId)
        .order('created_at', ascending: true);

    final list = (resp as List).cast<Map<String, dynamic>>();
    return list.map((m) => AndonComment.fromMap(m)).toList();
  }

  Future<void> addComment({
    required String issueId,
    required String userId,
    String? userName,
    required String text,
    List<String> mentionedUserIds = const [],
    String? issueTitle,
  }) async {
    final commentResp =
        await _client
            .from('andon_issue_comments')
            .insert({
              'issue_id': issueId,
              'user_id': userId,
              'user_name': userName,
              'comment_text': text,
            })
            .select('id')
            .single();

    final commentId = commentResp['id']?.toString();
    final targetUserIds =
        mentionedUserIds
            .where((id) => id.trim().isNotEmpty && id != userId)
            .map((id) => id.trim())
            .toSet()
            .toList();

    if (commentId == null || targetUserIds.isEmpty) return;

    try {
      await _insertCommentMentions(
        commentId: commentId,
        issueId: issueId,
        mentionedUserIds: targetUserIds,
      );
    } catch (_) {
      // Mention push notifications should still be sent if the optional
      // mention history table has not been deployed yet.
    }

    await _sendMentionNotifications(
      mentionedUserIds: targetUserIds,
      senderName: userName ?? userId,
      issueTitle: issueTitle,
      commentText: text,
    );
  }

  Future<List<AndonMentionUser>> fetchMentionableUsers() async {
    final resp = await _client
        .from('USERS')
        .select('org_id, name, dept, designation')
        .order('name', ascending: true);

    final list = (resp as List).cast<Map<String, dynamic>>();
    return list
        .map(AndonMentionUser.fromMap)
        .where((user) => user.orgId.isNotEmpty)
        .toList();
  }

  Future<void> _insertCommentMentions({
    required String commentId,
    required String issueId,
    required List<String> mentionedUserIds,
  }) async {
    final users = await _client
        .from('USERS')
        .select('org_id, name')
        .inFilter('org_id', mentionedUserIds);

    final nameById = <String, String?>{};
    for (final map in users) {
      final orgId = map['org_id']?.toString();
      if (orgId != null) {
        nameById[orgId] = map['name']?.toString();
      }
    }

    final rows =
        mentionedUserIds
            .map(
              (id) => {
                'comment_id': commentId,
                'issue_id': issueId,
                'mentioned_user_id': id,
                'mentioned_user_name': nameById[id],
              },
            )
            .toList();

    await _client
        .from('andon_comment_mentions')
        .upsert(rows, onConflict: 'comment_id,mentioned_user_id');
  }

  Future<void> _sendMentionNotifications({
    required List<String> mentionedUserIds,
    required String senderName,
    required String? issueTitle,
    required String commentText,
  }) async {
    final tokenResp = await _client
        .from('device_token')
        .select('user_id, token')
        .inFilter('user_id', mentionedUserIds);

    final title = 'You were mentioned in Andon';
    final issuePart =
        issueTitle == null || issueTitle.trim().isEmpty
            ? 'an Andon issue'
            : issueTitle.trim();
    final shortComment =
        commentText.length > 80
            ? '${commentText.substring(0, 77)}...'
            : commentText;
    final body = '$senderName mentioned you on $issuePart: $shortComment';

    for (final row in tokenResp) {
      final token = row['token']?.toString();
      if (token == null || token.isEmpty) continue;

      try {
        await PushNotificationService.sendPushNotification(
          deviceToken: token,
          title: title,
          body: body,
        );
      } catch (_) {
        // Keep the comment saved even if one user's push delivery fails.
      }
    }
  }

  Future<List<AndonIssue>> fetchIssuesFiltered({
    required DateTime date,
    String? responsibleDept, // optional
  }) async {
    final startLocal = DateTime(date.year, date.month, date.day);
    final endLocal = startLocal.add(const Duration(days: 1));

    final startUtc = startLocal.toUtc();
    final endUtc = endLocal.toUtc();

    var query = _client
        .from('andon_issues')
        .select() // <-- MUST COME FIRST
        .eq('is_active', true);

    // Now these work:
    query = query
        .gte('created_at', startUtc.toIso8601String())
        .lt('created_at', endUtc.toIso8601String());

    if (responsibleDept != null && responsibleDept.isNotEmpty) {
      query = query.eq('responsible_dept', responsibleDept);
    }

    final resp = await query.select().order('created_at', ascending: false);

    final list = (resp as List).cast<Map<String, dynamic>>();
    return list.map((m) => AndonIssue.fromMap(m)).toList();
  }
}
