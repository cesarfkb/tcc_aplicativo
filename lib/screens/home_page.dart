import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../provider/alerts_provider.dart';
import '../provider/backend_status_provider.dart';
import '../provider/server_config_provider.dart';
import '../utils/event_visuals.dart';

class HomePage extends StatelessWidget {
  HomePage({super.key});

  final CarouselSliderController _carouselController =
      CarouselSliderController();

  Future<void> _refresh(BuildContext context) async {
    await Future.wait([
      context.read<BackendStatusProvider>().refreshAll(),
      context.read<AlertsProvider>().fetchSummaryAlerts(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<BackendStatusProvider, AlertsProvider,
        ServerConfigProvider>(
      builder: (context, statusProvider, alertsProvider, serverConfig, _) {
        final summaryAlerts = alertsProvider.summaryAlerts;
        final alertsLoading = alertsProvider.isSummaryLoading;
        final alertsError = alertsProvider.summaryError;
        final carouselSources = _buildCarouselSources(statusProvider);

        return RefreshIndicator(
          onRefresh: () => _refresh(context),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              _buildHeader(context),
              const SizedBox(height: 16),
              _buildStatusCard(context, statusProvider),
              const SizedBox(height: 16),
              _buildLatencyCard(context, statusProvider),
              const SizedBox(height: 16),
              _buildCarousel(context, carouselSources),
              const SizedBox(height: 24),
              _buildAlertsSection(
                context,
                alertsProvider,
                summaryAlerts,
                alertsLoading,
                alertsError,
              ),
              const SizedBox(height: 24),
              _buildEndpointsOverview(context, serverConfig),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Visão geral',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        FilledButton.icon(
          onPressed: () => _refresh(context),
          icon: const Icon(Icons.refresh),
          label: const Text('Atualizar'),
        ),
      ],
    );
  }

  Widget _buildStatusCard(
      BuildContext context, BackendStatusProvider statusProvider) {
    final isLoading = statusProvider.isStatusLoading;
    final isConnected = statusProvider.isConnected;
    final statusPayload = statusProvider.statusPayload;
    final statusError = statusProvider.statusError;
    final colorScheme = Theme.of(context).colorScheme;

    String statusLabel;
    IconData icon;
    Color iconColor;
    if (isLoading) {
      statusLabel = 'Verificando estado da câmera…';
      icon = Icons.sync;
      iconColor = colorScheme.primary;
    } else if (statusError != null) {
      statusLabel = 'Erro: $statusError';
      icon = Icons.error_outline;
      iconColor = colorScheme.error;
    } else if (isConnected) {
      statusLabel = 'Câmera conectada';
      icon = Icons.check_circle_outline;
      iconColor = Colors.green;
    } else {
      statusLabel = 'Câmera desconectada';
      icon = Icons.highlight_off;
      iconColor = Colors.orange;
    }

    final extraStatusLines = <Widget>[];
    if (statusPayload != null) {
      final entries = statusPayload.entries
          .where((entry) =>
              entry.key != 'connected' &&
              entry.key != 'status' &&
              entry.key != 'state' &&
              entry.key != 'code')
          .take(4);
      for (final entry in entries) {
        extraStatusLines.add(
          Text('${entry.key}: ${entry.value}'),
        );
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 36, color: iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    statusLabel,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (statusPayload != null &&
                      (statusPayload['code'] != null ||
                          statusPayload['status'] != null ||
                          statusPayload['state'] != null))
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Código: ${statusPayload['code'] ?? '-'} | Status: ${statusPayload['status'] ?? statusPayload['state'] ?? '-'}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  if (extraStatusLines.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: extraStatusLines,
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

  Widget _buildLatencyCard(
      BuildContext context, BackendStatusProvider statusProvider) {
    final isLoading = statusProvider.isLatencyLoading;
    final latencyData = statusProvider.latencyMetrics;
    final latencyError = statusProvider.latencyError;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Latência de captura',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (isLoading)
              const LinearProgressIndicator()
            else if (latencyError != null)
              Text(
                'Erro ao carregar latência: $latencyError',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              )
            else if (latencyData == null || latencyData.isEmpty)
              const Text('Nenhuma métrica disponível no momento.')
            else
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: latencyData.entries
                    .map(
                      (entry) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            entry.key,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            '${entry.value} ms',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCarousel(BuildContext context, List<String> sources) {
    if (sources.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Snapshots não disponíveis',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              Text(
                'Configure o servidor e verifique o endpoint /api/snapshot.',
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Snapshots recentes',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 12),
            CarouselSlider(
              carouselController: _carouselController,
              options: CarouselOptions(
                height: 220,
                autoPlay: sources.length > 1,
                enlargeCenterPage: true,
                enlargeFactor: 0.2,
                viewportFraction: 0.9,
              ),
              items: sources.map((url) {
                return Builder(
                  builder: (context) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Theme.of(context).colorScheme.surfaceVariant,
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 10,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        url,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) => Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.broken_image_outlined, size: 48),
                              SizedBox(height: 8),
                              Text('Falha ao carregar imagem'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertsSection(
    BuildContext context,
    AlertsProvider alertsProvider,
    List<Map<String, dynamic>> alerts,
    bool isLoading,
    String? error,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Ultimos alertas',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                IconButton(
                  tooltip: 'Atualizar alertas',
                  onPressed: () => alertsProvider.fetchSummaryAlerts(),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else if (error != null)
              Text(
                'Erro ao carregar alertas: ' + (error ?? ''),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              )
            else if (alerts.isEmpty)
              const Text('Nenhum alerta registrado ate o momento.')
            else
              Column(
                children: alerts.take(3).map((alert) {
                  final type = (alert['type'] ?? 'Info').toString();
                  final visuals = resolveEventVisuals(type);
                  final date = alert['date'];
                  String formattedDate;
                  if (date is DateTime) {
                    formattedDate = date.toLocal().toString().split('.').first;
                  } else {
                    formattedDate = date?.toString() ?? '';
                  }
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(visuals.icon, color: visuals.color),
                    title: Text(visuals.label),
                    subtitle: Text(
                      [
                        if ((alert['title'] ?? '').toString().isNotEmpty)
                          alert['title'].toString(),
                        if ((alert['description'] ?? '').toString().isNotEmpty)
                          alert['description'].toString(),
                        formattedDate,
                      ].join('\n'),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEndpointsOverview(
      BuildContext context, ServerConfigProvider serverConfig) {
    final baseUrl = serverConfig.baseUrl;
    final endpoints = [
      '/api/status',
      '/api/snapshot',
      '/api/pose-snapshot',
      '/api/stream',
      '/api/events',
      '/api/events/noimg',
      '/api/events/{offset}',
      '/api/events/{offset}/noimg',
      '/api/latency',
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Endpoints configurados',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Base: $baseUrl',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 8),
            ...endpoints.map(
              (path) => Text(
                '$baseUrl$path',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<String> _buildCarouselSources(BackendStatusProvider statusProvider) {
    final sources = <String>[];
    final snapshotUri = statusProvider.snapshotUri;
    final poseSnapshotUri = statusProvider.poseSnapshotUri;
    if (snapshotUri != null) {
      sources.add(snapshotUri.toString());
    }
    if (poseSnapshotUri != null) {
      sources.add(poseSnapshotUri.toString());
    }
    return sources;
  }
}
