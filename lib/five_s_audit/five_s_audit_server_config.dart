import 'package:shared_preferences/shared_preferences.dart';

const String defaultFiveSApiBaseUrl = 'http://172.26.48.4:8000';
const String fiveSUploadEndpoint = '/five-s-audits';
const String _fiveSApiBaseUrlKey = 'five_s_api_base_url';

class FiveSAuditServerConfig {
  static String normalizeBaseUrl(String value) {
    return value.trim().replaceAll(RegExp(r'/+$'), '');
  }

  static Future<String> getApiBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString(_fiveSApiBaseUrlKey);
    if (savedUrl == null || savedUrl.trim().isEmpty) {
      return defaultFiveSApiBaseUrl;
    }
    return normalizeBaseUrl(savedUrl);
  }

  static Future<void> setApiBaseUrl(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_fiveSApiBaseUrlKey, normalizeBaseUrl(value));
  }
}
