import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/sales_order_model.dart';

class SalesOrderDatabase {
  static final SalesOrderDatabase instance = SalesOrderDatabase._init();
  static Database? _database;

  SalesOrderDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('Sales_Order.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE sales_order_data (
            id INTEGER PRIMARY KEY,
            buyerName TEXT,
            salesDocument INTEGER,
            style TEXT
          )
        ''');
      },
    );
  }

  Future<List<SalesOrder>> fetchAllSalesOrders(Database db) async {
    final result = await db.query('sales_order_data');
    return result
        .map((map) => SalesOrder.fromMap(map))
        .toList()
        .cast<SalesOrder>();
  }
}
