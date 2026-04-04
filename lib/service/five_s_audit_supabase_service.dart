import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:square_dms_trial/database/five_s_audit_database.dart';
import 'package:square_dms_trial/five_s_audit/models/five_s_models.dart';

class FiveSAuditSupabaseService {
  FiveSAuditSupabaseService._();

  static final FiveSAuditSupabaseService instance =
      FiveSAuditSupabaseService._();

  final SupabaseClient _client = Supabase.instance.client;

  Future<FiveSMasterSyncResult> syncMasterData() async {
    final departmentRows = await _client
        .from('five_s_departments')
        .select()
        .order('sort_order', ascending: true);
    final categoryRows = await _client
        .from('five_s_categories')
        .select()
        .order('sort_order', ascending: true);
    final criteriaRows = await _client
        .from('five_s_criteria')
        .select()
        .eq('is_active', true)
        .order('department_id', ascending: true)
        .order('sort_order', ascending: true);

    final syncedAt = DateTime.now().toIso8601String();
    final departments =
        departmentRows
            .map<FiveSDepartment>((row) => FiveSDepartment.fromMap(row))
            .toList();
    final categories =
        categoryRows
            .map<FiveSCategory>((row) => FiveSCategory.fromMap(row))
            .toList();
    final criteria =
        criteriaRows
            .map<FiveSCriterion>((row) => FiveSCriterion.fromMap(row))
            .toList();

    await FiveSAuditDatabase.instance.replaceMasterData(
      departments: departments,
      categories: categories,
      criteria: criteria,
      syncedAt: syncedAt,
    );

    return FiveSMasterSyncResult(
      departmentCount: departments.length,
      criteriaCount: criteria.length,
      categoryCount: categories.length,
      syncedAt: syncedAt,
    );
  }

  Future<FiveSUserContext> fetchCurrentUserContext() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userID') ?? '';
    if (userId.isEmpty) {
      return FiveSUserContext.empty();
    }

    final row =
        await _client
            .from('USERS')
            .select('working_area')
            .eq('org_id', userId)
            .maybeSingle();

    return FiveSUserContext.fromUserRow(userId, row);
  }

  Future<List<String>> fetchDepartmentLineOptions(
    FiveSDepartment department,
  ) async {
    if (!department.lineRequired) {
      return const <String>[];
    }

    final userContext = await fetchCurrentUserContext();
    if (userContext.isMasterUser) {
      return _allLineOptions();
    }

    final normalized = <String>{};
    for (final area in userContext.workingAreas) {
      normalized.addAll(_expandArea(area));
    }

    final sorted =
        normalized.toList()
          ..sort((a, b) => _lineNumber(a).compareTo(_lineNumber(b)));
    return sorted;
  }

  List<String> _allLineOptions() {
    return List<String>.generate(124, (index) => 'Line ${index + 1}');
  }

  List<String> _expandArea(String rawArea) {
    final trimmed = rawArea.trim();
    if (trimmed.isEmpty) {
      return const <String>[];
    }

    final numbers =
        RegExp(
          r'\d+',
        ).allMatches(trimmed).map((m) => int.parse(m.group(0)!)).toList();
    if (numbers.length >= 2) {
      final start = numbers.first;
      final end = numbers.last;
      return [for (int line = start; line <= end; line++) 'Line $line'];
    }
    if (numbers.length == 1) {
      return ['Line ${numbers.first}'];
    }
    return [trimmed];
  }

  int _lineNumber(String label) {
    final match = RegExp(r'\d+').firstMatch(label);
    if (match == null) {
      return 9999;
    }
    return int.tryParse(match.group(0)!) ?? 9999;
  }
}
