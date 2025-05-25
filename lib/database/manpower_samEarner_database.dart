import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class SamEarnerDatabase {
  static final SamEarnerDatabase instance = SamEarnerDatabase._init();

  static Database? _database;

  SamEarnerDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('manpower_optimization.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE sam_earner (
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
      'sam_earner',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
