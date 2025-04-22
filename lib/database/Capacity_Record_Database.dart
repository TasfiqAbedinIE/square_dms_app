// import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/capacity_record_model.dart';

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
    // final file = File(path);
    // if (await file.exists()) {
    //   await file.delete(); // ⚠️ Only do this in dev/debug mode!
    // }

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
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
  }

  Future<void> insertRecord(CapacityRecord record) async {
    final db = await instance.database;
    await db.insert('capacity_records', record.toMap());
  }

  Future<List<CapacityRecord>> fetchRecords() async {
    final db = await instance.database;
    final result = await db.query('capacity_records');
    return result.map((e) => CapacityRecord.fromMap(e)).toList();
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
