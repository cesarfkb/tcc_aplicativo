import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../provider/alerts_provider.dart';

class HomePage extends StatelessWidget {
  HomePage({super.key});

  final CarouselSliderController _carouselController =
      CarouselSliderController();

  @override
  Widget build(BuildContext context) {
    final alertsProvider = Provider.of<AlertsProvider>(context);
    final alerts = alertsProvider.alerts;

    if (alertsProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Estatísticas Recentes',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              CarouselSlider(
                carouselController: _carouselController,
                options: CarouselOptions(
                  height: 200,
                  autoPlay: true,
                  enlargeCenterPage: true,
                  enlargeFactor: 0.2,
                ),
                items: [
                  'assets/images/2.jpg',
                  'assets/images/3.jpg',
                  'http://localhost:7680/api/raw-snapshot',
                ]
                    .map((item) => Builder(
                          builder: (BuildContext context) {
                            return Container(
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 5.0),
                              decoration: BoxDecoration(
                                color: Colors.amber,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 10,
                                    offset: Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: item.startsWith('http')
                                    ? Image.network(
                                        item,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        errorBuilder: (BuildContext context, Object exception, StackTrace? stackTrace) =>
                                            const Center(
                                          child: Icon(Icons.error),
                                        ),
                                      )
                                    : Image.asset(
                                        item,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                      ),
                              ),
                            );
                          },
                        ))
                    .toList(),
              ),
              const SizedBox(height: 20),
              const Text(
                'Últimos Alertas',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 3, // Replace with your actual alert count
                itemBuilder: (context, index) {
                  // Using the first 3 alerts for demonstration
                  final alert = alerts[index];
                  // Don't use Urgente and Importante alerts

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
                      isThreeLine: true,
                      subtitle: Text(
                          '${alert['description']}\n${alert['date'].toLocal().toString().split('.')[0]}'),
                      trailing: Icon(Icons.arrow_forward_ios,
                          color: Colors.grey[600]),
                    ),
                  );
                },
              ),
            ],
          )),
    );
  }
}
