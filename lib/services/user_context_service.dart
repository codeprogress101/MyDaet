import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'claims_service.dart';
import 'permissions.dart';

class UserContextService {
  UserContextService({
    ClaimsService? claimsService,
    FirebaseFirestore? firestore,
  })  : _claimsService = claimsService ?? ClaimsService(),
        _db = firestore ?? FirebaseFirestore.instance;

  final ClaimsService _claimsService;
  final FirebaseFirestore _db;

  Future<UserContext?> getCurrent() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    Map<String, dynamic> claims = {};
    try {
      await _claimsService.forceRefreshToken();
      claims = await _claimsService.getMyClaims();
    } catch (_) {
      // Fallback to Firestore user doc if claims fetch fails.
    }

    String role = AppRole.normalize(_string(claims['role']));
    String? officeId =
        _string(claims['officeId']) ?? _string(claims['office_id']);
    String? officeName =
        _string(claims['officeName']) ?? _string(claims['office_name']);
    bool isActive =
        claims['isActive'] is bool ? claims['isActive'] as bool : true;

    final needsDocFallback =
        _string(claims['role']) == null ||
            officeId == null ||
            officeName == null ||
            claims['isActive'] == null;

    if (needsDocFallback) {
      try {
        final doc = await _db.collection('users').doc(user.uid).get();
        final data = doc.data();
        if (data != null) {
          if (_string(claims['role']) == null) {
            role = AppRole.normalize(_string(data['role']));
          }
          officeId ??= _string(data['officeId']);
          officeName ??= _string(data['officeName']);
          if (claims['isActive'] == null && data['isActive'] is bool) {
            isActive = data['isActive'] as bool;
          }
        }
      } catch (_) {
        // Keep best-effort data.
      }
    }

    return UserContext(
      uid: user.uid,
      role: role,
      officeId: officeId,
      officeName: officeName,
      isActive: isActive,
    );
  }
}

String? _string(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}
