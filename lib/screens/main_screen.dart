import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../provider/alerts_provider.dart';
import '../provider/backend_status_provider.dart';
import '../provider/messaging_provider.dart';
import 'alerts.dart';
import 'home_page.dart';
import 'live_feed.dart';
import 'settings_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  late final List<Widget> _pages;
  final List<String> _titles = [
    'Baba Eletronica',
    '',
    'Alertas',
    'Configuracoes',
  ];

  @override
  void initState() {
    super.initState();
    _pages = [
      HomePage(),
      const LiveFeed(),
      const Alerts(),
      const SettingsScreen(),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final alertsProvider = context.read<AlertsProvider>();
      final statusProvider = context.read<BackendStatusProvider>();
      final messagingProvider = context.read<MessagingProvider>();
      alertsProvider.fetchSummaryAlerts();
      alertsProvider.fetchAlerts(reset: true);
      statusProvider.refreshAll();
      messagingProvider.ensureInitialized();
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _currentIndex == 1
          ? null
          : AppBar(
              title: Text(_titles[_currentIndex]),
            ),
      body: Stack(
        children: [
          _pages[_currentIndex],
          if (_currentIndex == 1)
            Positioned(
              top: 10,
              right: 10,
              child: FloatingActionButton(
                onPressed: () => _onItemTapped(0),
                child: const Icon(Icons.home, color: Colors.black),
              ),
            ),
        ],
      ),
      bottomNavigationBar: _currentIndex == 1
          ? null
          : BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              selectedItemColor: Theme.of(context).colorScheme.primary,
              unselectedItemColor:
                  Theme.of(context).colorScheme.onSurfaceVariant,
              backgroundColor: Theme.of(context).colorScheme.surface,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.video_camera_front),
                  label: 'Live Feed',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.notifications),
                  label: 'Alertas',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.settings),
                  label: 'Configuracoes',
                ),
              ],
              currentIndex: _currentIndex,
              onTap: _onItemTapped,
            ),
    );
  }
}
