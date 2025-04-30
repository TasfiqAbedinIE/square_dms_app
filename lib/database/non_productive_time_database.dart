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
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            lineNo INTEGER,
            date TEXT,
            startTime TEXT,
            endTime TEXT,
            machine_num int,
            reason TEXT
          )
        ''');
      },
      version: 1,
    );
  }

  static Future<void> insertEntry(NonProductiveEntry entry) async {
    final db = await _openDB();
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
}
