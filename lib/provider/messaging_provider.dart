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
  )   : _alertsProvider = alertsProvider,
        _serverConfig = serverConfig;

  AlertsProvider _alertsProvider;
  ServerConfigProvider _serverConfig;

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
  ) {
    _alertsProvider = alertsProvider;
    _serverConfig = serverConfig;
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
}
