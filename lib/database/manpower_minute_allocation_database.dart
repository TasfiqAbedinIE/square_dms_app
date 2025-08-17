import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class ManpowerMinuteAllocationDatabase {
  static final ManpowerMinuteAllocationDatabase instance =
      ManpowerMinuteAllocationDatabase._init();

  static Database? _database;

  ManpowerMinuteAllocationDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('manpower_minute_allocation.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE minute_allocation (
        id TEXT PRIMARY KEY,
        block TEXT,
        date TEXT,
        lineNo INTEGER,
        hrs8 INTEGER,
        hrs4to6 INTEGER,
        hrs6to8 INTEGER,
        hrs8to10 INTEGER,
        hrs10to12 INTEGER
      )
    ''');
  }

  Future<void> insertOrUpdate(Map<String, dynamic> data) async {
    final db = await instance.database;
    await db.insert(
      'minute_allocation',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> fetchByBlockAndDate(
    String block,
    String date,
  ) async {
    final db = await instance.database;
    return await db.query(
      'minute_allocation',
      where: 'block = ? AND date = ?',
      whereArgs: [block, date],
    );
  }

  Future<int> sumManpower(String block, String date) async {
    final db = await instance.database;
    final result = await db.rawQuery(
      '''
    SELECT SUM(hrs8) as total FROM minute_allocation 
    WHERE block = ? AND date = ?
  ''',
      [block, date],
    );

    final total = result.first['total'];
    return (total ?? 0) as int;
  }
}
