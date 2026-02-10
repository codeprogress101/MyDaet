import 'package:cloud_firestore/cloud_firestore.dart';

import 'permissions.dart';

class AppointmentsService {
  final FirebaseFirestore _db;

  AppointmentsService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get appointments =>
      _db.collection('appointments');
  CollectionReference<Map<String, dynamic>> get officeSlots =>
      _db.collection('office_slots');

  /// Office scoping rules:
  /// - super_admin: all offices
  /// - office_admin / moderator: filter by officeId
  Query<Map<String, dynamic>> appointmentsFor(UserContext user) {
    if (Permissions.canViewAllOffices(user)) {
      return appointments;
    }
    return _officeScopedQuery(appointments, user.officeId);
  }

  Query<Map<String, dynamic>> officeSlotsFor(UserContext user) {
    if (Permissions.canViewAllOffices(user)) {
      return officeSlots;
    }
    return _officeScopedQuery(officeSlots, user.officeId);
  }

  Query<Map<String, dynamic>> _officeScopedQuery(
    CollectionReference<Map<String, dynamic>> base,
    String? officeId,
  ) {
    // TODO: Ensure appointments and office_slots always include officeId.
    final trimmed = officeId?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      // Prevent accidental cross-office reads when officeId is missing.
      return base.where('officeId', isEqualTo: '__no_office__');
    }
    return base.where('officeId', isEqualTo: trimmed);
  }
}
