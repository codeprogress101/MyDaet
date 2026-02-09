import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';

class AnnouncementsService {
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  Stream<QuerySnapshot<Map<String, dynamic>>> publishedAnnouncementsStream({
    int limit = 50,
  }) {
    return _db
        .collection('announcements')
        .where('status', isEqualTo: 'published')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> allAnnouncementsStream({
    int limit = 100,
  }) {
    return _db
        .collection('announcements')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots();
  }

  Map<String, dynamic> _actorPayload() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {};
    return {
      'lastActionByUid': user.uid,
      'lastActionByEmail': user.email,
      'lastActionByName': user.displayName,
      'lastActionAt': FieldValue.serverTimestamp(),
    };
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> myReadsStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Stream.empty();
    }
    return _db
        .collection('users')
        .doc(user.uid)
        .collection('announcementReads')
        .snapshots();
  }

  Future<void> markRead(String announcementId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || announcementId.isEmpty) return;

    await _db
        .collection('users')
        .doc(user.uid)
        .collection('announcementReads')
        .doc(announcementId)
        .set(
      {
        'announcementId': announcementId,
        'readAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> recordView(String announcementId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || announcementId.isEmpty) return;

    await _db
        .collection('announcements')
        .doc(announcementId)
        .collection('views')
        .doc(user.uid)
        .set(
      {
        'uid': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<String> createAnnouncement({
    required String title,
    required String body,
    String meta = '',
    String status = 'draft',
    String category = 'General',
    PlatformFile? mediaFile,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not logged in');

    final doc = _db.collection('announcements').doc();
    Map<String, dynamic>? media;

    if (mediaFile != null) {
      media = await _uploadMedia(
        announcementId: doc.id,
        file: mediaFile,
      );
    }

    await doc.set({
      'title': title.trim(),
      'body': body.trim(),
      'meta': meta.trim(),
      'status': status,
      'category': category.trim().isEmpty ? 'General' : category.trim(),
      'media': media,
      'views': 0,
      'createdByUid': user.uid,
      'createdByEmail': user.email,
      'createdByName': user.displayName,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      ..._actorPayload(),
    });

    return doc.id;
  }

  Future<void> updateAnnouncement({
    required String announcementId,
    required String title,
    required String body,
    String meta = '',
    String status = 'draft',
    String category = 'General',
    PlatformFile? mediaFile,
    String? existingMediaPath,
    bool removeMedia = false,
  }) async {
    final updates = <String, dynamic>{
      'title': title.trim(),
      'body': body.trim(),
      'meta': meta.trim(),
      'status': status,
      'category': category.trim().isEmpty ? 'General' : category.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
      ..._actorPayload(),
    };

    if (removeMedia) {
      updates['media'] = FieldValue.delete();
      if (existingMediaPath != null && existingMediaPath.isNotEmpty) {
        await _deleteMedia(existingMediaPath);
      }
    }

    if (mediaFile != null) {
      final media = await _uploadMedia(
        announcementId: announcementId,
        file: mediaFile,
      );
      updates['media'] = media;
      if (existingMediaPath != null && existingMediaPath.isNotEmpty) {
        await _deleteMedia(existingMediaPath);
      }
    }

    await _db.collection('announcements').doc(announcementId).update(updates);
  }

  Future<void> updateStatus(String announcementId, String status) async {
    await _db.collection('announcements').doc(announcementId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
      ..._actorPayload(),
    });
  }

  Future<void> deleteAnnouncement(
    String announcementId, {
    String? mediaPath,
  }) async {
    final actor = _actorPayload();
    if (actor.isNotEmpty) {
      await _db.collection('announcements').doc(announcementId).set(
        actor,
        SetOptions(merge: true),
      );
    }
    await _db.collection('announcements').doc(announcementId).delete();
    if (mediaPath != null && mediaPath.isNotEmpty) {
      await _deleteMedia(mediaPath);
    }
  }

  Future<Map<String, dynamic>> _uploadMedia({
    required String announcementId,
    required PlatformFile file,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await user.getIdToken(true);
    }

    final path = file.path;
    if (path == null) throw Exception('File path missing');

    final filename = file.name;
    final storagePath = 'announcements/$announcementId/$filename';
    final ref = _storage.ref(storagePath);
    final task = await ref.putFile(File(path));
    final url = await task.ref.getDownloadURL();

    return {
      'type': 'image',
      'url': url,
      'path': storagePath,
      'name': filename,
      'size': file.size,
      'contentType': task.metadata?.contentType,
    };
  }

  Future<void> _deleteMedia(String storagePath) async {
    await _storage.ref(storagePath).delete();
  }
}
