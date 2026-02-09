import 'package:cloud_firestore/cloud_firestore.dart';

class UserDirectoryItem {
  final String uid;
  final String email;
  final String role;
  final String displayName;

  const UserDirectoryItem({
    required this.uid,
    required this.email,
    required this.role,
    required this.displayName,
  });
}

class UserDirectoryService {
  final _db = FirebaseFirestore.instance;

  Stream<List<UserDirectoryItem>> watchAssignableUsers() {
    // Users that can be assigned to handle reports
    // NOTE: Firestore "in" supports up to 10 values
    return _db
        .collection("users")
        .where("role", whereIn: ["moderator", "admin", "super_admin"])
        .snapshots()
        .map((snap) {
      final list = snap.docs.map((d) {
        final data = d.data();
        return UserDirectoryItem(
          uid: d.id,
          email: (data["email"] ?? "").toString(),
          role: (data["role"] ?? "resident").toString(),
          displayName: (data["displayName"] ?? "").toString(),
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
