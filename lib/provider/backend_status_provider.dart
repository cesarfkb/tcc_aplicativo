import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'server_config_provider.dart';

class BackendStatusProvider with ChangeNotifier {
  BackendStatusProvider({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  ServerConfigProvider? _serverConfig;

  Map<String, dynamic>? _statusPayload;
  Map<String, dynamic>? _latencyMetrics;
  bool _isStatusLoading = false;
  bool _isLatencyLoading = false;
  String? _statusError;
  String? _latencyError;

  Map<String, dynamic>? get statusPayload => _statusPayload;
  Map<String, dynamic>? get latencyMetrics => _latencyMetrics;
  bool get isStatusLoading => _isStatusLoading;
  bool get isLatencyLoading => _isLatencyLoading;
  String? get statusError => _statusError;
  String? get latencyError => _latencyError;

  bool get isConnected {
    final payload = _statusPayload;
    if (payload == null) return false;
    final connected = payload['connected'];
    if (connected is bool) return connected;
    final code = payload['code'];
    if (code is int && code == 200) return true;
    final status = payload['status'] ?? payload['state'];
    if (status is String) {
      final normalized = status.toLowerCase();
      return normalized == 'ok' ||
          normalized == 'online' ||
          normalized == 'connected' ||
          normalized == 'ready';
    }
    return false;
  }

  Uri? get snapshotUri => _serverConfig?.buildUri('/api/snapshot');

  Uri? get poseSnapshotUri => _serverConfig?.buildUri('/api/pose-snapshot');

  Uri? get latencyUri => _serverConfig?.buildUri('/api/latency');

  Uri? get statusUri => _serverConfig?.buildUri('/api/status');

  Uri? get eventsUri => _serverConfig?.buildUri('/api/events');

  Uri? get eventsNoImgUri => _serverConfig?.buildUri('/api/events/noimg');

  Uri? buildPaginatedEventsUri(
      {required int offset, int? limit, bool includeImages = true}) {
    final base = _serverConfig?.buildUri(
        includeImages ? '/api/events/$offset' : '/api/events/$offset/noimg');
    if (base == null) return null;
    if (limit == null) return base;
    return base.replace(queryParameters: {
      ...base.queryParameters,
      'limit': limit.toString(),
    });
  }

  void updateServerConfig(ServerConfigProvider config) {
    final shouldReload = _serverConfig?.baseUrl != config.baseUrl;
    _serverConfig = config;
    if (shouldReload) {
      refreshAll();
    }
  }

  Future<void> refreshAll() async {
    await Future.wait([
      fetchStatus(),
      fetchLatency(),
    ]);
  }

  Future<void> fetchStatus() async {
    final config = _serverConfig;
    if (config == null) return;
    final uri = config.buildUri('/api/status');
    _isStatusLoading = true;
    _statusError = null;
    notifyListeners();
    try {
      final response = await _client.get(uri);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        _statusPayload = _decodePayload(response.body);
        _statusPayload ??= {
          'status': response.body,
          'code': response.statusCode,
        };
      } else {
        _statusError =
            'HTTP ${response.statusCode}: ${response.reasonPhrase ?? 'Erro ao obter status'}';
      }
    } catch (error, stackTrace) {
      debugPrint('Erro ao buscar status: $error\n$stackTrace');
      _statusError = error.toString();
    } finally {
      _isStatusLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchLatency() async {
    final config = _serverConfig;
    if (config == null) return;
    final uri = config.buildUri('/api/latency');
    _isLatencyLoading = true;
    _latencyError = null;
    notifyListeners();
    try {
      final response = await _client.get(uri);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        _latencyMetrics = _decodePayload(response.body);
      } else {
        _latencyError =
            'HTTP ${response.statusCode}: ${response.reasonPhrase ?? 'Erro ao obter latência'}';
      }
    } catch (error, stackTrace) {
      debugPrint('Erro ao buscar latência: $error\n$stackTrace');
      _latencyError = error.toString();
    } finally {
      _isLatencyLoading = false;
      notifyListeners();
    }
  }

  Map<String, dynamic>? _decodePayload(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is List) {
        return {'data': decoded};
      }
      return {'data': decoded};
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }
}
