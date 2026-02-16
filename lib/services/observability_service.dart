import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

class ObservabilityService {
  ObservabilityService._();

  static final FirebaseCrashlytics _crashlytics = FirebaseCrashlytics.instance;
  static StreamSubscription<User?>? _authSub;
  static bool _started = false;

  static void start() {
    if (_started) return;
    _started = true;
    _authSub = FirebaseAuth.instance.authStateChanges().listen(
      (user) async {
        await _applyUserContext(user);
      },
      onError: (error, stack) {
        _record(error, stack, reason: 'observability_auth_listener');
      },
    );
  }

  static Future<void> dispose() async {
    await _authSub?.cancel();
    _authSub = null;
    _started = false;
  }

  static Future<void> _applyUserContext(User? user) async {
    try {
      await _crashlytics.setUserIdentifier(user?.uid ?? 'anonymous');
      if (user == null) {
        await _crashlytics.setCustomKey('role', 'anonymous');
        await _crashlytics.setCustomKey('officeId', '');
        await _crashlytics.setCustomKey('officeName', '');
        return;
      }

      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = snap.data() ?? const <String, dynamic>{};
      final role = (data['role'] ?? 'resident').toString();
      final officeId = (data['officeId'] ?? '').toString();
      final officeName = (data['officeName'] ?? '').toString();
      final isActive = data['isActive'] is bool
          ? data['isActive'] as bool
          : true;

      await _crashlytics.setCustomKey('role', role);
      await _crashlytics.setCustomKey('officeId', officeId);
      await _crashlytics.setCustomKey('officeName', officeName);
      await _crashlytics.setCustomKey('isActive', isActive);
      await _crashlytics.setCustomKey(
        'appMode',
        kDebugMode ? 'debug' : 'release',
      );
    } catch (error, stack) {
      _record(error, stack, reason: 'observability_apply_user_context');
    }
  }

  static Future<void> setRoute(String routeName) async {
    try {
      await _crashlytics.setCustomKey('route', routeName);
    } catch (_) {}
  }

  static Future<void> recordError(
    Object error,
    StackTrace stack, {
    required String reason,
    Map<String, Object?> context = const <String, Object?>{},
    bool fatal = false,
  }) async {
    await _record(error, stack, reason: reason, context: context, fatal: fatal);
  }

  static Future<void> _record(
    Object error,
    StackTrace? stack, {
    required String reason,
    Map<String, Object?> context = const <String, Object?>{},
    bool fatal = false,
  }) async {
    try {
      if (context.isNotEmpty) {
        for (final entry in context.entries) {
          await _crashlytics.setCustomKey(
            'ctx_${entry.key}',
            (entry.value ?? '').toString(),
          );
        }
      }
      await _crashlytics.recordError(
        error,
        stack,
        reason: reason,
        fatal: fatal,
      );
    } catch (_) {}
  }
}
