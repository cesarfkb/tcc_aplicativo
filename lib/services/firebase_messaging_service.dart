import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:prototipo_tcc/provider/alerts_provider.dart';
import 'package:provider/provider.dart';

class FirebaseMessagingService {
  final BuildContext context;
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  FirebaseMessagingService(this.context);

  Future<void> initialize() async {
    await _firebaseMessaging.requestPermission();

    final String? fcmToken = await _firebaseMessaging.getToken();
    print('FCM Token: $fcmToken');

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Mensagem recebida: ${message.notification?.title}');
      print('Mensagem recebida: ${message.notification?.body}');

      if (message.notification != null) {
        print('Notificação recebida: ${message.notification}');
        _handleIncomingMessage(message);
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('Mensagem aberta: ${message.notification?.title}');
      print('Mensagem aberta: ${message.notification?.body}');
      _handleIncomingMessage(message);
    });
  }

  void _handleIncomingMessage(RemoteMessage message) {
    final newAlert = {
      "title": message.notification?.title ?? 'Nova Notificação',
      "description":
          message.notification?.body ?? 'Você recebeu uma nova notificação',
      "type": message.data['type'] ?? 'Info',
      "date": DateTime.now(),
    };

    Provider.of<AlertsProvider>(context, listen: false).addAlert(newAlert);
  }
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Mensagem recebida em segundo plano: ${message.notification?.title}');
}
