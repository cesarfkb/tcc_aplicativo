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
  final normalized = (rawType ?? '').trim().toLowerCase();
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
    case 'posture_absent':
      return const EventVisuals(
        label: 'Bebe nao detectado (postura)',
        icon: Icons.baby_changing_station,
        color: Colors.deepOrange,
      );
    case 'posture_face_covered':
      return const EventVisuals(
        label: 'Rosto possivelmente coberto',
        icon: Icons.health_and_safety,
        color: Colors.red,
      );
    case 'posture_prone':
    case 'posture prone':
    case 'posture-prone':
      return const EventVisuals(
        label: 'Bebe de brucos',
        icon: Icons.warning_amber_rounded,
        color: Colors.redAccent,
      );
    case 'posture_side':
      return const EventVisuals(
        label: 'Bebe de lado',
        icon: Icons.report_problem,
        color: Colors.deepOrange,
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
    case 'side_suspected':
      return const EventVisuals(
        label: 'Suspeita do Bebe de lado',
        icon: Icons.report_problem,
        color: Colors.amber,
      );
    case 'urgente':
      return const EventVisuals(
        label: 'Urgente',
        icon: Icons.priority_high,
        color: Colors.red,
      );
    case 'importante':
      return const EventVisuals(
        label: 'Importante',
        icon: Icons.report,
        color: Colors.orange,
      );
    case 'leve':
      return const EventVisuals(
        label: 'Leve',
        icon: Icons.info_outline,
        color: Colors.lightBlue,
      );
    case 'info':
    case 'informativo':
    default:
      return const EventVisuals(
        label: 'Evento',
        icon: Icons.notifications,
        color: Colors.grey,
      );
  }
}
