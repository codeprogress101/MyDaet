import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../features/admin/admin_report_detail_screen.dart';
import '../features/moderator/moderator_report_detail_screen.dart';
import '../features/resident/announcements_screen.dart';
import '../features/resident/report_detail_screen.dart';

class NotificationService {
  NotificationService._();

  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static String? _cachedToken;
  static String? _pendingReportId;
  static String? _pendingAnnouncementId;

  static Future<void> init() async {
    await _requestPermission();
    _cachedToken = await _messaging.getToken();
    await _saveToken(_cachedToken);

    FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      _cachedToken = token;
      await _saveToken(token);
    });

    FirebaseAuth.instance.userChanges().listen((user) async {
      if (user != null && _cachedToken != null) {
        await _saveToken(_cachedToken);
      }
    });

    FirebaseMessaging.onMessage.listen((message) {
      final title = message.notification?.title ?? 'Notification';
      final body = message.notification?.body ?? '';
      if (body.isEmpty) return;
      messengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('$title\n$body'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    });

    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleMessage(initialMessage);
    }

    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null && _pendingReportId != null) {
        _navigateToReport(_pendingReportId!);
        _pendingReportId = null;
      }
      if (user != null && _pendingAnnouncementId != null) {
        _navigateToAnnouncement(_pendingAnnouncementId!);
        _pendingAnnouncementId = null;
      }
    });
  }

  static Future<void> unregisterToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final token = _cachedToken ?? await _messaging.getToken();
    if (token == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('fcmTokens')
        .doc(token)
        .delete();
  }

  static void drainPending() {
    if (_pendingReportId != null) {
      _navigateToReport(_pendingReportId!);
      _pendingReportId = null;
    }
    if (_pendingAnnouncementId != null) {
      _navigateToAnnouncement(_pendingAnnouncementId!);
      _pendingAnnouncementId = null;
    }
  }

  static Future<void> _requestPermission() async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  static Future<void> _saveToken(String? token) async {
    if (token == null) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('fcmTokens')
        .doc(token)
        .set(
      {
        'token': token,
        'platform': defaultTargetPlatform.name,
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  static Future<void> _handleMessage(RemoteMessage message) async {
    final type = (message.data['type'] ?? '').toString();
    final announcementId =
        (message.data['announcementId'] ?? '').toString().trim();
    final reportId = (message.data['reportId'] ?? '').toString().trim();

    if (type == 'announcement_published' && announcementId.isNotEmpty) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _pendingAnnouncementId = announcementId;
        return;
      }

      _navigateToAnnouncement(announcementId);
      return;
    }

    if (reportId.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _pendingReportId = reportId;
      return;
    }

    _navigateToReport(reportId);
  }

  static Future<void> _navigateToReport(String reportId) async {
    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      _pendingReportId = reportId;
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _pendingReportId = reportId;
      return;
    }

    String role = 'resident';
    try {
      final token = await user.getIdTokenResult();
      final claimRole = token.claims?['role'];
      if (claimRole is String && claimRole.isNotEmpty) {
        role = claimRole;
      }
    } catch (_) {}

    Widget screen;
    if (role == 'admin' || role == 'super_admin') {
      screen = AdminReportDetailScreen(reportId: reportId);
    } else if (role == 'moderator') {
      screen = ModeratorReportDetailScreen(reportId: reportId);
    } else {
      screen = ReportDetailScreen(reportId: reportId);
    }

    navigator.push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  static Future<void> _navigateToAnnouncement(String announcementId) async {
    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      _pendingAnnouncementId = announcementId;
      return;
    }

    navigator.push(
      MaterialPageRoute(
        builder: (_) => AnnouncementDetailScreen(
          announcementId: announcementId,
        ),
      ),
    );
  }
}
