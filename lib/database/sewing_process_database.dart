import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/sewing_process_model.dart';

class SewingProcessDatabase {
  static final SewingProcessDatabase instance = SewingProcessDatabase._init();
  static Database? _database;

  SewingProcessDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('sewing_process_database.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE sewing_process_data (
        process_name TEXT,
        item TEXT,
        machine TEXT,
        form TEXT,
        smv REAL
      )
    ''');
  }

  Future<void> insertProcesses(List<SewingProcess> processes) async {
    final db = await instance.database;
    final batch = db.batch();
    for (var process in processes) {
      batch.insert('sewing_process_data', process.toMap());
    }
    await batch.commit(noResult: true);
  }

  Future<List<SewingProcess>> fetchProcesses(Database db) async {
    final result = await db.query('sewing_process_data');
    return result.map((map) => SewingProcess.fromMap(map)).toList();
  }

  Future<void> deleteDatabaseFile() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'sewing_process_database.db');
    await deleteDatabase(path);
    _database = null;
  }
}
