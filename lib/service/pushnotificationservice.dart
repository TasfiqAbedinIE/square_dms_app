// final prefs = await SharedPreferences.getInstance();
// final userId = prefs.getString('userID') ?? '';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import 'package:flutter/material.dart'; // Add this

class PushNotificationService {
  static final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    try {
      FirebaseMessaging messaging = FirebaseMessaging.instance;

      // Request permission
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      print('🔔 Permission status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        final token = await messaging.getToken();
        print('📱 Device Token: $token');

        if (token != null) {
          // Schedule save AFTER app UI is rendered
          Future.delayed(Duration.zero, () => saveDeviceTokenToSupabase(token));
        }
      }

      // Set up local notifications
      const AndroidInitializationSettings androidInit =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const InitializationSettings initSettings = InitializationSettings(
        android: androidInit,
      );

      await _localNotificationsPlugin.initialize(initSettings);

      // Foreground notification handler
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print(
          '📩 Foreground message: ${message.notification?.title ?? "No Title"}',
        );
        showLocalNotification(message);
      });
    } catch (e) {
      print('❌ PushNotificationService initialization failed: $e');
    }
  }

  static void showLocalNotification(RemoteMessage message) async {
    final title = message.notification?.title ?? 'New Message';
    final body = message.notification?.body ?? 'You have a new notification.';

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'high_importance_channel',
          'High Importance Notifications',
          channelDescription:
              'This channel is used for important notifications.',
          importance: Importance.high,
          priority: Priority.high,
        );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
    );

    await _localNotificationsPlugin.show(
      message.hashCode,
      title,
      body,
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

