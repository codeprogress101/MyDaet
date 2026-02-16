import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../shared/timezone_utils.dart';
import '../data/dts_repository.dart';
import '../domain/dts_tracking_result.dart';
import 'dts_status.dart';

class DtsTrackDocumentScreen extends StatefulWidget {
  const DtsTrackDocumentScreen({super.key});

  @override
  State<DtsTrackDocumentScreen> createState() => _DtsTrackDocumentScreenState();
}

class _DtsTrackDocumentScreenState extends State<DtsTrackDocumentScreen> {
  final _repo = DtsRepository();
  final _trackingNo = TextEditingController();
  final _pin = TextEditingController();
  final _imagePicker = ImagePicker();
  final _imageAnalyzer = MobileScannerController(
    autoStart: false,
    formats: const [BarcodeFormat.qrCode],
  );
  bool _loading = false;
  bool _savingToAccount = false;
  bool _savedToAccount = false;
  String _status = '';
  String _saveStatus = '';
  DtsTrackingResult? _result;
  String? _lastTrackingNo;
  String? _lastPin;
  String? _sessionToken;
  DateTime? _sessionExpiresAt;

  @override
  void dispose() {
    _imageAnalyzer.dispose();
    _trackingNo.dispose();
    _pin.dispose();
    super.dispose();
  }

