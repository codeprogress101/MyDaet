import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AdminUsersScreen extends StatelessWidget {
  const AdminUsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? "";

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection("users")
          .orderBy("email")
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text("Error: ${snap.error}"));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Text("No users found."));
        }

        final myRole = () {
          for (final d in docs) {
            if (d.id == myUid) {
              return (d.data()["role"] ?? "resident") as String;
            }
          }
          return "resident";
        }();

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final d = docs[i];
            final data = d.data();
            final email = (data["email"] ?? "(no email)") as String;
            final displayName = (data["displayName"] ?? "").toString();
            final role = (data["role"] ?? "resident") as String;
            final isTargetSuperAdmin = role == "super_admin";

            return Card(
              child: ListTile(
                title: Text(displayName.isNotEmpty ? displayName : email),
                subtitle: Text("Email: $email\nRole: $role\nUID: ${d.id}"),
                trailing: myRole == "super_admin" && !isTargetSuperAdmin
                    ? DropdownButton<String>(
                        value: role,
                        items: const [
                          DropdownMenuItem(value: "resident", child: Text("resident")),
                          DropdownMenuItem(value: "moderator", child: Text("moderator")),
                          DropdownMenuItem(value: "admin", child: Text("admin")),
                          DropdownMenuItem(value: "super_admin", child: Text("super_admin")),
                        ],
                        onChanged: (v) async {
                          if (v == null || v == role) return;
                          try {
                            await d.reference.update({"role": v});
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Role updated to $v")),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Update failed: $e")),
                              );
                            }
                          }
                        },
                      )
                    : null,
              ),
            );
          },
        );
      },
    );
  }
}
