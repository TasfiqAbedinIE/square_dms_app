import 'package:http/http.dart' as http;
import 'dart:convert';

class PushNotificationService {
  static Future<void> sendPushNotification({
    required String deviceToken,
    required String title,
    required String body,
  }) async {
    final url = Uri.parse(
      'https://xwmfquxefxkswpslzxhq.supabase.co/functions/v1/sendNotification',
    );

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'token': deviceToken, 'title': title, 'body': body}),
    );

    if (response.statusCode == 200) {
      print('✅ Notification sent successfully: ${response.body}');
    } else {
      print(
        '❌ Failed to send notification: ${response.statusCode} ${response.body}',
      );
    }
  }
}

