import 'dart:js_interop';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:web/web.dart' as web;

class ApiConfig {
  static const _storage = FlutterSecureStorage();
  static const _keyApiKey = 'api_key';
  static const _keyBaseUrl = 'base_url';
  static const _keyAiBaseUrl = 'ai_base_url';
  static const _keyImageApiKey = 'image_api_key';
  static const _keyImageBaseUrl = 'image_base_url';
  static const _keyWeatherApiKey = 'weather_api_key';
  static const _keySerperApiKey = 'serper_api_key';

  static const defaultBaseUrl = 'http://localhost:8000';

  /// 从 web/env.js 中读取 APP_CONFIG.API_BASE_URL
  static String _getEnvBaseUrl() {
    try {
      final config = (web.window as JSObject).getProperty('APP_CONFIG'.toJS);
      if (config != null && config.isA<JSObject>()) {
        final url = (config as JSObject).getProperty('API_BASE_URL'.toJS);
        if (url != null && url.isA<JSString>()) {
          return (url as JSString).toDart;
        }
      }
    } catch (_) {}
    return defaultBaseUrl;
  }

  static Future<String> getBaseUrl() async {
    final stored = await _storage.read(key: _keyBaseUrl);
    if (stored == null || stored == 'http://10.0.2.2:8000') return _getEnvBaseUrl();
    return stored;
  }
  static Future<void> setBaseUrl(String url) async => _storage.write(key: _keyBaseUrl, value: url);

  static Future<String?> getApiKey() async => _storage.read(key: _keyApiKey);
  static Future<void> setApiKey(String key) async => _storage.write(key: _keyApiKey, value: key);

  static Future<String?> getAiBaseUrl() async => _storage.read(key: _keyAiBaseUrl);
  static Future<void> setAiBaseUrl(String url) async => _storage.write(key: _keyAiBaseUrl, value: url);

  static Future<String?> getImageApiKey() async => _storage.read(key: _keyImageApiKey);
  static Future<void> setImageApiKey(String key) async => _storage.write(key: _keyImageApiKey, value: key);

  static Future<String?> getImageBaseUrl() async => _storage.read(key: _keyImageBaseUrl);
  static Future<void> setImageBaseUrl(String url) async => _storage.write(key: _keyImageBaseUrl, value: url);

  static Future<String?> getWeatherApiKey() async => _storage.read(key: _keyWeatherApiKey);
  static Future<void> setWeatherApiKey(String key) async => _storage.write(key: _keyWeatherApiKey, value: key);

  static Future<String?> getSerperApiKey() async => _storage.read(key: _keySerperApiKey);
  static Future<void> setSerperApiKey(String key) async => _storage.write(key: _keySerperApiKey, value: key);
}
