import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../provider/alerts_provider.dart';
import 'alerts.dart';
import 'home_page.dart';
import 'live_feed.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    Provider.of<AlertsProvider>(context, listen: false).loadAlerts();
  }

  final List<Widget> _pages = [
    HomePage(), // Replace with your actual page widgets
    LiveFeed(),
    const Alerts(),
  ];

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
              title: const Text('Baba Eletrônica'),
            ),
      body: Stack(children: [
        _pages[_currentIndex],
        if (_currentIndex == 1)
          Positioned(
              top: 10,
              right: 10,
              child: FloatingActionButton(
                  onPressed: () {
                    setState(() {
                      _currentIndex = 0; // Volta para a página inicial
                    });
                  },
                  child: const Icon(Icons.home, color: Colors.black))),
      ]),
      bottomNavigationBar: _currentIndex == 1
          ? null
          : BottomNavigationBar(
              items: [
                const BottomNavigationBarItem(
                    icon: Icon(Icons.home), label: 'Home'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.video_camera_front), label: 'Live Feed'),
                const BottomNavigationBarItem(
                    icon: Icon(Icons.notifications), label: 'Alerts'),
              ],
              currentIndex: _currentIndex,
              onTap: _onItemTapped,
            ),
    );
  }
}
