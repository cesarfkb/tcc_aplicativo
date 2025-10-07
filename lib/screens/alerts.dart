import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../provider/alerts_provider.dart';
import '../utils/event_visuals.dart';

class Alerts extends StatefulWidget {
  const Alerts({super.key});

  @override
  State<Alerts> createState() => _AlertsState();
}

class _AlertsState extends State<Alerts> {
  String _selectedType = 'Todos';
  DateTime? _selectedDate;
  bool _includeImages = true;

  @override
  void initState() {
    super.initState();
    final provider = context.read<AlertsProvider>();
    _includeImages = provider.includeImages;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      provider.fetchAlerts(reset: true, includeImages: _includeImages);
    });
  }

  Future<void> _refresh() async {
    await context
        .read<AlertsProvider>()
        .fetchAlerts(reset: true, includeImages: _includeImages);
  }

  List<Map<String, dynamic>> _filteredAlerts(
      List<Map<String, dynamic>> alerts) {
    return alerts.where((alert) {
      final type = (alert['type'] ?? 'Info').toString();
      final matchesType = _selectedType == 'Todos' ||
          type.toLowerCase() == _selectedType.toLowerCase();

      final date = alert['date'];
      DateTime? eventDate;
      if (date is DateTime) {
        eventDate = date;
      } else if (date is String) {
        eventDate = DateTime.tryParse(date);
      }
      final matchesDate = _selectedDate == null ||
          (eventDate != null &&
              eventDate.year == _selectedDate!.year &&
              eventDate.month == _selectedDate!.month &&
              eventDate.day == _selectedDate!.day);

      return matchesType && matchesDate;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final alertsProvider = context.watch<AlertsProvider>();
    final alerts = _filteredAlerts(alertsProvider.alerts);

    final showLoadingMore = alerts.isNotEmpty && alertsProvider.isLoadingMore;
    final itemCount =
        alerts.isEmpty ? 1 : alerts.length + (showLoadingMore ? 1 : 0);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showFilterSheet(context),
        icon: const Icon(Icons.filter_list),
        label: const Text('Filtros'),
      ),
      body: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.pixels >=
                  notification.metrics.maxScrollExtent - 200 &&
              alertsProvider.hasMore &&
              !alertsProvider.isLoading &&
              !alertsProvider.isLoadingMore) {
            alertsProvider.loadMoreAlerts();
          }
          return false;
        },
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: alertsProvider.isLoading && alertsProvider.alerts.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 200),
                    Center(child: CircularProgressIndicator()),
                  ],
                )
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: itemCount,
                  itemBuilder: (context, index) {
                    if (alerts.isEmpty) {
                      if (alertsProvider.error != null) {
                        return _buildMessageCard(
                          context,
                          'Erro ao carregar alertas:\n${alertsProvider.error}',
                          isError: true,
                        );
                      }
                      return _buildMessageCard(
                        context,
                        'Nenhum alerta encontrado com os filtros selecionados.',
                      );
                    }

                    if (showLoadingMore && index == alerts.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    final alert = alerts[index];
                    return _buildAlertTile(context, alert);
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildMessageCard(BuildContext context, String message,
      {bool isError = false}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          message,
          style: TextStyle(
            fontSize: 14,
            color: isError
                ? Theme.of(context).colorScheme.error
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildAlertTile(BuildContext context, Map<String, dynamic> alert) {
    final type = (alert['type'] ?? 'Info').toString();
    final visuals = resolveEventVisuals(type);
    final date = alert['date'];
    String formattedDate = '';
    if (date is DateTime) {
      formattedDate = date.toLocal().toString().split('.').first;
    } else if (date != null) {
      formattedDate = date.toString();
    }

    final description = (alert['description'] ?? '').toString();
    final title = alert['title']?.toString();
    Uint8List? previewBytes;
    final base64Image = _extractBase64Image(alert);
    if (base64Image != null) {
      try {
        previewBytes = base64Decode(base64Image);
      } catch (_) {
        previewBytes = null;
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showAlertDetails(context, alert),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (previewBytes != null)
              AspectRatio(
                aspectRatio: 4 / 3,
                child: Image.memory(
                  previewBytes,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.black12,
                    alignment: Alignment.center,
                    child: const Icon(Icons.broken_image_outlined),
                  ),
                ),
              ),
            ListTile(
              leading: Icon(visuals.icon, color: visuals.color),
              title: Text(visuals.label),
              subtitle: Text(
                [
                  if (title != null && title.isNotEmpty) title,
                  if (description.isNotEmpty) description,
                  if (formattedDate.isNotEmpty) formattedDate,
                ].join('\n'),
              ),
              trailing: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ),
    );
  }

  void _showAlertDetails(BuildContext context, Map<String, dynamic> alert) {
    final type = (alert['type'] ?? 'Info').toString();
    final visuals = resolveEventVisuals(type);
    final base64Image = _extractBase64Image(alert);
    Widget? imageWidget;
    if (base64Image != null) {
      try {
        final bytes = base64Decode(base64Image);
        imageWidget = Padding(
          padding: const EdgeInsets.only(top: 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              bytes,
              fit: BoxFit.cover,
            ),
          ),
        );
      } catch (_) {
        imageWidget = const Padding(
          padding: EdgeInsets.only(top: 12),
          child: Text('Nao foi possivel decodificar a imagem deste evento.'),
        );
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final rawTitle = (alert['title'] ?? '').toString();
        final rawDescription = (alert['description'] ?? '').toString();
        final rawDate = alert['date']?.toString() ?? '';
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).padding.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  visuals.label,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (rawTitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(rawTitle, style: const TextStyle(fontSize: 14)),
                ],
                if (rawDescription.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(rawDescription),
                ],
                const SizedBox(height: 8),
                Text(
                  'Tipo: ${visuals.label} (${alert['type'] ?? '-'})',
                  style: const TextStyle(fontSize: 12),
                ),
                if (rawDate.isNotEmpty)
                  Text(
                    'Data: $rawDate',
                    style: const TextStyle(fontSize: 12),
                  ),
                if (imageWidget != null) imageWidget,
                const SizedBox(height: 16),
                const Text(
                  'Payload bruto',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    const JsonEncoder.withIndent('  ')
                        .convert(_sanitizeAlertPayload(alert)),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Map<String, dynamic> _sanitizeAlertPayload(Map<String, dynamic> alert) {
    final result = <String, dynamic>{};
    alert.forEach((key, value) {
      if (value is DateTime) {
        result[key] = value.toIso8601String();
      } else if (value is List) {
        result[key] = value
            .map((item) => item is DateTime ? item.toIso8601String() : item)
            .toList();
      } else if (value is Map<String, dynamic>) {
        result[key] = _sanitizeAlertPayload(value);
      } else {
        result[key] = value;
      }
    });
    return result;
  }

  String? _extractBase64Image(Map<String, dynamic> alert) {
    final candidates = [
      alert['image'],
      alert['image_b64'],
      alert['image_b64'],
      alert['snapshot'],
      alert['frame'],
      alert['thumbnail'],
    ];
    for (final candidate in candidates) {
      if (candidate is String && candidate.length > 50) {
        final sanitized =
            candidate.contains(',') ? candidate.split(',').last : candidate;
        final isBase64 = RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(sanitized);
        if (isBase64) {
          return sanitized;
        }
      }
    }
    return null;
  }

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        String tempType = _selectedType;
        DateTime? tempDate = _selectedDate;
        bool tempIncludeImages = _includeImages;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Filtros',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: tempType,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Tipo de alerta',
                    ),
                    items: const [
                      'Todos',
                      'Info',
                      'Leve',
                      'Importante',
                      'Urgente',
                    ].map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(type),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setModalState(() {
                        tempType = value ?? 'Todos';
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Carregar imagens embutidas'),
                    subtitle:
                        const Text('Ative para usar /api/events com imagem.'),
                    value: tempIncludeImages,
                    onChanged: (value) {
                      setModalState(() {
                        tempIncludeImages = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: tempDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(DateTime.now().year + 1),
                            );
                            if (picked != null) {
                              setModalState(() {
                                tempDate = picked;
                              });
                            }
                          },
                          icon: const Icon(Icons.calendar_today),
                          label: Text(
                            tempDate == null
                                ? 'Selecionar data'
                                : '${tempDate!.year}-${tempDate!.month.toString().padLeft(2, '0')}-${tempDate!.day.toString().padLeft(2, '0')}',
                          ),
                        ),
                      ),
                      if (tempDate != null) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Limpar data',
                          onPressed: () {
                            setModalState(() {
                              tempDate = null;
                            });
                          },
                          icon: const Icon(Icons.clear),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: const Text('Cancelar'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () {
                          setState(() {
                            _selectedType = tempType;
                            _selectedDate = tempDate;
                            _includeImages = tempIncludeImages;
                          });
                          Navigator.of(context).pop();
                          _refresh();
                        },
                        child: const Text('Aplicar'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
