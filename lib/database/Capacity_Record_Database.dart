import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/capacity_record_model.dart';
import '../models/skill_matrix_record_model.dart';

class CapacityRecordDatabase {
  static final CapacityRecordDatabase instance = CapacityRecordDatabase._init();
  static Database? _database;

  CapacityRecordDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('CapacityRecord.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
      onOpen: (db) async {
        // Ensure skillMatrixRecords table exists even if DB already created
        await db.execute('''
          CREATE TABLE IF NOT EXISTS skillMatrixRecords (
            id INTEGER PRIMARY KEY,
            referenceNumber TEXT,
            lineNumber INTEGER,
            buyer TEXT,
            salesDocument TEXT,
            style TEXT,
            item TEXT,
            layoutTarget INTEGER,
            date TEXT,
            processSequence INTEGER,
            operatorID TEXT,
            processName TEXT,
            machine TEXT,
            form TEXT,
            lapCount INTEGER,
            avgCycle REAL,
            capacityPH INTEGER,
            deptid TEXT
          )
        ''');
        await _ensureSkillMatrixSequenceColumn(db);
      },
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE capacity_records (
        id INTEGER PRIMARY KEY,
        referenceNumber TEXT,
        lineNumber INTEGER,
        buyer TEXT,
        salesDocument TEXT,
        style TEXT,
        item TEXT,
        layoutTarget INTEGER,
        date TEXT,
        deptid TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS skillMatrixRecords (
        id INTEGER PRIMARY KEY,
        referenceNumber TEXT,
        lineNumber INTEGER,
        buyer TEXT,
        salesDocument TEXT,
        style TEXT,
        item TEXT,
        layoutTarget INTEGER,
        date TEXT,
        processSequence INTEGER,
        operatorID TEXT,
        processName TEXT,
        machine TEXT,
        form TEXT,
        lapCount INTEGER,
        avgCycle REAL,
        capacityPH INTEGER,
        deptid TEXT
      )
    ''');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _ensureSkillMatrixSequenceColumn(db);
    }
  }

  Future<void> _ensureSkillMatrixSequenceColumn(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info(skillMatrixRecords)');
    final hasProcessSequence = columns.any(
      (column) => column['name'] == 'processSequence',
    );

    if (!hasProcessSequence) {
      await db.execute(
        'ALTER TABLE skillMatrixRecords ADD COLUMN processSequence INTEGER',
      );
    }

    await _backfillSkillMatrixSequences(db);
  }

  Future<void> _backfillSkillMatrixSequences(Database db) async {
    final missingSequenceRecords = await db.query(
      'skillMatrixRecords',
      columns: ['id', 'referenceNumber'],
      where: 'processSequence IS NULL OR processSequence = 0',
      orderBy: 'referenceNumber ASC, id ASC',
    );

    final nextSequenceByReference = <String, int>{};

    for (final row in missingSequenceRecords) {
      final referenceNumber = row['referenceNumber']?.toString() ?? '';
      final nextSequence =
          nextSequenceByReference[referenceNumber] ??
          await _getNextSkillMatrixSequence(db, referenceNumber);

      await db.update(
        'skillMatrixRecords',
        {'processSequence': nextSequence},
        where: 'id = ?',
        whereArgs: [row['id']],
      );

      nextSequenceByReference[referenceNumber] = nextSequence + 1;
    }
  }

  Future<void> insertRecord(CapacityRecord record) async {
    final db = await instance.database;
    await db.insert('capacity_records', record.toMap());
  }

  Future<void> insertSkillMatrixRecord(SkillMatrixRecord record) async {
    final db = await instance.database;
    await db.insert('skillMatrixRecords', record.toMap());
  }

  Future<int> getNextSkillMatrixSequence(String referenceNumber) async {
    final db = await instance.database;
    return _getNextSkillMatrixSequence(db, referenceNumber);
  }

  Future<int> _getNextSkillMatrixSequence(
    Database db,
    String referenceNumber,
  ) async {
    final result = await db.rawQuery(
      '''
      SELECT COALESCE(MAX(processSequence), 0) + 1 AS nextSequence
      FROM skillMatrixRecords
      WHERE referenceNumber = ?
      ''',
      [referenceNumber],
    );

    return (result.first['nextSequence'] as int?) ?? 1;
  }

  Future<List<CapacityRecord>> fetchRecords() async {
    final db = await instance.database;
    final result = await db.query('capacity_records');
    return result.map((e) => CapacityRecord.fromMap(e)).toList();
  }

  Future<List<SkillMatrixRecord>> fetchSkillMatrixRecords(
    String referenceNumber,
  ) async {
    final db = await instance.database;
    final result = await db.query(
      'skillMatrixRecords',
      where: 'referenceNumber = ?',
      whereArgs: [referenceNumber],
      orderBy: 'processSequence ASC, id ASC',
    );
    return result.map((map) => SkillMatrixRecord.fromMap(map)).toList();
  }

  Future<void> deleteDatabaseFile() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'CapacityRecord.db');
    final path1 = join(dbPath, 'skillMatrixRecords.db');
    await deleteDatabase(path);
    await deleteDatabase(path1);
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
