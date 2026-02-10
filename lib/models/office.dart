import 'package:cloud_firestore/cloud_firestore.dart';

class Office {
  final String id;
  final String name;
  final bool isActive;

  const Office({
    required this.id,
    required this.name,
    this.isActive = true,
  });

  factory Office.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final name = (data['name'] ?? doc.id).toString();
    final isActive =
        data['isActive'] is bool ? data['isActive'] as bool : true;
    return Office(
      id: doc.id,
      name: name,
      isActive: isActive,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'isActive': isActive,
    };
  }
}
