import 'package:shared_preferences/shared_preferences.dart';

const String defaultPreproductionApiBaseUrl = 'http://172.26.48.4:8000';
const String preproductionUploadEndpoint = '/preproduction-records';
const String _preproductionApiBaseUrlKey = 'preproduction_api_base_url';

class PreproductionServerConfig {
  static String normalizeBaseUrl(String value) {
    return value.trim().replaceAll(RegExp(r'/+$'), '');
  }

  static Future<String> getApiBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString(_preproductionApiBaseUrlKey);
    if (savedUrl == null || savedUrl.trim().isEmpty) {
      return defaultPreproductionApiBaseUrl;
    }
    return normalizeBaseUrl(savedUrl);
  }

  static Future<void> setApiBaseUrl(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_preproductionApiBaseUrlKey, normalizeBaseUrl(value));
  }
}
