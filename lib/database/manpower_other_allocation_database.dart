import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class ManpowerOtherAllocationDatabase {
  static final ManpowerOtherAllocationDatabase instance =
      ManpowerOtherAllocationDatabase._init();

  static Database? _database;

  ManpowerOtherAllocationDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('manpower_other_allocation.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE manpower_other_allocation (
        id TEXT PRIMARY KEY,
        block TEXT NOT NULL,
        date TEXT NOT NULL,
        factor TEXT NOT NULL,
        count INTEGER,
        transferTo TEXT
      )
    ''');
  }

  Future<void> insertOrUpdateAllocation(Map<String, dynamic> data) async {
    final db = await instance.database;

    await db.insert(
      'manpower_other_allocation',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> fetchAllocations(
    String block,
    String date,
  ) async {
    final db = await instance.database;
    return await db.query(
      'manpower_other_allocation',
      where: 'block = ? AND date = ?',
      whereArgs: [block, date],
    );
  }

  Future<void> deleteAllocation(
    String block,
    String date,
    String factor,
  ) async {
    final db = await instance.database;
    await db.delete(
      'manpower_other_allocation',
      where: 'block = ? AND date = ? AND factor = ?',
      whereArgs: [block, date, factor],
    );
  }

  Future<int> sumManpower(String block, String date) async {
    final db = await instance.database;
    final result = await db.rawQuery(
      '''
    SELECT SUM(count) as total FROM manpower_other_allocation
    WHERE block = ? AND date = ?
  ''',
      [block, date],
    );

    final total = result.first['total'];
    return (total ?? 0) as int;
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
