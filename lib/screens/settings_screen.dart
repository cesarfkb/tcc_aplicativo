import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../provider/alerts_provider.dart';
import '../provider/messaging_provider.dart';
import '../provider/server_config_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _baseUrlController;
  bool _isTestingConnection = false;
  String? _connectionStatus;
  bool _initializedController = false;
  bool _initializedMessaging = false;

  @override
  void initState() {
    super.initState();
    _baseUrlController = TextEditingController();
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final serverConfig = context.watch<ServerConfigProvider>();
    if (!_initializedController) {
      _baseUrlController.text = serverConfig.baseUrl;
      _initializedController = true;
    }
    if (!_initializedMessaging) {
      _initializedMessaging = true;
      context.read<MessagingProvider>().ensureInitialized();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildServerSection(context),
        const SizedBox(height: 24),
        _buildMessagingSection(context),
        const SizedBox(height: 24),
        _buildAlertsSection(context),
      ],
    );
  }

  Widget _buildServerSection(BuildContext context) {
    return Consumer<ServerConfigProvider>(
      builder: (context, config, _) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Servidor da API',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _baseUrlController,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Base URL do servidor',
                    hintText: 'Ex.: http://10.0.2.2:8000',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    ElevatedButton.icon(
                      onPressed: config.isPersisting
                          ? null
                          : () => _saveServerUrl(context),
                      icon: config.isPersisting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save),
                      label: const Text('Salvar'),
                    ),
                    OutlinedButton.icon(
                      onPressed: config.isPersisting
                          ? null
                          : () => _restoreDefaultServerUrl(context),
                      icon: const Icon(Icons.restart_alt),
                      label: const Text('Restaurar padrão'),
                    ),
                    OutlinedButton.icon(
                      onPressed:
                          _isTestingConnection ? null : _testServerConnection,
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
                if (_connectionStatus != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _connectionStatus!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMessagingSection(BuildContext context) {
    return Consumer<MessagingProvider>(
      builder: (context, messaging, _) {
        final authStatus = messaging.authorizationStatus;
        final statusLabel = switch (authStatus) {
          AuthorizationStatus.denied => 'Negado',
          AuthorizationStatus.notDetermined => 'Não solicitado',
          AuthorizationStatus.provisional => 'Provisório',
          AuthorizationStatus.authorized => 'Autorizado',
          _ => messaging.isInitializing ? 'Verificando…' : 'Desconhecido',
        };

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Firebase Cloud Messaging',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text('Permissão: $statusLabel'),
                if (messaging.registrationStatus != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    messaging.registrationStatus!,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
                const SizedBox(height: 16),
                if (messaging.token == null)
                  messaging.isInitializing
                      ? const Center(child: CircularProgressIndicator())
                      : const Text('Token não disponível.')
                else
                  SelectableText(
                    messaging.token!,
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.icon(
                      onPressed: messaging.isInitializing
                          ? null
                          : () => messaging.refreshToken(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Atualizar token'),
                    ),
                    FilledButton.icon(
                      onPressed: (messaging.token ?? '').isEmpty
                          ? null
                          : () => messaging.copyTokenToClipboard(context),
                      icon: const Icon(Icons.copy),
                      label: const Text('Copiar token'),
                    ),
                    FilledButton.icon(
                      onPressed: messaging.isRegistering
                          ? null
                          : () => messaging.reRegisterToken(),
                      icon: messaging.isRegistering
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.cloud_upload),
                      label: const Text('Registrar no backend'),
                    ),
                  ],
                ),
                if (messaging.lastForegroundMessage != null ||
                    messaging.initialMessage != null) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Mensagens recentes',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  if (messaging.lastForegroundMessage != null)
                    _buildMessageTile(
                      'Em primeiro plano',
                      messaging.lastForegroundMessage!,
                    ),
                  if (messaging.initialMessage != null)
                    _buildMessageTile(
                      'Que abriu o app',
                      messaging.initialMessage!,
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAlertsSection(BuildContext context) {
    return Consumer<AlertsProvider>(
      builder: (context, alertsProvider, _) {
        final alerts = alertsProvider.alerts;
        if (alerts.isEmpty) {
          return const SizedBox.shrink();
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Notificações registradas',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...alerts.take(5).map(
                  (alert) {
                    final rawDate = alert['date'];
                    final formattedDate = rawDate is DateTime
                        ? rawDate.toLocal().toString().split('.').first
                        : (rawDate?.toString() ?? '-');
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.notifications,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: Text(alert['title'] as String? ?? '-'),
                      subtitle: Text(
                        '${alert['description'] ?? '-'}\n$formattedDate',
                      ),
                    );
                  },
                ),
                if (alerts.length > 5)
                  Text(
                    '+ ${alerts.length - 5} notificações adicionais…',
                    style: const TextStyle(fontSize: 12),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMessageTile(String title, RemoteMessage message) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.notification != null) ...[
            Text('Título: ${message.notification!.title ?? '-'}'),
            Text('Corpo: ${message.notification!.body ?? '-'}'),
          ],
          if (message.data.isNotEmpty) Text('Dados: ${message.data}'),
          Text('ID: ${message.messageId ?? '-'}'),
        ],
      ),
    );
  }

  Future<void> _saveServerUrl(BuildContext context) async {
    final serverConfig = context.read<ServerConfigProvider>();
    final messagingProvider = context.read<MessagingProvider>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await serverConfig.updateBaseUrl(_baseUrlController.text);
      if (!mounted) return;
      setState(() {
        _connectionStatus = null;
      });
      messenger.showSnackBar(
        const SnackBar(content: Text('Servidor atualizado com sucesso.')),
      );
      await messagingProvider.reRegisterToken();
    } on FormatException {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Informe uma URL válida.')),
      );
    }
  }

  Future<void> _restoreDefaultServerUrl(BuildContext context) async {
    final serverConfig = context.read<ServerConfigProvider>();
    final messagingProvider = context.read<MessagingProvider>();
    await serverConfig.restoreDefault();
    if (!mounted) return;
    _baseUrlController.text = serverConfig.baseUrl;
    setState(() {
      _connectionStatus = null;
    });
    await messagingProvider.reRegisterToken();
  }

  Future<void> _testServerConnection() async {
    final uri = Uri.tryParse(_baseUrlController.text.trim());
    final normalizedUri =
        (uri != null && uri.hasScheme && uri.host.isNotEmpty) ? uri : null;

    if (normalizedUri == null) {
      setState(() {
        _connectionStatus = 'Informe uma URL válida antes de testar.';
      });
      return;
    }

    setState(() {
      _isTestingConnection = true;
      _connectionStatus = 'Testando conexão com ${normalizedUri.toString()}…';
    });

    try {
      final response = await http.get(normalizedUri);
      final success = response.statusCode >= 200 && response.statusCode < 300;
      setState(() {
        final statusLabel = success ? 'sucesso' : 'falha';
        _connectionStatus =
            'Resposta de ${response.statusCode} (${statusLabel}).';
      });
    } catch (error) {
      setState(() {
        _connectionStatus = 'Falha ao conectar: $error';
      });
    } finally {
      setState(() {
        _isTestingConnection = false;
      });
    }
  }
}
