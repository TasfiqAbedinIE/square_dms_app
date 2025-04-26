import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:square_dms_trial/pages/hourlyProductionScreen.dart';
import 'package:square_dms_trial/pages/homeScreen.dart';
import 'package:square_dms_trial/pages/adminScreen.dart';
import 'package:square_dms_trial/pages/ieScreen.dart';
import 'package:square_dms_trial/pages/skillMatrixScreen.dart';
import 'package:square_dms_trial/loginScreen.dart';
import 'package:square_dms_trial/service/connectivity_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = 'https://xwmfquxefxkswpslzxhq.supabase.co';
const supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh3bWZxdXhlZnhrc3dwc2x6eGhxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDQ3NjY0OTksImV4cCI6MjA2MDM0MjQ5OX0.IDpdZPlMojmzFDqC3Wt4QrvWtglORMRIy7xYIMmjzn8';

final connectivityService = ConnectivityService();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);

  final prefs = await SharedPreferences.getInstance();
  final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

  runApp(MyApp(isLoggedIn: isLoggedIn));
}

class MyApp extends StatefulWidget {
  final bool isLoggedIn;
  const MyApp({super.key, required this.isLoggedIn});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  bool _isOffline = false;

  @override
  void initState() {
    super.initState();

    connectivityService.connectivityStream.listen((isConnected) {
      if (!isConnected && !_isOffline) {
        _isOffline = true;
        _messengerKey.currentState?.showMaterialBanner(
          MaterialBanner(
            backgroundColor: Colors.red.shade400,
            content: const Text(
              'No internet connection',
              style: TextStyle(color: Colors.white),
            ),
            actions: const [
              SizedBox(), // just to avoid needing action buttons
            ],
          ),
        );
      } else if (isConnected && _isOffline) {
        _isOffline = false;
        _messengerKey.currentState?.clearMaterialBanners();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SQUARE DMS',
      theme: ThemeData(fontFamily: GoogleFonts.lexend().fontFamily),
      scaffoldMessengerKey: _messengerKey,
      initialRoute: widget.isLoggedIn ? '/home' : '/login',
      routes: {
        '/home': (context) => DashboardScreen(),
        '/IE': (context) => IEScreen(),
        '/admin': (context) => AdminPage(),
        '/login': (context) => const LoginScreen(),
        '/production': (context) => const HourlyProductionScreen(),
        '/skill_matrix': (context) => const SkillMatrixScreen(),
      },
    );
  }
}
