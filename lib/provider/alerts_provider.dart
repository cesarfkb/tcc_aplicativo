import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AlertsProvider with ChangeNotifier {
  List<Map<String, dynamic>> _alerts = [];
  bool _isLoading = true;

  List<Map<String, dynamic>> get alerts => _alerts;
  bool get isLoading => _isLoading;

  Future<void> loadAlerts() async {
    try {
      _isLoading = true;
      final String jsonString =
          await rootBundle.loadString('assets/alerts.json');
      final List<dynamic> jsonList = json.decode(jsonString);

      for (var alert in jsonList) {
        alert['date'] = DateTime.parse(alert['date']);
      }
      _alerts = List<Map<String, dynamic>>.from(jsonList);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      print('Error loading alerts: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  void addAlert(Map<String, dynamic> newAlert) {
    _alerts.insert(0, newAlert);
    notifyListeners();
  }
}
