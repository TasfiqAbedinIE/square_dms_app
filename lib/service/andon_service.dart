// lib/services/andon_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/andon_issue_model.dart';

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
    return AndonIssue.fromMap(resp as Map<String, dynamic>);
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
  }) async {
    await _client.from('andon_issue_comments').insert({
      'issue_id': issueId,
      'user_id': userId,
      'user_name': userName,
      'comment_text': text,
    });
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
