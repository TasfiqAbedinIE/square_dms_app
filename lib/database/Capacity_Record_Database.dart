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
      version: 1,
      onCreate: _createDB,
      onOpen: (db) async {
        // Ensure skillMatrixRecords table exists even if DB already created
        await db.execute('''
          CREATE TABLE IF NOT EXISTS skillMatrixRecords (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            referenceNumber TEXT,
            lineNumber INTEGER,
            buyer TEXT,
            salesDocument TEXT,
            style TEXT,
            item TEXT,
            layoutTarget INTEGER,
            date TEXT,
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
      },
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE capacity_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
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
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        referenceNumber TEXT,
        lineNumber INTEGER,
        buyer TEXT,
        salesDocument TEXT,
        style TEXT,
        item TEXT,
        layoutTarget INTEGER,
        date TEXT,
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

  Future<void> insertRecord(CapacityRecord record) async {
    final db = await instance.database;
    await db.insert('capacity_records', record.toMap());
  }

  Future<void> insertSkillMatrixRecord(SkillMatrixRecord record) async {
    final db = await instance.database;
    await db.insert('skillMatrixRecords', record.toMap());
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
