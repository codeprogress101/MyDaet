import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'permissions.dart';

class ClaimsService {
  ClaimsService();

  FirebaseFunctions _functions() {
    // Your functions are deployed in us-central1
    return FirebaseFunctions.instanceFor(
      app: FirebaseAuth.instance.app,
      region: 'us-central1',
    );
  }

  /// Force refresh the ID token to ensure latest custom claims are available.
  Future<void> forceRefreshToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await user.getIdToken(true);
  }

  /// Fetch claims from backend callable (authoritative).
  Future<Map<String, dynamic>> getMyClaims() async {
    final callable = _functions().httpsCallable('getMyClaims');
    final res = await callable.call();
    final data = res.data;

    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return <String, dynamic>{};
  }

  /// Convenience: get role from claims (fallback to resident)
  Future<String> getMyRole() async {
    await forceRefreshToken();
    final claims = await getMyClaims();
    final role = claims['role'];
    return AppRole.normalize(role is String ? role : null);
  }
}
