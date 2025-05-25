import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:square_dms_trial/pages/aboutScreen.dart';
import 'package:square_dms_trial/pages/hourlyProductionScreen.dart';
import 'package:square_dms_trial/pages/homeScreen.dart';
import 'package:square_dms_trial/pages/adminScreen.dart';
import 'package:square_dms_trial/pages/ieScreen.dart';
import 'package:square_dms_trial/pages/skillMatrixScreen.dart';
import 'package:square_dms_trial/pages/profileScreen.dart';
import 'package:square_dms_trial/pages/processVideoScreen.dart';
import 'package:square_dms_trial/pages/manpowerOptScreen.dart';

import 'package:square_dms_trial/loginScreen.dart';
import 'package:square_dms_trial/service/connectivity_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:square_dms_trial/service/pushnotificationservice.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:square_dms_trial/subPages/NonProductiveTimePage.dart';

const supabaseUrl = 'https://xwmfquxefxkswpslzxhq.supabase.co';
const supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh3bWZxdXhlZnhrc3dwc2x6eGhxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDQ3NjY0OTksImV4cCI6MjA2MDM0MjQ5OX0.IDpdZPlMojmzFDqC3Wt4QrvWtglORMRIy7xYIMmjzn8';

final connectivityService = ConnectivityService();

@pragma('vm:entry-point') // Needed for background handling!
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('🔥 Background message received: ${message.notification?.title}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  await Firebase.initializeApp();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // await requestNotificationPermission();
  await PushNotificationService.initialize();

  final prefs = await SharedPreferences.getInstance();
  final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

  FirebaseMessaging messaging = FirebaseMessaging.instance;

  final token = await messaging.getToken();
  print('📱 Device Token: $token');

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
  String userID = '';

  Future<void> loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userID = prefs.getString('userID') ?? '';
      print(userID);
      // authority = prefs.getString('authority') ?? '';
    });
  }

  @override
  void initState() {
    super.initState();
    loadUserInfo();

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
        '/profile': (context) => ProfileScreen(),
        '/about': (context) => AboutScreen(),
        '/nonProductive': (context) => NonProductiveTimeScreen(),
        '/processVideo': (context) => VideoViewerScreen(),
        '/manpowerOpt': (context) => ManpowerOptimizationScreen(),
      },
    );
  }
}
