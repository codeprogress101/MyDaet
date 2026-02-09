import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';

class AdsService {
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  Stream<QuerySnapshot<Map<String, dynamic>>> publishedAdsStream(
      {int limit = 50}) {
    return _db
        .collection('ads')
        .where('status', isEqualTo: 'published')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> allAdsStream({int limit = 100}) {
    return _db
        .collection('ads')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> myReactionStream(String adId) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Stream.empty();
    }
    return _db
        .collection('ads')
        .doc(adId)
        .collection('reactions')
        .doc(uid)
        .snapshots();
  }

  Future<void> setReaction(String adId, String? reaction) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Not logged in');

    final ref =
        _db.collection('ads').doc(adId).collection('reactions').doc(uid);

    if (reaction == null) {
      await ref.delete();
      return;
    }

    await ref.set({
      'type': reaction,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<String> createAd({
    required String title,
    required String body,
    required String meta,
    required String cta,
    String? ctaUrl,
    required String status,
    PlatformFile? mediaFile,
    String? mediaType,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not logged in');

    final doc = _db.collection('ads').doc();
    Map<String, dynamic>? media;

    if (mediaFile != null && mediaType != null) {
      media = await _uploadMedia(
        adId: doc.id,
        file: mediaFile,
        mediaType: mediaType,
      );
    }

    await doc.set({
      'title': title.trim(),
      'body': body.trim(),
      'meta': meta.trim(),
      'cta': cta.trim(),
      'ctaUrl': (ctaUrl ?? '').trim(),
      'status': status,
      'media': media,
      'reactions': {'like': 0, 'dislike': 0},
      'createdByUid': user.uid,
      'createdByEmail': user.email,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return doc.id;
  }

  Future<void> updateAd({
    required String adId,
    required String title,
    required String body,
    required String meta,
    required String cta,
    String? ctaUrl,
    required String status,
    PlatformFile? mediaFile,
    String? mediaType,
    String? existingMediaPath,
    bool removeMedia = false,
  }) async {
    Map<String, dynamic> updates = {
      'title': title.trim(),
      'body': body.trim(),
      'meta': meta.trim(),
      'cta': cta.trim(),
      'ctaUrl': (ctaUrl ?? '').trim(),
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (removeMedia) {
      updates['media'] = FieldValue.delete();
      if (existingMediaPath != null && existingMediaPath.isNotEmpty) {
        await _deleteMedia(existingMediaPath);
      }
    }

    if (mediaFile != null && mediaType != null) {
      final media = await _uploadMedia(
        adId: adId,
        file: mediaFile,
        mediaType: mediaType,
      );
      updates['media'] = media;
      if (existingMediaPath != null && existingMediaPath.isNotEmpty) {
        await _deleteMedia(existingMediaPath);
      }
    }

    await _db.collection('ads').doc(adId).update(updates);
  }

  Future<void> updateAdStatus(String adId, String status) async {
    await _db.collection('ads').doc(adId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> recountReactions(String adId) async {
    final snap = await _db
        .collection('ads')
        .doc(adId)
        .collection('reactions')
        .get();

    int like = 0;
    int dislike = 0;
    for (final doc in snap.docs) {
      final type = (doc.data()['type'] ?? '').toString();
      if (type == 'like') like += 1;
      if (type == 'dislike') dislike += 1;
    }

    await _db.collection('ads').doc(adId).update({
      'reactions': {'like': like, 'dislike': dislike},
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteAd(String adId, {String? mediaPath}) async {
    await _db.collection('ads').doc(adId).delete();
    if (mediaPath != null && mediaPath.isNotEmpty) {
      await _deleteMedia(mediaPath);
    }
  }

  Future<Map<String, dynamic>> _uploadMedia({
    required String adId,
    required PlatformFile file,
    required String mediaType,
  }) async {
    // Ensure latest custom claims are used by Storage rules.
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await user.getIdToken(true);
    }

    final path = file.path;
    if (path == null) throw Exception('File path missing');

    final filename = file.name;
    final storagePath = 'ads/$adId/$filename';
    final ref = _storage.ref(storagePath);
    final task = await ref.putFile(File(path));
    final url = await task.ref.getDownloadURL();

    return {
      'type': mediaType,
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
