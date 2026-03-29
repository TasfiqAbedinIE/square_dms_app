import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'package:square_dms_trial/models/preproduction_record_model.dart';

class PreproductionRecordDatabase {
  static final PreproductionRecordDatabase instance =
      PreproductionRecordDatabase._init();

  static Database? _database;

  PreproductionRecordDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('PreproductionMeeting.db');
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
      CREATE TABLE IF NOT EXISTS preproduction_records (
        record_id TEXT PRIMARY KEY,
        user_id TEXT,
        sales_order TEXT NOT NULL,
        buyer_name TEXT NOT NULL,
        style TEXT NOT NULL,
        critical_to_quality TEXT,
        sync_status TEXT NOT NULL DEFAULT 'pending',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS preproduction_artwork_parts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        record_id TEXT NOT NULL,
        artwork_type TEXT NOT NULL,
        garment_part TEXT NOT NULL,
        UNIQUE(record_id, artwork_type, garment_part)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS preproduction_photos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        record_id TEXT NOT NULL,
        local_path TEXT NOT NULL,
        captured_at TEXT NOT NULL,
        photo_data_base64 TEXT,
        photo_size_bytes INTEGER NOT NULL DEFAULT 0,
        sync_status TEXT NOT NULL DEFAULT 'pending'
      )
    ''');

    await _ensureColumn(
      db,
      tableName: 'preproduction_records',
      columnName: 'user_id',
      columnDefinition: 'TEXT',
    );
    await _ensureColumn(
      db,
      tableName: 'preproduction_photos',
      columnName: 'photo_data_base64',
      columnDefinition: 'TEXT',
    );
    await _ensureColumn(
      db,
      tableName: 'preproduction_photos',
      columnName: 'photo_size_bytes',
      columnDefinition: 'INTEGER NOT NULL DEFAULT 0',
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

  Future<void> saveRecord(PreproductionRecord record) async {
    final db = await database;

    await db.transaction((txn) async {
      await txn.insert(
        'preproduction_records',
        record.toRecordMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      await txn.delete(
        'preproduction_artwork_parts',
        where: 'record_id = ?',
        whereArgs: [record.recordId],
      );
      await txn.delete(
        'preproduction_photos',
        where: 'record_id = ?',
        whereArgs: [record.recordId],
      );

      final artworkBatch = txn.batch();
      for (final selection in record.artworkSelections) {
        artworkBatch.insert(
          'preproduction_artwork_parts',
          selection.toMap(record.recordId),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      await artworkBatch.commit(noResult: true);

      final photoBatch = txn.batch();
      for (final photo in record.photos) {
        photoBatch.insert(
          'preproduction_photos',
          photo.toMap(record.recordId),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await photoBatch.commit(noResult: true);
    });
  }

  Future<PreproductionRecord?> fetchRecordById(String recordId) async {
    final db = await database;
    final records = await db.query(
      'preproduction_records',
      where: 'record_id = ?',
      whereArgs: [recordId],
      limit: 1,
    );

    if (records.isEmpty) return null;

    final artworkRows = await db.query(
      'preproduction_artwork_parts',
      where: 'record_id = ?',
      whereArgs: [recordId],
      orderBy: 'artwork_type, garment_part',
    );
    final photoRows = await db.query(
      'preproduction_photos',
      where: 'record_id = ?',
      whereArgs: [recordId],
      orderBy: 'captured_at ASC',
    );

    return PreproductionRecord.fromMap(
      map: records.first,
      artworkSelections:
          artworkRows
              .map((row) => PreproductionArtworkSelection.fromMap(row))
              .toList(),
      photos: photoRows.map((row) => PreproductionPhoto.fromMap(row)).toList(),
    );
  }

  Future<List<Map<String, dynamic>>> fetchRecordSummaries() async {
    final db = await database;
    return db.rawQuery('''
      SELECT
        r.record_id,
        r.user_id,
        r.sales_order,
        r.buyer_name,
        r.style,
        r.critical_to_quality,
        r.sync_status,
        r.created_at,
        r.updated_at,
        (
          SELECT COUNT(*)
          FROM preproduction_artwork_parts a
          WHERE a.record_id = r.record_id
        ) AS artwork_count,
        (
          SELECT COUNT(*)
          FROM preproduction_photos p
          WHERE p.record_id = r.record_id
        ) AS photo_count
      FROM preproduction_records r
      ORDER BY r.created_at DESC
    ''');
  }

  Future<int> pendingRecordCount() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT COUNT(*) AS total
      FROM preproduction_records
      WHERE sync_status = 'pending'
    ''');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> markRecordAsUploaded(String recordId) async {
    final db = await database;
    final timestamp = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      await txn.update(
        'preproduction_records',
        {'sync_status': 'uploaded', 'updated_at': timestamp},
        where: 'record_id = ?',
        whereArgs: [recordId],
      );

      await txn.update(
        'preproduction_photos',
        {'sync_status': 'uploaded'},
        where: 'record_id = ?',
        whereArgs: [recordId],
      );
    });
  }

  Future<void> deleteRecord(String recordId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(
        'preproduction_photos',
        where: 'record_id = ?',
        whereArgs: [recordId],
      );
      await txn.delete(
        'preproduction_artwork_parts',
        where: 'record_id = ?',
        whereArgs: [recordId],
      );
      await txn.delete(
        'preproduction_records',
        where: 'record_id = ?',
        whereArgs: [recordId],
      );
    });
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
