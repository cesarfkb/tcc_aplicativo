import 'package:flutter/material.dart';

class EventVisuals {
  const EventVisuals({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;
}

EventVisuals resolveEventVisuals(String? rawType) {
  final normalized = (rawType ?? '').toLowerCase();
  switch (normalized) {
    case 'absence':
      return const EventVisuals(
        label: 'Bebe nao detectado no berco',
        icon: Icons.baby_changing_station,
        color: Colors.orange,
      );
    case 'camera_connected':
      return const EventVisuals(
        label: 'Camera conectada',
        icon: Icons.videocam,
        color: Colors.green,
      );
    case 'camera_disconnected':
      return const EventVisuals(
        label: 'Camera desconectada',
        icon: Icons.videocam_off,
        color: Colors.redAccent,
      );
    case 'face_down':
      return const EventVisuals(
        label: 'Bebe de brucos',
        icon: Icons.warning_amber_rounded,
        color: Colors.deepOrange,
      );
    case 'face_down_suspected':
      return const EventVisuals(
        label: 'Suspeita do Bebe de brucos',
        icon: Icons.report_problem,
        color: Colors.amber,
      );
    case 'info':
    default:
      return const EventVisuals(
        label: 'Informativo',
        icon: Icons.info_outline,
        color: Colors.blueAccent,
      );
  }
}
