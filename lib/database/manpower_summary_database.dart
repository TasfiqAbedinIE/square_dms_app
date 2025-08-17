import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class ManpowerSummaryDatabase {
  static final ManpowerSummaryDatabase instance =
      ManpowerSummaryDatabase._init();
  static Database? _database;

  ManpowerSummaryDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    final path = join(await getDatabasesPath(), 'manpower_summary.db');
    _database = await openDatabase(path, version: 1, onCreate: _createDB);
    return _database!;
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE summary (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT,
        block TEXT,
        total_present INTEGER
      )
    ''');
  }

  Future<void> insertSummary(
    String date,
    String block,
    int totalPresent,
  ) async {
    final db = await instance.database;
    await db.insert('summary', {
      'date': date,
      'block': block,
      'total_present': totalPresent,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int?> fetchTotalPresent(String date, String block) async {
    final db = await instance.database;
    final result = await db.query(
      'summary',
      where: 'date = ? AND block = ?',
      whereArgs: [date, block],
      limit: 1,
    );

    if (result.isNotEmpty) {
      return result.first['total_present'] as int;
    }
    return null;
  }
}
