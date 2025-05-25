import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';

class SewingProductionModel {
  final String id;
  final int lineNumber;
  final String buyerName;
  final int so;
  final String daysRun;
  final String styleName;
  final String itemName;
  final double smv;
  final double hour;
  final String date;
  final double hourTNC;
  final int production;
  final int due;
  final double target10;
  final int manpower;
  final int rejection;
  final int without;
  final String remarks;
  final double hourMinusTNC;

  SewingProductionModel({
    required this.id,
    required this.lineNumber,
    required this.buyerName,
    required this.so,
    required this.daysRun,
    required this.styleName,
    required this.itemName,
    required this.smv,
    required this.hour,
    required this.date,
    required this.hourTNC,
    required this.production,
    required this.due,
    required this.target10,
    required this.manpower,
    required this.rejection,
    required this.without,
    required this.remarks,
    required this.hourMinusTNC,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'lineNumber': lineNumber,
    'buyerName': buyerName,
    'so': so,
    'daysRun': daysRun,
    'styleName': styleName,
    'itemName': itemName,
    'smv': smv,
    'hour': hour,
    'date': date,
    'hourTNC': hourTNC,
    'production': production,
    'due': due,
    'target10': target10,
    'manpower': manpower,
    'rejection': rejection,
    'without': without,
    'remarks': remarks,
    'hourMinusTNC': hourMinusTNC,
  };

  factory SewingProductionModel.fromJson(Map<String, dynamic> json) =>
      SewingProductionModel(
        id: json['id'],
        lineNumber: json['lineNumber'],
        buyerName: json['buyerName'],
        so: json['SO'],
        daysRun: json['daysRun'],
        styleName: json['styleName'],
        itemName: json['itemName'],
        smv: (json['SMV'] as num).toDouble(),
        hour: (json['hour'] as num).toDouble(),
        date: DateTime.parse(json['date']).toIso8601String().split('T')[0],
        hourTNC: (json['hourTNC'] as num).toDouble(),
        production: json['production'],
        due: json['due'],
        target10: (json['target10'] as num).toDouble(),
        manpower: json['manpower'],
        rejection: json['rejection'],
        without: json['without'],
        remarks: json['remarks'],
        hourMinusTNC: (json['hourMinusTNC'] as num).toDouble(),
      );
}

class SewingDatabaseService {
  static Database? _db;

  static Future<Database> get db async {
    if (_db != null) return _db!;
    return await _initDB();
  }

  static Future<Database> _initDB() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();

