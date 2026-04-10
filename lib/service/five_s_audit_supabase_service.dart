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
    if (_isCuttingDepartment(department)) {
      return _cuttingTableOptions();
    }

    if (!department.lineRequired) {
      return const <String>[];
    }

    return _allLineOptions();
  }

  List<String> _allLineOptions() {
    return List<String>.generate(124, (index) => 'Line ${index + 1}');
  }

  List<String> _cuttingTableOptions() {
    return <String>[
      ...List<String>.generate(19, (index) => 'Table ${index + 1}'),
      'Y/D Section',
    ];
  }

  bool _isCuttingDepartment(FiveSDepartment department) {
    final departmentName = department.departmentName.toLowerCase();
    final areaType = (department.defaultAreaType ?? '').toLowerCase();
    return departmentName.contains('cutting') || areaType.contains('table');
  }
}
