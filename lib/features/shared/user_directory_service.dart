import 'package:cloud_firestore/cloud_firestore.dart';

class UserDirectoryItem {
  final String uid;
  final String email;
  final String role;
  final String displayName;
  final String? officeId;
  final String? officeName;

  const UserDirectoryItem({
    required this.uid,
    required this.email,
    required this.role,
    required this.displayName,
    this.officeId,
    this.officeName,
  });
}

class UserDirectoryService {
  final _db = FirebaseFirestore.instance;

  Stream<List<UserDirectoryItem>> watchAssignableUsers({
    String? officeId,
    List<String>? roles,
  }) {
    // Users that can be assigned to handle reports
    // NOTE: Firestore "in" supports up to 10 values
    final normalizedRoles = (roles ??
            const ["moderator", "office_admin", "super_admin", "admin"])
        .map((r) => r.trim())
        .where((r) => r.isNotEmpty)
        .toList();
    if (normalizedRoles.isEmpty) {
      return const Stream.empty();
    }

    Query<Map<String, dynamic>> query =
        _db.collection("users").where("role", whereIn: normalizedRoles);
    if (officeId != null && officeId.trim().isNotEmpty) {
      query = query.where("officeId", isEqualTo: officeId);
    }

    return query.snapshots().map((snap) {
      final list = snap.docs.map((d) {
        final data = d.data();
        return UserDirectoryItem(
          uid: d.id,
          email: (data["email"] ?? "").toString(),
          role: (data["role"] ?? "resident").toString(),
          displayName: (data["displayName"] ?? "").toString(),
          officeId: (data["officeId"] ?? "").toString().trim().isEmpty
              ? null
              : (data["officeId"] ?? "").toString(),
          officeName: (data["officeName"] ?? "").toString().trim().isEmpty
              ? null
              : (data["officeName"] ?? "").toString(),
        );
      }).toList();

      // sort by email for dropdown UX
      list.sort((a, b) {
        final aKey = a.displayName.isNotEmpty ? a.displayName : a.email;
        final bKey = b.displayName.isNotEmpty ? b.displayName : b.email;
        return aKey.toLowerCase().compareTo(bKey.toLowerCase());
      });
      return list;
    });
  }
}
