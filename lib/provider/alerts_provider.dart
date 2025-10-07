import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'server_config_provider.dart';

class AlertsProvider with ChangeNotifier {
  AlertsProvider({http.Client? client}) : _client = client ?? http.Client();

  static const int _pageSize = 20;

  final http.Client _client;

  ServerConfigProvider? _serverConfig;

  List<Map<String, dynamic>> _alerts = [];
  List<Map<String, dynamic>> _summaryAlerts = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _isSummaryLoading = false;
  String? _error;
  String? _summaryError;
  int _offset = 0;
  bool _includeImages = true;

  List<Map<String, dynamic>> get alerts => _alerts;
  List<Map<String, dynamic>> get summaryAlerts => _summaryAlerts;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  bool get isSummaryLoading => _isSummaryLoading;
  String? get error => _error;
  String? get summaryError => _summaryError;
  bool get includeImages => _includeImages;

  void updateServerConfig(ServerConfigProvider config) {
    final shouldReload = _serverConfig?.baseUrl != config.baseUrl;
    _serverConfig = config;
    if (shouldReload) {
      fetchAlerts(reset: true);
    }
  }

  Future<void> fetchAlerts({
    bool reset = false,
    bool? includeImages,
  }) async {
    final config = _serverConfig;
    if (config == null) return;

    var effectiveReset = reset;
    if (includeImages != null && includeImages != _includeImages) {
      _includeImages = includeImages;
      effectiveReset = true;
    }

    if (effectiveReset) {
      if (_isLoading) return;
      _isLoading = true;
      _isLoadingMore = false;
      _error = null;
      _hasMore = true;
      _offset = 0;
      _alerts = [];
      notifyListeners();
    } else {
      if (!_hasMore || _isLoading || _isLoadingMore) return;
      _isLoadingMore = true;
      notifyListeners();
    }

    final offset = _offset;
    final uri = _buildEventsUri(config, offset, _pageSize, _includeImages);

    try {
      final response = await _client.get(uri);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final parsed = _parseEventsResponse(response.body);
        if (effectiveReset) {
          _alerts = parsed;
        } else {
          _alerts = [..._alerts, ...parsed];
        }
        _hasMore = parsed.length == _pageSize;
        _offset = _alerts.length;
      } else {
        _error =
            'HTTP ${response.statusCode}: ${response.reasonPhrase ?? 'Erro ao carregar eventos'}';
      }
    } catch (error, stackTrace) {
      debugPrint('Erro ao carregar eventos: $error\n$stackTrace');
      _error = error.toString();
    } finally {
      if (effectiveReset) {
        _isLoading = false;
      } else {
        _isLoadingMore = false;
      }
      notifyListeners();
    }
  }

  Future<void> loadMoreAlerts() => fetchAlerts();

  Future<void> fetchSummaryAlerts() async {
    final config = _serverConfig;
    if (config == null) return;
    _isSummaryLoading = true;
    _summaryError = null;
    notifyListeners();
    try {
      final uri = _buildEventsUri(config, 0, 3, false);
      final response = await _client.get(uri);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final parsed = _parseEventsResponse(response.body);
        _summaryAlerts = parsed.take(3).toList();
      } else {
        _summaryError =
            'HTTP ${response.statusCode}: ${response.reasonPhrase ?? 'Erro ao carregar eventos'}';
      }
    } catch (error, stackTrace) {
      debugPrint('Erro ao carregar eventos (resumo): $error\n$stackTrace');
      _summaryError = error.toString();
    } finally {
      _isSummaryLoading = false;
      notifyListeners();
    }
  }

  void addAlert(Map<String, dynamic> newAlert) {
    _alerts.insert(0, newAlert);
    notifyListeners();
  }

  List<Map<String, dynamic>> _parseEventsResponse(String body) {
    final decoded = jsonDecode(body);
    final List<dynamic> events;
    if (decoded is List) {
      events = decoded;
    } else if (decoded is Map<String, dynamic>) {
      final data = decoded['events'] ?? decoded['data'];
      if (data is List) {
        events = data;
      } else {
        events = [decoded];
      }
    } else {
      return _alerts;
    }

    final result = <Map<String, dynamic>>[];
    for (final item in events) {
      if (item is! Map<String, dynamic>) continue;
      result.add(_normalizeEvent(item));
    }
    return result;
  }

  Map<String, dynamic> _normalizeEvent(Map<String, dynamic> raw) {
    final normalized = Map<String, dynamic>.from(raw);
    normalized['title'] =
        raw['title'] ?? raw['event'] ?? raw['type'] ?? raw['label'] ?? 'Evento';
    normalized['description'] = raw['description'] ??
        raw['message'] ??
        raw['details'] ??
        raw['info'] ??
        '';
    normalized['type'] =
        (raw['type'] ?? raw['severity'] ?? raw['level'] ?? 'Info').toString();
    normalized['date'] = _extractDate(raw);
    if (!normalized.containsKey('id') && raw['uuid'] != null) {
      normalized['id'] = raw['uuid'];
    }
    return normalized;
  }

  DateTime _extractDate(Map<String, dynamic> raw) {
    final candidates = [
      raw['timestamp'],
      raw['date'],
      raw['time'],
      raw['created_at'],
      raw['updated_at'],
    ];

    for (final candidate in candidates) {
      if (candidate == null) continue;
      if (candidate is int) {
        // Try milliseconds, then seconds.
        if (candidate > 1000000000000) {
          return DateTime.fromMillisecondsSinceEpoch(candidate);
        }
        return DateTime.fromMillisecondsSinceEpoch(candidate * 1000);
      }
      if (candidate is String) {
        try {
          return DateTime.parse(candidate).toLocal();
        } catch (_) {
          // Try parse as int string.
          final maybeInt = int.tryParse(candidate);
          if (maybeInt != null) {
            if (maybeInt > 1000000000000) {
              return DateTime.fromMillisecondsSinceEpoch(maybeInt);
            }
            return DateTime.fromMillisecondsSinceEpoch(maybeInt * 1000);
          }
        }
      }
    }
    return DateTime.now();
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }

  Uri _buildEventsUri(
    ServerConfigProvider config,
    int offset,
    int limit,
    bool includeImages,
  ) {
    final basePath = offset <= 0
        ? (includeImages ? '/api/events' : '/api/events/noimg')
        : (includeImages ? '/api/events/$offset' : '/api/events/$offset/noimg');
    final uri = config.buildUri(basePath);
    return uri.replace(queryParameters: {
      ...uri.queryParameters,
      'limit': limit.toString(),
    });
  }
}
