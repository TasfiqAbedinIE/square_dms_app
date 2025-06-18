import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:square_dms_trial/models/non_productive_time_model.dart';

class NonProductiveDB {
  static Future<Database> openDB() async {
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
            totalLostPcs DOUBLE,
            machine_code TEXT,
            deptid TEXT,
            res_dept TEXT
          )
        ''');
      },
      version: 1,
      onOpen: (db) async {
        // 1) Inspect the schema for 'entries'
        final info = await db.rawQuery("PRAGMA table_info('entries');");
        final hasResDept = info.any((row) => row['name'] == 'res_dept');

        if (!hasResDept) {
          // 2) If missing, add it (new columns default to NULL)
          await db.execute("ALTER TABLE entries ADD COLUMN res_dept TEXT;");
        }
      },
    );
  }

  static Future<void> insertEntry(NonProductiveEntry entry) async {
    final db = await openDB();
    // db.execute('''ALTER TABLE entries ADD COLUMN deptid TEXT''');
    await db.insert(
      'entries',
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<NonProductiveEntry>> fetchEntries() async {
    final db = await openDB();
    final List<Map<String, dynamic>> maps = await db.query('entries');
    return List.generate(
      maps.length,
      (i) => NonProductiveEntry.fromMap(maps[i]),
    );
  }

  static Future<void> deleteEntry(String id) async {
    final db = await openDB();
    await db.delete('entries', where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> resetEntriesTable() async {
    final db = await openDB();
    // await db.execute('DROP TABLE IF EXISTS entries');
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
      totalNP INTEGER,
      totalLostPcs DOUBLE,
      machine_code TEXT,
      deptid TEXT,
      res_dept TEXT
    )
  ''');
  }

  static Future<void> updateEntry(NonProductiveEntry entry) async {
    final db = await openDB();
    await db.update(
      'entries',
      entry.toMap(),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
    await db.close();
  }
}
