import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'package:square_dms_trial/five_s_audit/models/five_s_models.dart';

class FiveSAuditDatabase {
  static final FiveSAuditDatabase instance = FiveSAuditDatabase._init();

  static Database? _database;

  FiveSAuditDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('FiveSAudit.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);

    return openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
      onOpen: (db) async {
        await ensureTables(db);
      },
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await ensureTables(db);
  }

  Future<void> ensureTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS five_s_departments (
        department_id TEXT PRIMARY KEY,
        department_name TEXT NOT NULL,
        default_area_type TEXT,
        line_required INTEGER NOT NULL DEFAULT 0,
        sort_order INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS five_s_categories (
        code TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS five_s_criteria (
        criterion_id TEXT PRIMARY KEY,
        department_id TEXT NOT NULL,
        category_code TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT,
        max_score INTEGER NOT NULL DEFAULT 5,
        weight REAL NOT NULL DEFAULT 1,
        sort_order INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS five_s_audit_headers (
        audit_id TEXT PRIMARY KEY,
        department_id TEXT NOT NULL,
        department_name TEXT NOT NULL,
        area_line TEXT,
        audit_date TEXT NOT NULL,
        auditor_id TEXT,
        auditor_name TEXT,
        production_representative TEXT NOT NULL,
        signature_path TEXT NOT NULL,
        signature_base64 TEXT NOT NULL,
        total_score INTEGER NOT NULL,
        max_score INTEGER NOT NULL,
        percentage REAL NOT NULL,
        rating_band TEXT NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'pending',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        uploaded_at TEXT,
        remarks TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS five_s_audit_details (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        audit_id TEXT NOT NULL,
        criterion_id TEXT NOT NULL,
        category_code TEXT NOT NULL,
        criterion_title TEXT NOT NULL,
        max_score INTEGER NOT NULL,
        weight REAL NOT NULL DEFAULT 1,
        score INTEGER NOT NULL,
        issue_flag INTEGER NOT NULL DEFAULT 0,
        UNIQUE(audit_id, criterion_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS five_s_audit_photos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        audit_id TEXT NOT NULL,
        local_path TEXT NOT NULL,
        captured_at TEXT NOT NULL,
        photo_data_base64 TEXT NOT NULL,
        photo_size_bytes INTEGER NOT NULL DEFAULT 0,
        sync_status TEXT NOT NULL DEFAULT 'pending'
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS five_s_sync_meta (
        sync_key TEXT PRIMARY KEY,
        sync_value TEXT
      )
    ''');

    await _ensureColumn(
      db,
      tableName: 'five_s_audit_headers',
      columnName: 'uploaded_at',
      columnDefinition: 'TEXT',
    );
    await _ensureColumn(
      db,
      tableName: 'five_s_audit_headers',
      columnName: 'remarks',
      columnDefinition: 'TEXT',
    );
  }

  Future<void> _ensureColumn(
    Database db, {
    required String tableName,
    required String columnName,
    required String columnDefinition,
  }) async {
    final columns = await db.rawQuery('PRAGMA table_info($tableName)');
    final hasColumn = columns.any((row) => row['name'] == columnName);
    if (!hasColumn) {
      await db.execute(
        'ALTER TABLE $tableName ADD COLUMN $columnName $columnDefinition',
      );
    }
  }

  Future<void> replaceMasterData({
    required List<FiveSDepartment> departments,
    required List<FiveSCategory> categories,
    required List<FiveSCriterion> criteria,
    required String syncedAt,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('five_s_departments');
      await txn.delete('five_s_categories');
      await txn.delete('five_s_criteria');

      final departmentBatch = txn.batch();
      for (final department in departments) {
        departmentBatch.insert(
          'five_s_departments',
          department.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await departmentBatch.commit(noResult: true);

      final categoryBatch = txn.batch();
      for (final category in categories) {
        categoryBatch.insert(
          'five_s_categories',
          category.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await categoryBatch.commit(noResult: true);

      final criteriaBatch = txn.batch();
      for (final criterion in criteria) {
        criteriaBatch.insert(
          'five_s_criteria',
          criterion.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await criteriaBatch.commit(noResult: true);

      await txn.insert('five_s_sync_meta', {
        'sync_key': 'master_synced_at',
        'sync_value': syncedAt,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<String?> getLastMasterSyncAt() async {
    final db = await database;
    final rows = await db.query(
      'five_s_sync_meta',
      where: 'sync_key = ?',
      whereArgs: ['master_synced_at'],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['sync_value']?.toString();
  }

  Future<List<FiveSDepartment>> fetchDepartments() async {
    final db = await database;
    final rows = await db.query(
      'five_s_departments',
      orderBy: 'sort_order ASC, department_name ASC',
    );
    return rows.map(FiveSDepartment.fromMap).toList();
  }

  Future<List<FiveSCategory>> fetchCategories() async {
    final db = await database;
    final rows = await db.query(
      'five_s_categories',
      orderBy: 'sort_order ASC, name ASC',
    );
    return rows.map(FiveSCategory.fromMap).toList();
  }

  Future<List<FiveSCriterion>> fetchCriteriaByDepartment(
    String departmentId,
  ) async {
    final db = await database;
    final rows = await db.query(
      'five_s_criteria',
      where: 'department_id = ? AND is_active = 1',
      whereArgs: [departmentId],
      orderBy: 'sort_order ASC, title ASC',
    );
    return rows.map(FiveSCriterion.fromMap).toList();
  }

  Future<void> saveAuditRecord(FiveSAuditRecord record) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert(
        'five_s_audit_headers',
        record.toHeaderMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      await txn.delete(
        'five_s_audit_details',
        where: 'audit_id = ?',
        whereArgs: [record.auditId],
      );
      await txn.delete(
        'five_s_audit_photos',
        where: 'audit_id = ?',
        whereArgs: [record.auditId],
      );

      final detailBatch = txn.batch();
      for (final detail in record.details) {
        detailBatch.insert(
          'five_s_audit_details',
          detail.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await detailBatch.commit(noResult: true);

      final photoBatch = txn.batch();
      for (final photo in record.photos) {
        photoBatch.insert(
          'five_s_audit_photos',
          photo.toMap(record.auditId),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await photoBatch.commit(noResult: true);
    });
  }

  Future<FiveSAuditRecord?> fetchAuditById(String auditId) async {
    final db = await database;
    final headers = await db.query(
      'five_s_audit_headers',
      where: 'audit_id = ?',
      whereArgs: [auditId],
      limit: 1,
    );
    if (headers.isEmpty) return null;

    final details = await db.query(
      'five_s_audit_details',
      where: 'audit_id = ?',
      whereArgs: [auditId],
      orderBy: 'category_code ASC, id ASC',
    );
    final photos = await db.query(
      'five_s_audit_photos',
      where: 'audit_id = ?',
      whereArgs: [auditId],
      orderBy: 'captured_at ASC',
    );

    return FiveSAuditRecord.fromMap(
      map: headers.first,
      details: details.map(FiveSAuditDetail.fromMap).toList(),
      photos: photos.map(FiveSAuditPhoto.fromMap).toList(),
    );
  }

  Future<List<FiveSAuditSummary>> fetchAuditSummaries() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT
        h.audit_id,
        h.department_name,
        h.area_line,
        h.audit_date,
        h.auditor_name,
        h.production_representative,
        h.total_score,
        h.max_score,
        h.percentage,
        h.rating_band,
        h.sync_status,
        h.created_at,
        (
          SELECT COUNT(*)
          FROM five_s_audit_details d
          WHERE d.audit_id = h.audit_id AND d.issue_flag = 1
        ) AS issue_count,
        (
          SELECT COUNT(*)
          FROM five_s_audit_photos p
          WHERE p.audit_id = h.audit_id
        ) AS photo_count
      FROM five_s_audit_headers h
      ORDER BY h.created_at DESC
    ''');
    return rows.map(FiveSAuditSummary.fromMap).toList();
  }

  Future<void> markAuditAsUploaded(String auditId) async {
    final db = await database;
    final timestamp = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      await txn.update(
        'five_s_audit_headers',
        {
          'sync_status': 'uploaded',
          'updated_at': timestamp,
          'uploaded_at': timestamp,
        },
        where: 'audit_id = ?',
        whereArgs: [auditId],
      );
      await txn.update(
        'five_s_audit_photos',
        {'sync_status': 'uploaded'},
        where: 'audit_id = ?',
        whereArgs: [auditId],
      );
    });
  }

  Future<void> deleteAudit(String auditId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(
        'five_s_audit_photos',
        where: 'audit_id = ?',
        whereArgs: [auditId],
      );
      await txn.delete(
        'five_s_audit_details',
        where: 'audit_id = ?',
        whereArgs: [auditId],
      );
      await txn.delete(
        'five_s_audit_headers',
        where: 'audit_id = ?',
        whereArgs: [auditId],
      );
    });
  }
}
