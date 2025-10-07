import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ServerConfigProvider with ChangeNotifier {
  static const _preferenceKey = 'server_base_url';

  ServerConfigProvider() {
    _baseUrl = _defaultBaseUrl();
    _loadFromStorage();
  }

  String? _baseUrl;
  bool _isPersisting = false;

  String get baseUrl => _baseUrl ?? _defaultBaseUrl();
  bool get isPersisting => _isPersisting;

  Future<void> updateBaseUrl(String rawUrl) async {
    final normalized = _normalizeBaseUrl(rawUrl);
    if (!_isValidBaseUrl(normalized)) {
      throw const FormatException('URL inválida');
    }
    _baseUrl = normalized;
    notifyListeners();
    await _persistBaseUrl(normalized!);
  }

  Future<void> restoreDefault() async {
    final defaultUrl = _defaultBaseUrl();
    _baseUrl = defaultUrl;
    notifyListeners();
    await _persistBaseUrl(defaultUrl);
  }

  Uri buildUri(String path) {
    final sanitizedPath = path.startsWith('/') ? path : '/$path';
    final base = Uri.parse(baseUrl);
    return base.resolve(sanitizedPath);
  }

  Future<void> _loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_preferenceKey);
    final normalized = _normalizeBaseUrl(stored);
    if (_isValidBaseUrl(normalized)) {
      _baseUrl = normalized;
      notifyListeners();
    }
  }

  Future<void> _persistBaseUrl(String url) async {
    _isPersisting = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_preferenceKey, url);
    _isPersisting = false;
    notifyListeners();
  }

  String _defaultBaseUrl() {
    const defaultPort = '8000';
    if (kIsWeb) {
      return 'http://localhost:$defaultPort';
    }
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:$defaultPort';
    }
    return 'http://localhost:$defaultPort';
  }

  String? _normalizeBaseUrl(String? value) {
    final url = value?.trim();
    if (url == null || url.isEmpty) {
      return null;
    }
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  bool _isValidBaseUrl(String? url) {
    if (url == null || url.isEmpty) {
      return false;
    }
    final uri = Uri.tryParse(url);
    return uri != null && uri.hasScheme && uri.host.isNotEmpty;
  }
}
