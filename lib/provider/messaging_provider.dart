import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'alerts_provider.dart';
import 'server_config_provider.dart';

class MessagingProvider with ChangeNotifier {
  MessagingProvider(
    AlertsProvider alertsProvider,
    ServerConfigProvider serverConfig,
    GlobalKey<ScaffoldMessengerState>? messengerKey,
  )   : _alertsProvider = alertsProvider,
        _serverConfig = serverConfig,
        _messengerKey = messengerKey;

  AlertsProvider _alertsProvider;
  ServerConfigProvider _serverConfig;
  GlobalKey<ScaffoldMessengerState>? _messengerKey;

  AuthorizationStatus? _authorizationStatus;
  String? _token;
  RemoteMessage? _lastForegroundMessage;
  RemoteMessage? _initialMessage;
  String? _registrationStatus;
  bool _isInitializing = false;
  bool _isRegistering = false;

  AuthorizationStatus? get authorizationStatus => _authorizationStatus;
  String? get token => _token;
  RemoteMessage? get lastForegroundMessage => _lastForegroundMessage;
  RemoteMessage? get initialMessage => _initialMessage;
  String? get registrationStatus => _registrationStatus;
  bool get isInitializing => _isInitializing;
  bool get isRegistering => _isRegistering;

  void updateDependencies(
    AlertsProvider alertsProvider,
    ServerConfigProvider serverConfig,
    {GlobalKey<ScaffoldMessengerState>? messengerKey}) {
    _alertsProvider = alertsProvider;
    _serverConfig = serverConfig;
    _messengerKey = messengerKey ?? _messengerKey;
  }

  Future<void> ensureInitialized() async {
    if (_isInitializing || _authorizationStatus != null) {
      return;
    }
    _isInitializing = true;
    notifyListeners();

    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
      carPlay: false,
      criticalAlert: false,
      announcement: false,
    );

    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    final token = await messaging.getToken();
    final initialMessage = await messaging.getInitialMessage();

    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      _token = newToken;
      notifyListeners();
      _registerTokenWithBackend(newToken);
    });

    FirebaseMessaging.onMessage.listen((message) {
      _lastForegroundMessage = message;
      notifyListeners();
      _alertsProvider.addAlert({
        'title': message.notification?.title ?? 'Notificação recebida',
        'description': message.notification?.body ?? 'Sem conteúdo',
        'type': message.data['type'] ?? 'Info',
        'date': DateTime.now(),
      });
      _showInAppNotification(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _initialMessage = message;
      notifyListeners();
    });

    _authorizationStatus = settings.authorizationStatus;
    _token = token;
    _initialMessage = initialMessage ?? _initialMessage;
    _isInitializing = false;
    notifyListeners();

    if (token != null && token.isNotEmpty) {
      await _registerTokenWithBackend(token);
    }
  }

  Future<void> refreshToken() async {
    final messaging = FirebaseMessaging.instance;
    final newToken = await messaging.getToken();
    _token = newToken;
    notifyListeners();
    if (newToken != null && newToken.isNotEmpty) {
      await _registerTokenWithBackend(newToken);
    }
  }

  Future<void> copyTokenToClipboard(BuildContext context) async {
    final currentToken = _token;
    if (currentToken == null || currentToken.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: currentToken));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Token copiado para a área de transferência.'),
        ),
      );
    }
  }

  Future<void> reRegisterToken() async {
    final currentToken = _token;
    if (currentToken == null || currentToken.isEmpty) return;
    await _registerTokenWithBackend(currentToken);
  }

  Future<void> _registerTokenWithBackend(String token) async {
    final uri = _serverConfig.buildUri('/api/register-token');

    try {
      _isRegistering = true;
      _registrationStatus = 'Registrando token em ${uri.host}…';
      notifyListeners();

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'token': token}),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _registrationStatus =
            'Token registrado com sucesso (${response.statusCode}).';
      } else {
        _registrationStatus =
            'Falha ao registrar (HTTP ${response.statusCode}): ${response.body}';
      }
    } catch (error, stackTrace) {
      debugPrint('Erro ao registrar token: $error\n$stackTrace');
      _registrationStatus = 'Erro ao registrar token: $error';
    } finally {
      _isRegistering = false;
      notifyListeners();
    }
  }

  void _showInAppNotification(RemoteMessage message) {
    ScaffoldMessengerState? messenger = _messengerKey?.currentState;
    messenger ??= _messengerKey?.currentContext != null
        ? ScaffoldMessenger.maybeOf(_messengerKey!.currentContext!)
        : null;
    if (messenger == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showInAppNotification(message);
      });
      return;
    }
    final severity = _resolveSeverity(message);
    final title = message.notification?.title ??
        message.data['title'] ??
        message.data['type'] ??
        'Nova notificacao';
    final body =
        message.notification?.body ?? message.data['description'] ?? '';
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.white,
          margin: const EdgeInsets.all(12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: severity.color, width: 1.5),
          ),
          duration: severity.duration,
          content: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(severity.icon, color: severity.color, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (severity.label.isNotEmpty)
                      Text(
                      '${severity.label} • $title',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                    if (severity.label.isEmpty)
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                    if (body.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          body,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
  }

  _InAppSeverity _resolveSeverity(RemoteMessage message) {
    final level =
        (message.data['level'] ?? message.data['severity'] ?? '').toString().toLowerCase();
    final type = (message.data['type'] ?? '').toString().toLowerCase();

    switch (level) {
      case 'urgente':
      case 'urgent':
      case 'critical':
        return _InAppSeverity.urgent();
      case 'importante':
      case 'important':
      case 'warning':
        return _InAppSeverity.important();
      case 'leve':
      case 'low':
      case 'minor':
        return _InAppSeverity.light();
      case 'info':
      case 'informativo':
        return _InAppSeverity.info();
    }

    const urgentTypes = {
      'posture_face_covered',
      'posture_prone',
    };
    const importantTypes = {
      'camera_disconnected',
      'absence',
      'posture_absent',
      'posture_side',
    };

    if (urgentTypes.contains(type)) return _InAppSeverity.urgent();
    if (importantTypes.contains(type)) return _InAppSeverity.important();
    return _InAppSeverity.info();
  }
}

class _InAppSeverity {
  final String label;
  final Color color;
  final IconData icon;
  final Duration duration;

  const _InAppSeverity({
    required this.label,
    required this.color,
    required this.icon,
    required this.duration,
  });

  factory _InAppSeverity.urgent() => const _InAppSeverity(
        label: 'Urgente',
        color: Colors.red,
        icon: Icons.priority_high,
        duration: Duration(seconds: 8),
      );

  factory _InAppSeverity.important() => const _InAppSeverity(
        label: 'Importante',
        color: Colors.orange,
        icon: Icons.report,
        duration: Duration(seconds: 6),
      );

  factory _InAppSeverity.light() => const _InAppSeverity(
        label: 'Leve',
        color: Colors.blueAccent,
        icon: Icons.info_outline,
        duration: Duration(seconds: 4),
      );

  factory _InAppSeverity.info() => const _InAppSeverity(
        label: '',
        color: Colors.blueGrey,
        icon: Icons.notifications,
        duration: Duration(seconds: 4),
      );
}
