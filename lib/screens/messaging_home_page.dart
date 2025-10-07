import 'dart:convert';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase_options.dart';

const _serverUrlPreferenceKey = 'messaging_server_base_url';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _ensureFirebaseInitialized();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  runApp(const MessagingApp());
}

class MessagingApp extends StatelessWidget {
  const MessagingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Firebase Messaging Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      home: const MessagingHomePage(),
    );
  }
}

Future<void> _ensureFirebaseInitialized() async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await _ensureFirebaseInitialized();
  debugPrint('Background message: ${message.messageId}');
}

class MessagingHomePage extends StatefulWidget {
  const MessagingHomePage({super.key});

  @override
  State<MessagingHomePage> createState() => _MessagingHomePageState();
}

class _MessagingHomePageState extends State<MessagingHomePage> {
  String? _token;
  AuthorizationStatus? _authorizationStatus;
  RemoteMessage? _lastForegroundMessage;
  RemoteMessage? _initialMessage;
  String? _registrationStatus;
  String? _serverBaseUrl;
  bool _isSavingServerUrl = false;
  bool _isInitializing = true;
  bool _isTestingConnection = false;
  String? _connectionTestResult;

  late final TextEditingController _serverUrlController;

  @override
  void initState() {
    super.initState();
    _serverUrlController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialize();
    });
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    await _loadServerBaseUrl();
    await _setupMessaging();
    if (mounted) {
      setState(() {
        _isInitializing = false;
      });
    }
  }

  Future<void> _loadServerBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final storedUrl = prefs.getString(_serverUrlPreferenceKey);
    final normalized = _normalizeBaseUrl(storedUrl ?? _defaultServerBaseUrl());

    if (!mounted) return;
    setState(() {
      _serverBaseUrl = normalized;
    });
    _serverUrlController.text = normalized;
  }

  Future<void> _setupMessaging() async {
    await _ensureFirebaseInitialized();
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
      setState(() {
        _token = newToken;
      });
      _registerTokenWithBackend(newToken);
    });

    FirebaseMessaging.onMessage.listen((message) {
      setState(() {
        _lastForegroundMessage = message;
      });
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      setState(() {
        _initialMessage = message;
      });
    });

    if (!mounted) return;
    setState(() {
      _authorizationStatus = settings.authorizationStatus;
      _token = token;
      _initialMessage = initialMessage ?? _initialMessage;
    });

    if (token != null && token.isNotEmpty) {
      await _registerTokenWithBackend(token);
    }
  }

  Future<void> _refreshToken() async {
    final messaging = FirebaseMessaging.instance;
    final newToken = await messaging.getToken();
    if (!mounted) return;
    setState(() {
      _token = newToken;
    });
    if (newToken != null && newToken.isNotEmpty) {
      await _registerTokenWithBackend(newToken);
    }
  }

  Future<void> _copyToken() async {
    if (_token == null || _token!.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _token!));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Token copiado para a área de transferência.'),
      ),
    );
  }

  Future<void> _registerTokenWithBackend(String token) async {
    final uri = _registerTokenEndpoint();

    try {
      if (mounted) {
        setState(() {
          _registrationStatus = 'Registrando token no backend (${uri.host})…';
        });
      }

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'token': token}),
      );

      if (!mounted) return;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        setState(() {
          _registrationStatus =
              'Token registrado (${response.statusCode}) em ${uri.host}.';
        });
      } else {
        setState(() {
          _registrationStatus =
              'Falha ao registrar (HTTP ${response.statusCode}): ${response.body}';
        });
      }
    } catch (error, stackTrace) {
      debugPrint('Erro ao registrar token: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _registrationStatus = 'Erro ao registrar token: $error';
      });
    }
  }

  Future<void> _saveServerUrl() async {
    final rawUrl = _serverUrlController.text.trim();
    final normalized = _normalizeBaseUrl(rawUrl);

    if (normalized.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe uma URL válida.')),
      );
      return;
    }

    final parsed = Uri.tryParse(normalized);
    final isValid =
        parsed != null && parsed.hasScheme && parsed.host.isNotEmpty;

    if (!isValid) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'URL inválida. Use o formato completo, por exemplo: http://10.0.2.2:8000'),
        ),
      );
      return;
    }

    setState(() {
      _isSavingServerUrl = true;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serverUrlPreferenceKey, normalized);

    if (!mounted) return;

    setState(() {
      _serverBaseUrl = normalized;
      _isSavingServerUrl = false;
      _registrationStatus = null;
      _connectionTestResult = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Servidor atualizado para $normalized')),
    );

    if ((_token ?? '').isNotEmpty) {
      await _registerTokenWithBackend(_token!);
    }
  }

  Future<void> _restoreDefaultServerUrl() async {
    final defaultUrl = _defaultServerBaseUrl();
    _serverUrlController.text = defaultUrl;
    await _saveServerUrl();
  }

  String _defaultServerBaseUrl() {
    const defaultPort = '8000';
    if (kIsWeb) {
      return 'http://localhost:$defaultPort';
    }
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:$defaultPort';
    }
    return 'http://localhost:$defaultPort';
  }

  Uri _registerTokenEndpoint() {
    const path = '/api/register-token';
    final base = _serverBaseUrl ?? _defaultServerBaseUrl();
    final normalized = _normalizeBaseUrl(base);
    return Uri.parse('$normalized$path');
  }

  String _normalizeBaseUrl(String? url) {
    final value = url?.trim() ?? '';
    if (value.isEmpty) return '';
    return value.endsWith('/') ? value.substring(0, value.length - 1) : value;
  }

  String _truncateToken(String token) {
    const visibleCharacters = 24;
    if (token.length <= visibleCharacters) {
      return token;
    }
    return '${token.substring(0, visibleCharacters)}…';
  }

  Future<void> _testServerConnection() async {
    final rawUrl = _serverUrlController.text.trim();
    final normalized = _normalizeBaseUrl(rawUrl);
    final uri = Uri.tryParse(normalized);

    final invalidUrl =
        normalized.isEmpty || uri == null || !uri.hasScheme || uri.host.isEmpty;

    if (invalidUrl) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe uma URL válida antes de testar a conexão.'),
        ),
      );
      return;
    }

    setState(() {
      _isTestingConnection = true;
      _connectionTestResult = 'Testando conexão com $normalized…';
    });

    try {
      final response = await http.get(uri);
      if (!mounted) return;
      setState(() {
        final success = response.statusCode >= 200 && response.statusCode < 300;
        final statusLabel = success ? 'sucesso' : 'falha';
        _connectionTestResult =
            'Resposta $statusLabel (HTTP ${response.statusCode}) de $normalized';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _connectionTestResult = 'Erro ao testar conexão: $error';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isTestingConnection = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Firebase Cloud Messaging'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.info_outline), text: 'Status'),
              Tab(icon: Icon(Icons.settings), text: 'Configuração'),
            ],
          ),
        ),
        body: _isInitializing
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildStatusTab(),
                  _buildConfigurationTab(),
                ],
              ),
      ),
    );
  }

  Widget _buildStatusTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildStatusCard(),
        const SizedBox(height: 16),
        _buildTokenCard(),
        if (_lastForegroundMessage != null) ...[
          const SizedBox(height: 16),
          _buildMessageCard(
            'Última mensagem em primeiro plano',
            _lastForegroundMessage!,
          ),
        ],
        if (_initialMessage != null) ...[
          const SizedBox(height: 16),
          _buildMessageCard('Mensagem que abriu o app', _initialMessage!),
        ],
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: _refreshToken,
              icon: const Icon(Icons.refresh),
              label: const Text('Atualizar token'),
            ),
            FilledButton.icon(
              onPressed: (_token ?? '').isEmpty ? null : _copyToken,
              icon: const Icon(Icons.copy),
              label: const Text('Copiar token'),
            ),
            FilledButton.icon(
              onPressed: (_token ?? '').isEmpty
                  ? null
                  : () => _registerTokenWithBackend(_token!),
              icon: const Icon(Icons.cloud_upload),
              label: const Text('Registrar novamente'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildConfigurationTab() {
    final registerUri = _registerTokenEndpoint();
    final base = _serverBaseUrl ?? _defaultServerBaseUrl();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Servidor da API',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _serverUrlController,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'Base URL do servidor',
              hintText: 'Ex.: http://10.0.2.2:8000',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _saveServerUrl(),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ElevatedButton.icon(
                onPressed: _isSavingServerUrl ? null : _saveServerUrl,
                icon: _isSavingServerUrl
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: const Text('Salvar'),
              ),
              OutlinedButton.icon(
                onPressed: _restoreDefaultServerUrl,
                icon: const Icon(Icons.restart_alt),
                label: const Text('Restaurar padrão'),
              ),
              OutlinedButton.icon(
                onPressed: _isTestingConnection ? null : _testServerConnection,
                icon: _isTestingConnection
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.wifi_tethering),
                label: const Text('Testar conexão'),
              ),
            ],
          ),
          if (_connectionTestResult != null) ...[
            const SizedBox(height: 12),
            Text(
              _connectionTestResult!,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Configuração atual',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text('Base URL: $base'),
                  Text('Endpoint de registro: $registerUri'),
                  if ((_token ?? '').isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Token atual: ${_truncateToken(_token!)}',
                    ),
                  ],
                  if (_registrationStatus != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _registrationStatus!,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Dica: use http://10.0.2.2 quando estiver testando em um emulador Android. '
            'Para dispositivos físicos, informe o IP da sua máquina na mesma rede.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    final status = _authorizationStatus;
    final statusLabel = switch (status) {
      AuthorizationStatus.denied => 'Negado',
      AuthorizationStatus.notDetermined => 'Não solicitado',
      AuthorizationStatus.provisional => 'Provisório',
      AuthorizationStatus.authorized => 'Autorizado',
      null => 'Verificando…',
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Permissão para notificações',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(statusLabel),
          ],
        ),
      ),
    );
  }

  Widget _buildTokenCard() {
    final token = _token;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'FCM token atual',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (token == null)
              const Text('Carregando token…')
            else if (token.isEmpty)
              const Text('Não foi possível obter o token.')
            else
              SelectableText(token),
            if (_registrationStatus != null) ...[
              const SizedBox(height: 12),
              Text(_registrationStatus!, style: const TextStyle(fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMessageCard(String title, RemoteMessage message) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (message.notification != null) ...[
              Text('Título: ${message.notification!.title ?? '-'}'),
              Text('Corpo: ${message.notification!.body ?? '-'}'),
              const SizedBox(height: 8),
            ],
            if (message.data.isNotEmpty) Text('Dados: ${message.data}'),
            Text('ID da mensagem: ${message.messageId ?? '-'}'),
          ],
        ),
      ),
    );
  }
}