    final path = join(documentsDirectory.path, 'SewingProduction.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE sewing_production_data (
            id TEXT PRIMARY KEY,
            lineNumber INTEGER,
            buyerName TEXT,
            so INTEGER,
            daysRun TEXT,
            styleName TEXT,
            itemName TEXT,
            smv REAL,
            hour REAL,
            date TEXT,
            hourTNC REAL,
            production INTEGER,
            due INTEGER,
            target10 REAL,
            manpower INTEGER,
            rejection INTEGER,
            without INTEGER,
            remarks TEXT,
            hourMinusTNC REAL
          )
        ''');
      },
    );
  }

  static Future<void> ensureTableExists() async {
    final dbClient = await db;
    await dbClient.execute('''
    CREATE TABLE IF NOT EXISTS sewing_production_data (
      id TEXT PRIMARY KEY,
      lineNumber INTEGER,
      buyerName TEXT,
      so INTEGER,
      daysRun TEXT,
      styleName TEXT,
      itemName TEXT,
      smv REAL,
      hour REAL,
      date TEXT,
      hourTNC REAL,
      production INTEGER,
      due INTEGER,
      target10 REAL,
      manpower INTEGER,
      rejection INTEGER,
      without INTEGER,
      remarks TEXT,
      hourMinusTNC REAL
    )
  ''');
  }

  static Future<List<String>> getExistingDates() async {
    final dbClient = await db;
    await ensureTableExists();
    final result = await dbClient.rawQuery(
      'SELECT DISTINCT substr(date, 1, 10) as date FROM sewing_production_data',
    );
    return result.map((e) => e['date'] as String).toList();
  }

  static Future<void> insertBatch(List<SewingProductionModel> records) async {
    final dbClient = await db;
    // ------------------------------------------>
    // await dbClient.execute('DROP TABLE IF EXISTS sewing_production_data');

    final batch = dbClient.batch();
    for (final record in records) {
      batch.insert(
        'sewing_production_data',
        record.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
  }

  static Future<void> syncFromSupabaseForRange(DateTimeRange range) async {
    await ensureTableExists();
    final existingDates = await getExistingDates();

    // Create a list of all dates in the selected range as yyyy-MM-dd
    final List<String> dateList = [];
    DateTime d = range.start;
    while (!d.isAfter(range.end)) {
      dateList.add(d.toIso8601String().split('T')[0]);
      d = d.add(Duration(days: 1));
    }

    // Only keep the dates that are not in local db
    final List<String> datesToFetch =
        dateList.where((d) => !existingDates.contains(d)).toList();
    if (datesToFetch.isEmpty) {
      print('✅ All data already available locally for the selected range.');
      return;
    }

    // Fetch from Supabase where date in the list
    final List<Map<String, dynamic>> remoteData = await Supabase.instance.client
        .from('sewing_production_data')
        .select()
        .inFilter(
          'date',
          datesToFetch.map((d) => '${d}T00:00:00+00:00').toList(),
        );

    final newRecords =
        remoteData.map((e) => SewingProductionModel.fromJson(e)).toList();

    if (newRecords.isNotEmpty) {
      await insertBatch(newRecords);
      print('✅ Downloaded ${newRecords.length} new records');
    } else {
      print('✅ No new data found in Supabase for selected dates');
    }
  }

  static Future<Map<String, dynamic>> getProductionSummary(
    DateTimeRange range,
  ) async {
    final dbClient = await db;

    final start = range.start.toIso8601String().split('T')[0];
    final end = range.end.toIso8601String().split('T')[0];

    print('🔍 Summary Date Range: $start → $end');

    final rows = await dbClient.query(
      'sewing_production_data',
      where: 'substr(date, 1, 10) BETWEEN ? AND ?',
      whereArgs: [start, end],
    );

    print('Rows found: ${rows.length}');
    ///////
    int rowCount = await SewingDatabaseService.getRowCount();
    print('Total rows: $rowCount');
    String? date = await SewingDatabaseService.getFirstDate();
    print('First date in DB: $date');

    int totalProduction = 0;
    double totalTarget = 0;
    double availableMinutes = 0;
    double earnedMinutes = 0;
    double totalSMV = 0;
    int totalManpower = 0;

    int manpowerSum = 0;
    int manpowerCount = 0;

    for (final row in rows) {
      final without = (row['without'] as num?)?.toInt() ?? 0;
      final production = (row['production'] as num?)?.toInt() ?? 0;
      final rejection = (row['rejection'] as num?)?.toInt() ?? 0;
      final due = (row['due'] as num?)?.toInt() ?? 0;
      final target10 = (row['target10'] as num?)?.toDouble() ?? 0;
      final hourMinusTNC = (row['hourMinusTNC'] as num?)?.toDouble() ?? 0;
      final hourTNC = (row['hourTNC'] as num?)?.toDouble() ?? 0;
      final hour = (row['hour'] as num?)?.toDouble() ?? 0;
      final manpower = (row['manpower'] as num?)?.toInt() ?? 0;
      final smv = (row['smv'] as num?)?.toDouble() ?? 0;

      final thisProduction = without + production + rejection - due;
      final thisTarget = (target10 / 10.0) * hourMinusTNC;
      final thisAvailableMin = (hourTNC / 10.0) * hour * manpower * 60;

      totalProduction += thisProduction;
      totalTarget += thisTarget;
      availableMinutes += thisAvailableMin;
      earnedMinutes += thisProduction * smv;
      totalSMV += smv;
      manpowerSum += manpower;
      manpowerCount++;
    }

    final achievement =
        totalTarget > 0 ? (totalProduction / totalTarget * 100) : 0;
    final efficiency =
        availableMinutes > 0 ? (earnedMinutes / availableMinutes * 100) : 0;
    final avgSMV = totalProduction > 0 ? (earnedMinutes / totalProduction) : 0;
    double avgManpower = manpowerCount > 0 ? manpowerSum / 124 : 0;

    return {
      'Production': totalProduction,
      'Target': totalTarget.toInt(),
      'Achievement %': achievement.toInt(),
      'Manpower': avgManpower.round(),
      'Avg. SMV': avgSMV,
      'Efficiency %': efficiency.toDouble(),
    };
  }

  // helper finctions
  static Future<int> getRowCount() async {
    final dbClient = await db;
    final result = await dbClient.rawQuery(
      'SELECT COUNT(*) as count FROM sewing_production_data',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  static Future<String?> getFirstDate() async {
    final dbClient = await db;
    final result = await dbClient.rawQuery(
      'SELECT date FROM sewing_production_data LIMIT 1',
    );
    if (result.isNotEmpty) {
      return result.first['date'] as String?;
    }
    return null;
  }

  ////////
  static Future<List<Map<String, dynamic>>> getProductionTrend({
    int days = 15,
  }) async {
    final dbClient = await db;
    // SQLite query: group by date, order by date desc, limit 30
    final result = await dbClient.rawQuery(
      '''
    SELECT substr(date, 1, 10) as day, 
           SUM(without + production + rejection - due) as totalProduction
    FROM sewing_production_data
    GROUP BY day
    ORDER BY day DESC
    LIMIT ?
  ''',
      [days],
    );

    // Reverse so earliest date comes first for the chart
    return result.reversed.toList();
  }
}
