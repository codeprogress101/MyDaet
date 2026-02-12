import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/dts_repository.dart';
import '../domain/dts_tracking_result.dart';
import 'dts_status.dart';

class DtsTrackDocumentScreen extends StatefulWidget {
  const DtsTrackDocumentScreen({super.key});

  @override
  State<DtsTrackDocumentScreen> createState() =>
      _DtsTrackDocumentScreenState();
}

class _DtsTrackDocumentScreenState extends State<DtsTrackDocumentScreen> {
  final _repo = DtsRepository();
  final _trackingNo = TextEditingController();
  final _pin = TextEditingController();
  bool _loading = false;
  String _status = '';
  DtsTrackingResult? _result;

  @override
  void dispose() {
    _trackingNo.dispose();
    _pin.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    final tracking = _trackingNo.text.trim();
    final pin = _pin.text.trim();
    if (tracking.isEmpty || pin.isEmpty) {
      setState(() => _status = 'Tracking number and PIN are required.');
      return;
    }
    setState(() {
      _loading = true;
      _status = 'Checking...';
      _result = null;
    });
    try {
      final result = await _repo.trackByTrackingNo(
        trackingNo: tracking,
        pin: pin,
      );
      setState(() {
        _result = result;
        _status = '';
      });
    } catch (e) {
      setState(() => _status = 'Lookup failed: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  InputDecoration _inputDecoration(
    BuildContext context,
    String label,
    IconData icon,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final border = Theme.of(context).dividerColor;
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: scheme.primary),
      filled: true,
      fillColor: scheme.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.primary, width: 1.3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final textTheme = GoogleFonts.poppinsTextTheme(baseTheme.textTheme);
    final scheme = baseTheme.colorScheme;

    return Theme(
      data: baseTheme.copyWith(textTheme: textTheme),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('Track Document'),
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          foregroundColor: scheme.onSurface,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _trackingNo,
              decoration:
                  _inputDecoration(context, 'Tracking number', Icons.qr_code),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pin,
              keyboardType: TextInputType.number,
              obscureText: true,
              decoration: _inputDecoration(context, 'PIN', Icons.lock_outline),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: _loading ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.primary,
                  foregroundColor: scheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _loading
                    ? SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: scheme.onPrimary,
                        ),
                      )
                    : const Text('Track'),
              ),
            ),
            const SizedBox(height: 12),
            if (_status.isNotEmpty)
              Text(
                _status,
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            if (_result != null) ...[
              const SizedBox(height: 16),
              _TrackingResultCard(result: _result!),
            ],
          ],
        ),
      ),
    );
  }
}

class _TrackingResultCard extends StatelessWidget {
  const _TrackingResultCard({required this.result});

  final DtsTrackingResult result;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final border = Theme.of(context).dividerColor;
    final statusColor = DtsStatusHelper.color(context, result.status);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        color: scheme.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            result.trackingNo,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          if (result.title != null) ...[
            const SizedBox(height: 4),
            Text(
              result.title!,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: 8),
          _StatusChip(label: DtsStatusHelper.label(result.status), color: statusColor),
          const SizedBox(height: 8),
          if (result.currentOfficeName != null)
            Text(
              'Current office: ${result.currentOfficeName}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.7),
                  ),
            ),
          if (result.instructions != null) ...[
            const SizedBox(height: 6),
            Text(
              result.instructions!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.7),
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
