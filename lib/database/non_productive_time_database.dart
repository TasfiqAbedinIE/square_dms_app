import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:square_dms_trial/models/non_productive_time_model.dart';

class NonProductiveDB {
  static Future<Database> _openDB() async {
    return openDatabase(
      join(await getDatabasesPath(), 'NonProductive.db'),

      onCreate: (db, version) {
        return db.execute('''
          CREATE TABLE entries(
            id TEXT PRIMARY KEY,
            lineNo INTEGER,
            date TEXT,
            startTime TEXT,
            endTime TEXT,
            machine_num int,
            reason TEXT,
            durationMinutes int,
            totalNP int,
          )
        ''');
      },
      version: 1,
    );
  }

  static Future<void> insertEntry(NonProductiveEntry entry) async {
    final db = await _openDB();
    // db.execute('''ALTER TABLE entries ADD COLUMN totalNP INTEGER''');
    await db.insert(
      'entries',
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<NonProductiveEntry>> fetchEntries() async {
    final db = await _openDB();
    final List<Map<String, dynamic>> maps = await db.query('entries');
    return List.generate(
      maps.length,
      (i) => NonProductiveEntry.fromMap(maps[i]),
    );
  }

  static Future<void> deleteEntry(String id) async {
    final db = await _openDB();
    await db.delete('entries', where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> resetEntriesTable() async {
    final db = await _openDB();
    await db.execute('DROP TABLE IF EXISTS entries');
    await db.execute('''
    CREATE TABLE entries(
      id TEXT PRIMARY KEY,
      lineNo INTEGER,
      date TEXT,
      startTime TEXT,
      endTime TEXT,
      machine_num INTEGER,
      reason TEXT,
      durationMinutes INTEGER,
      totalNP INTEGER
    )
  ''');
  }
}
