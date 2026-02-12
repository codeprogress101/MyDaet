import 'package:flutter/material.dart';

class DtsStatusHelper {
  static const values = [
    'RECEIVED',
    'IN_TRANSIT',
    'WITH_OFFICE',
    'IN_PROCESS',
    'FOR_APPROVAL',
    'RELEASED',
    'ARCHIVED',
    'PULLED_OUT',
  ];

  static String normalize(String? raw) {
    final v = (raw ?? 'RECEIVED').trim().toUpperCase();
    return values.contains(v) ? v : 'RECEIVED';
  }

  static String label(String status) {
    switch (normalize(status)) {
      case 'IN_TRANSIT':
        return 'In transit';
      case 'WITH_OFFICE':
        return 'With office';
      case 'IN_PROCESS':
        return 'In process';
      case 'FOR_APPROVAL':
        return 'For approval';
      case 'RELEASED':
        return 'Released';
      case 'ARCHIVED':
        return 'Archived';
      case 'PULLED_OUT':
        return 'Pulled out';
      case 'RECEIVED':
      default:
        return 'Received';
    }
  }

  static Color color(BuildContext context, String status) {
    switch (normalize(status)) {
      case 'IN_TRANSIT':
        return const Color(0xFF7E57C2);
      case 'WITH_OFFICE':
      case 'IN_PROCESS':
        return const Color(0xFF3A7BD5);
      case 'FOR_APPROVAL':
        return const Color(0xFFF9A825);
      case 'RELEASED':
        return const Color(0xFF2E7D32);
      case 'ARCHIVED':
        return const Color(0xFF9E9E9E);
      case 'PULLED_OUT':
        return const Color(0xFFC62828);
      case 'RECEIVED':
      default:
        return const Color(0xFFE46B2C);
    }
  }
}
