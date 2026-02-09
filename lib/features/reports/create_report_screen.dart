import 'package:flutter/material.dart';
import '../../services/reports_service.dart';

class CreateReportScreen extends StatefulWidget {
  const CreateReportScreen({super.key});

  @override
  State<CreateReportScreen> createState() => _CreateReportScreenState();
}

class _CreateReportScreenState extends State<CreateReportScreen> {
  final _service = ReportsService();
  final _title = TextEditingController();
  final _desc = TextEditingController();

  bool _submitting = false;
  String _msg = 'Ready';

  Future<void> _submit() async {
    final t = _title.text.trim();
    final d = _desc.text.trim();

    if (t.isEmpty || d.isEmpty) {
      setState(() => _msg = 'Please fill in title and description.');
      return;
    }

    setState(() {
      _submitting = true;
      _msg = 'Submitting...';
    });

    try {
      final id = await _service.createReport(title: t, description: d);
      setState(() => _msg = '✅ Report created: $id');

      if (!mounted) return;
      Navigator.pop(context, true); // return "created"
    } catch (e) {
      setState(() => _msg = '❌ Failed: $e');
    } finally {
      setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Report')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _desc,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: Text(_submitting ? 'Submitting...' : 'Submit Report'),
            ),
            const SizedBox(height: 12),
            Text(_msg),
          ],
        ),
      ),
    );
  }
}
