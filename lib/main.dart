import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'provider/alerts_provider.dart';
import 'provider/backend_status_provider.dart';
import 'provider/messaging_provider.dart';
import 'provider/server_config_provider.dart';
import 'screens/main_screen.dart';
import 'services/firebase_background_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ServerConfigProvider()),
        ChangeNotifierProxyProvider<ServerConfigProvider, AlertsProvider>(
          create: (_) => AlertsProvider(),
          update: (_, serverConfig, alerts) {
            final provider = alerts ?? AlertsProvider();
            provider.updateServerConfig(serverConfig);
            return provider;
          },
        ),
        ChangeNotifierProxyProvider<ServerConfigProvider,
            BackendStatusProvider>(
          create: (_) => BackendStatusProvider(),
          update: (_, serverConfig, statusProvider) {
            final provider = statusProvider ?? BackendStatusProvider();
            provider.updateServerConfig(serverConfig);
            return provider;
          },
        ),
        ChangeNotifierProxyProvider2<AlertsProvider, ServerConfigProvider,
            MessagingProvider>(
          create: (context) => MessagingProvider(
            context.read<AlertsProvider>(),
            context.read<ServerConfigProvider>(),
          ),
          update: (context, alerts, server, previous) {
            final provider = previous ?? MessagingProvider(alerts, server);
            provider.updateDependencies(alerts, server);
            return provider;
          },
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Baba Eletronica',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
