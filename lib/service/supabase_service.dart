// lib/services/supabase_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/sales_order_model.dart';

Future<List<SalesOrder>> fetchSalesOrdersFromSupabase() async {
  final client = Supabase.instance.client;
  final response = await client.from('Sales_Order_Data').select();
  return response.map((data) => SalesOrder.fromMap(data)).toList();
}
