import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class ApiService {
  static Future<String> _baseUrl() => ApiConfig.getBaseUrl();

  static Future<Map<String, dynamic>> get(String path) async {
    final base = await _baseUrl();
    final res = await http.get(Uri.parse('$base$path'));
    return jsonDecode(res.body);
  }

  static Future<List<dynamic>> getList(String path) async {
    final base = await _baseUrl();
    final res = await http.get(Uri.parse('$base$path'));
    return jsonDecode(res.body);
  }

  static Future<Map<String, String>> _authHeaders() async {
    final key = await ApiConfig.getApiKey();
    return {
      'Content-Type': 'application/json',
      if (key != null && key.isNotEmpty) 'X-API-Key': key,
    };
  }

  static Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async {
    final base = await _baseUrl();
    final headers = await _authHeaders();
    final res = await http.post(
      Uri.parse('$base$path'),
      headers: headers,
      body: jsonEncode(body),
    );
    final decoded = jsonDecode(res.body);
    if (res.statusCode >= 400) {
      final detail = decoded is Map ? (decoded['detail'] ?? res.body) : res.body;
      throw Exception('$detail');
    }
    return decoded;
  }

  static Future<Map<String, dynamic>> put(String path, Map<String, dynamic> body) async {
    final base = await _baseUrl();
    final headers = await _authHeaders();
    final res = await http.put(
      Uri.parse('$base$path'),
      headers: headers,
      body: jsonEncode(body),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> postWithHeaders(
      String path, Map<String, dynamic> body,
      {Map<String, String> extraHeaders = const {}}) async {
    final base = await _baseUrl();
    final headers = await _authHeaders();
    headers.addAll(extraHeaders);
    final res = await http.post(
      Uri.parse('$base$path'),
      headers: headers,
      body: jsonEncode(body),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> delete(String path) async {
    final base = await _baseUrl();
    final res = await http.delete(Uri.parse('$base$path'));
    return jsonDecode(res.body);
  }
}
