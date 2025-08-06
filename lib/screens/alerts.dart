import 'package:flutter/material.dart';
import 'package:prototipo_tcc/provider/alerts_provider.dart';
import 'package:provider/provider.dart';

class Alerts extends StatefulWidget {
  const Alerts({super.key});

  @override
  State<Alerts> createState() => _AlertsState();
}

class _AlertsState extends State<Alerts> {
  String _alertType = 'Todos';
  DateTime? _searchDate;
  // DateTime? _startDate;
  // DateTime? _endDate;

  void _showFilterModal(BuildContext context) {
    showModalBottomSheet(
        context: context,
        builder: (context) {
          return Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Filtros',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: _alertType,
                      decoration: const InputDecoration(
                        labelText: 'Tipo de Alerta',
                        border: OutlineInputBorder(),
                      ),
                      items: ['Todos', 'Info', 'Leve', 'Importante', 'Urgente']
                          .map((type) =>
                              DropdownMenuItem(value: type, child: Text(type)))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _alertType = value ?? 'Todos';
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                        onPressed: () async {
                          final DateTime? pickedDate = await showDatePicker(
                              context: context,
                              initialDate: _searchDate ?? DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime(DateTime.now().year + 1));
                          if (pickedDate != null) {
                            setState(() {
                              _searchDate = pickedDate;
                            });
                          }
                        },
                        icon: const Icon(Icons.calendar_today),
                        label: Text(
                          _searchDate == null
                              ? 'Selecionar Data'
                              : 'Data Selecionada: ${_searchDate!.toLocal()}'
                                  .split(' ')[0],
                        )),
                  ]));
        });
  }

  // Widget _buildFilterOptions() {
  //   return Row(
  //     mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //     children: [
  //       Expanded(
  //         child: DropdownButtonFormField<String>(
  //           value: _alertType,
  //           decoration: InputDecoration(
  //             labelText: 'Tipo de Alerta',
  //             border: OutlineInputBorder(),
  //           ),
  //           items: ['Todos', 'Info', 'Leve', 'Importante', 'Urgente']
  //               .map((type) => DropdownMenuItem(
  //                     value: type,
  //                     child: Text(type),
  //                   ))
  //               .toList(),
  //           onChanged: (value) {
  //             setState(() {
  //               _alertType = value ?? 'Todos';
  //             });
  //           },
  //         ),
  //       ),
  //       ElevatedButton(
  //         onPressed: () async {
  //           final DateTime? pickedDate = await showDatePicker(
  //             context: context,
  //             initialDate: _searchDate ?? DateTime.now(),
  //             firstDate: DateTime(2000),
  //             lastDate: DateTime(2101),
  //           );
  //           if (pickedDate != null && pickedDate != _searchDate) {
  //             setState(() {
  //               _searchDate = pickedDate;
  //             });
  //           }
  //         },
  //         child: Text(_searchDate == null
  //             ? 'Selecionar Data'
  //             : 'Data Selecionada: ${_searchDate!.toLocal()}'.split(' ')[0]),
  //       ),
  //     ],
  //   );
  // }

  List<Map<String, dynamic>> _filterAlerts(alerts) {
    return alerts.where((alert) {
      final matchesType = _alertType == 'Todos' || alert['type'] == _alertType;
      final matchesDate = _searchDate == null ||
          (alert['date'].year == _searchDate!.year &&
              alert['date'].month == _searchDate!.month &&
              alert['date'].day == _searchDate!.day);
      return matchesType && matchesDate;
    }).toList();
  }

  Widget _buildAlertList(alerts) {
    final filteredAlerts = _filterAlerts(alerts);
    return ListView.builder(
      itemCount: filteredAlerts.length,
      itemBuilder: (context, index) {
        final alert = filteredAlerts[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 5),
          child: ListTile(
            leading: Icon(
              alert['type'] == 'Info' ? Icons.info : Icons.warning,
              color: alert['type'] == 'Urgente'
                  ? Colors.red
                  : alert['type'] == 'Importante'
                      ? Colors.orange
                      : alert['type'] == 'Leve'
                          ? Colors.green
                          : Colors.blue,
            ),
            title: Text(alert['title']),
            subtitle: Text('${alert['description']}\n'
                    '${alert['date'].toLocal()}'
                .split(' ')[0]),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final alertsProvider = Provider.of<AlertsProvider>(context);
    final alerts = alertsProvider.alerts;

    return Scaffold(
        body: Stack(
      children: [
        Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [Expanded(child: _buildAlertList(alerts))],
            )),
        Positioned(
            top: 20,
            right: 20,
            child: FloatingActionButton(
              onPressed: () => _showFilterModal(context),
              child: const Icon(Icons.filter_list, color: Colors.black),
            ))
      ],
    ));

    // return Padding(
    //   padding: const EdgeInsets.all(15),
    //   child: Column(
    //     crossAxisAlignment: CrossAxisAlignment.start,
    //     children: [
    //       const Text(
    //         'Alertas',
    //         style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
    //       ),
    //       const SizedBox(height: 20),
    //       _buildFilterOptions(),
    //       const SizedBox(height: 20),
    //       Expanded(child: _buildAlertList(alerts)),
    //     ],
    //   ),
    // );
  }
}
