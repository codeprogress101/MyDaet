import 'package:flutter/material.dart';

class SimpleInfoScreen extends StatelessWidget {
  final String title;
  final String body;

  const SimpleInfoScreen({super.key, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(body),
      ),
    );
  }
}