  void _applyTrackingResult(DtsTrackingResult result, {String? pin}) {
    setState(() {
      _result = result;
      _trackingNo.text = result.trackingNo;
      _lastTrackingNo = result.trackingNo;
      _lastPin = pin ?? _lastPin;
      _sessionToken = result.sessionToken;
      _sessionExpiresAt = result.sessionExpiresAt;
      _status = '';
    });
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
      _saveStatus = '';
      _savedToAccount = false;
      _result = null;
    });
    try {
      final result = await _repo.trackByTrackingNo(
        trackingNo: tracking,
        pin: pin,
      );
      _applyTrackingResult(result, pin: pin);
    } catch (e) {
      var message = 'Unable to track document right now.';
      if (e is FirebaseFunctionsException) {
        if (e.code == 'permission-denied') {
          message = 'Invalid PIN. Please try again.';
        } else if (e.code == 'resource-exhausted') {
          message = e.message ?? 'Too many failed attempts. Try again later.';
        } else if (e.code == 'not-found') {
          message = 'Document not found.';
        } else {
          message = e.message ?? message;
        }
      }
      setState(() => _status = message);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _trackByQrCode(String qrCode) async {
    if (_loading) return;
    final pin = _pin.text.trim();
    if (pin.isEmpty) {
      setState(() => _status = 'Enter PIN first, then scan/upload QR.');
      return;
    }

    setState(() {
      _loading = true;
      _status = 'Checking QR...';
      _saveStatus = '';
      _savedToAccount = false;
      _result = null;
    });
    try {
      final result = await _repo.trackByQrAndPin(qrCode: qrCode, pin: pin);
      _applyTrackingResult(result, pin: pin);
    } catch (e) {
      var message = 'Unable to track document from QR right now.';
      if (e is FirebaseFunctionsException) {
        if (e.code == 'permission-denied') {
          message = 'Invalid PIN. Please try again.';
        } else if (e.code == 'resource-exhausted') {
          message = e.message ?? 'Too many failed attempts. Try again later.';
        } else if (e.code == 'not-found') {
          message = 'Document not found for this QR.';
        } else {
          message = e.message ?? message;
        }
      }
      setState(() => _status = message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _scanQrWithCamera() async {
    final value = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const _ResidentQrScannerPage()),
    );
    if (!mounted || value == null || value.trim().isEmpty) return;
    final scanned = value.trim();
    if (scanned.toUpperCase().startsWith('DTS-QR-')) {
      await _trackByQrCode(scanned);
      return;
    }
    _trackingNo.text = scanned;
    await _submit();
  }

  Future<void> _uploadQrImage() async {
    final picked = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    try {
      final capture = await _imageAnalyzer.analyzeImage(picked.path);
      if (!mounted) return;
      if (capture == null || capture.barcodes.isEmpty) {
        setState(() => _status = 'No QR found in selected image.');
        return;
      }
      final barcode = capture.barcodes.first;
      final raw = (barcode.rawValue ?? barcode.displayValue ?? '').trim();
      if (raw.isEmpty) {
        setState(() => _status = 'No QR found in selected image.');
        return;
      }
      if (raw.toUpperCase().startsWith('DTS-QR-')) {
        await _trackByQrCode(raw);
        return;
      }
      _trackingNo.text = raw;
      await _submit();
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Unable to read QR image: $e');
    }
  }

  Future<void> _saveToMyDocuments() async {
    if (_savingToAccount) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _saveStatus = 'Please sign in first.';
      });
      return;
    }
    final trackingNo = _lastTrackingNo ?? _trackingNo.text.trim();
    final pin = _lastPin ?? _pin.text.trim();
    if (trackingNo.isEmpty) {
      setState(() {
        _saveStatus = 'Tracking number is required.';
      });
      return;
    }
    final hasValidSession =
        _sessionToken != null &&
        _sessionToken!.trim().isNotEmpty &&
        _sessionExpiresAt != null &&
        _sessionExpiresAt!.isAfter(DateTime.now());
    if (!hasValidSession && pin.isEmpty) {
      setState(() {
        _saveStatus = 'PIN is required because tracking session expired.';
      });
      return;
    }

    setState(() {
      _savingToAccount = true;
      _saveStatus = 'Saving to your account...';
    });

    try {
      await _repo.saveTrackedDocumentToAccount(
        trackingNo: trackingNo,
        pin: hasValidSession ? null : pin,
        sessionToken: hasValidSession ? _sessionToken : null,
      );
      setState(() {
        _savedToAccount = true;
        _saveStatus = 'Saved. You can now view it in My Documents.';
      });
    } catch (e) {
      String message = 'Unable to save document right now.';
      if (e is FirebaseFunctionsException) {
        if (e.code == 'failed-precondition') {
          message = 'This document is already linked to another account.';
        } else if (e.code == 'permission-denied') {
          message = 'Invalid PIN. Please try again.';
        } else if (e.code == 'not-found') {
          message = 'Document not found.';
        } else {
          message = e.message ?? message;
        }
      }
      setState(() {
        _saveStatus = message;
      });
    } finally {
      setState(() => _savingToAccount = false);
    }
  }

  Future<void> _refreshUsingSession() async {
    final token = _sessionToken;
    if (token == null || token.trim().isEmpty) {
      setState(() => _status = 'Tracking session expired. Re-enter PIN.');
      return;
    }
    if (_loading) return;
    setState(() {
      _loading = true;
      _status = 'Refreshing...';
    });
    try {
      final refreshed = await _repo.trackBySessionToken(sessionToken: token);
      setState(() {
        _result = refreshed;
        _sessionToken = refreshed.sessionToken;
        _sessionExpiresAt = refreshed.sessionExpiresAt;
        _status = '';
      });
    } catch (e) {
      setState(() {
        _status = 'Session expired. Please re-enter tracking PIN.';
      });
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
    final signedIn = FirebaseAuth.instance.currentUser != null;

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
              decoration: _inputDecoration(
                context,
                'Tracking number',
                Icons.qr_code,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pin,
              keyboardType: TextInputType.number,
              obscureText: true,
              decoration: _inputDecoration(context, 'PIN', Icons.lock_outline),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _loading ? null : _scanQrWithCamera,
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Scan QR'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _loading ? null : _uploadQrImage,
                    icon: const Icon(Icons.image_search),
                    label: const Text('Upload QR'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Security: QR scan/upload still requires PIN verification.',
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.65),
              ),
            ),
            const SizedBox(height: 12),
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
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _loading ? null : _refreshUsingSession,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh using secure token'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 46,
                child: OutlinedButton.icon(
                  onPressed: _savingToAccount || _savedToAccount || !signedIn
                      ? null
                      : _saveToMyDocuments,
                  icon: Icon(
                    _savedToAccount ? Icons.check_circle : Icons.bookmark_add,
                  ),
                  label: Text(
                    !signedIn
                        ? 'Sign in to save'
                        : _savedToAccount
                        ? 'Saved to My Documents'
                        : (_savingToAccount
                              ? 'Saving...'
                              : 'Save to My Documents'),
                  ),
                ),
              ),
              if (_saveStatus.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  _saveStatus,
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
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
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (result.title != null) ...[
            const SizedBox(height: 4),
            Text(result.title!, style: Theme.of(context).textTheme.bodyMedium),
          ],
          const SizedBox(height: 8),
          _StatusChip(
            label: DtsStatusHelper.label(result.status),
            color: statusColor,
          ),
          const SizedBox(height: 8),
          if (result.currentOfficeName != null)
            Text(
              'Current office: ${result.currentOfficeName}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          if (result.lastUpdated != null) ...[
            const SizedBox(height: 6),
            Text(
              'Last updated: ${formatManilaDateTime(result.lastUpdated!, includeZone: true)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
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

class _ResidentQrScannerPage extends StatefulWidget {
  const _ResidentQrScannerPage();

  @override
  State<_ResidentQrScannerPage> createState() => _ResidentQrScannerPageState();
}

class _ResidentQrScannerPageState extends State<_ResidentQrScannerPage> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );
  bool _detected = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan QR'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              if (_detected || capture.barcodes.isEmpty) return;
              final barcode = capture.barcodes.first;
              final value = (barcode.rawValue ?? barcode.displayValue ?? '')
                  .trim();
              if (value.isEmpty) return;
              _detected = true;
              Navigator.of(context).pop(value);
            },
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Align the DTS QR sticker within the frame.',
                style: TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
