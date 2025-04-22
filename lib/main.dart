import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:square_dms_trial/pages/hourlyProductionScreen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:square_dms_trial/loginScreen.dart';
import 'package:square_dms_trial/pages/homeScreen.dart';
import 'package:square_dms_trial/pages/adminScreen.dart';
import 'package:square_dms_trial/pages/ieScreen.dart';
import 'package:square_dms_trial/service/connectivity_service.dart';
import 'package:square_dms_trial/pages/skillMatrixScreen.dart';

// import '../database/CapacityRecordDatabase.dart';
// import '../service/supabase_service.dart';
// import 'database/sales_order_database.dart';
// import 'models/sales_order_model.dart';

//Only for desktop or test purpose
// import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const supabaseUrl = 'https://xwmfquxefxkswpslzxhq.supabase.co';
const supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh3bWZxdXhlZnhrc3dwc2x6eGhxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDQ3NjY0OTksImV4cCI6MjA2MDM0MjQ5OX0.IDpdZPlMojmzFDqC3Wt4QrvWtglORMRIy7xYIMmjzn8';

final connectivityService = ConnectivityService();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  // syncSalesOrdersFromSupabase();

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  MyApp({super.key});

  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: connectivityService.connectivityStream,
      builder: (context, snapshot) {
        final isConnected = snapshot.data ?? true;

        if (!isConnected) {
          Future.microtask(() {
            _messengerKey.currentState?.showSnackBar(
              const SnackBar(
                content: Text('No Internet Connection!'),
                backgroundColor: Colors.red,
              ),
            );
          });
        }

        return MaterialApp(
          title: 'SQUARE DMS',
          theme: ThemeData(fontFamily: GoogleFonts.lexend().fontFamily),
          // initialRoute: '/home',
          scaffoldMessengerKey: _messengerKey,
          initialRoute: '/login',
          routes: {
            // Side Bar Routing
            '/home': (context) => const HomeScreen(),
            '/IE': (context) => IEScreen(),
            '/admin': (context) => AdminPage(),
            '/login': (context) => const LoginScreen(),

            // Sub Screen Routing
            '/production': (context) => const HourlyProductionScreen(),
            '/skill_matrix': (context) => const SkillMatrixScreen(),
          },
        );
      },
    );
  }
}
