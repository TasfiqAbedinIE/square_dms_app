// final prefs = await SharedPreferences.getInstance();
// final userId = prefs.getString('userID') ?? '';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart'; // Add this

class PushNotificationService {
  static final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // Request Notification Permission
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('✅ User granted permission');
      String? token = await messaging.getToken();
      print('📱 Device Token: $token');

      if (token != null) {
        await saveDeviceTokenToSupabase(token);
      }
    } else {
      print('❌ User declined notification permission');
    }

    // 🔥 Local Notification Setup
    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings(
          '@mipmap/ic_launcher',
        ); // Use your app icon

    const InitializationSettings initSettings = InitializationSettings(
      android: androidInit,
    );

    await _localNotificationsPlugin.initialize(initSettings);

    // Foreground messages: show local popup
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('📩 Foreground message received: ${message.notification?.title}');
      showLocalNotification(message);
    });
  }

  static void showLocalNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'high_importance_channel', // channel ID
          'High Importance Notifications', // channel name
          channelDescription:
              'This channel is used for important notifications.',
          importance: Importance.high,
          priority: Priority.high,
        );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
    );

    await _localNotificationsPlugin.show(
      message.notification.hashCode,
      message.notification?.title ?? 'No Title',
      message.notification?.body ?? 'No Body',
      platformDetails,
    );
  }

  static Future<void> saveDeviceTokenToSupabase(String token) async {
    final supabase = Supabase.instance.client;
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userID') ?? '';

    if (userId.isNotEmpty) {
      try {
        final response =
            await supabase
                .from('device_token')
                .upsert(
                  {
                    'user_id': userId,
                    'token': token,
                    'updated_at': DateTime.now().toUtc().toIso8601String(),
                  },
                  onConflict:
                      'user_id', // 💥 Force update existing if user_id matches
                )
                .select()
                .single();

        print('✅ Device token saved/updated for user: $response');
      } catch (e) {
        print('❌ Error saving token: $e');
      }
    } else {
      print('⚠️ No logged-in user found!');
    }
  }
}
