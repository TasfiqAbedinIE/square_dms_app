import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:square_dms_trial/models/non_productive_time_line_model.dart';

class NonProductiveTimeLineDB {
  static const _dbName = 'NonProductiveLine.db';
  static const _tableName = 'non_productive_time_line';
  static const _dbVersion = 1;

  /// Open (and create if necessary) the database, returning a Database instance.
  static Future<Database> _openDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_tableName (
            id TEXT PRIMARY KEY,
            lineNo INTEGER NOT NULL,
            date TEXT NOT NULL,
            buyer TEXT NOT NULL,
            soNumber TEXT NOT NULL,
            style TEXT NOT NULL
          )
        ''');
      },
    );
  }

  /// Inserts a new card. If a row with the same id already exists, it is replaced.
  static Future<void> insertCard(NonProductiveTimeLineCard card) async {
    final db = await _openDB();
    await db.insert(
      _tableName,
      card.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await db.close();
  }

  /// Returns all cards for the given [date] (yyyy-MM-dd).
  static Future<List<NonProductiveTimeLineCard>> fetchCardsByDate(
    String date,
  ) async {
    final db = await _openDB();
    final rows = await db.query(
      _tableName,
      where: 'date = ?',
      whereArgs: [date],
      orderBy: 'lineNo ASC',
    );
    await db.close();
    return rows.map((row) => NonProductiveTimeLineCard.fromMap(row)).toList();
  }

  /// Deletes the card with the given [id].
  static Future<void> deleteCard(String id) async {
    final db = await _openDB();
    await db.delete(_tableName, where: 'id = ?', whereArgs: [id]);
    await db.close();
  }

  /// Deletes all cards for the given [date] (if you ever need to clear a day).
  static Future<void> clearCardsForDate(String date) async {
    final db = await _openDB();
    await db.delete(_tableName, where: 'date = ?', whereArgs: [date]);
    await db.close();
  }
}
