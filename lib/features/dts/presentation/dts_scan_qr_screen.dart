import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../services/permissions.dart';
import '../../../services/user_context_service.dart';
import '../data/dts_repository.dart';
import '../domain/dts_document.dart';
import 'dts_create_document_screen.dart';
import 'dts_document_detail_screen.dart';

class DtsScanQrScreen extends StatefulWidget {
  const DtsScanQrScreen({super.key});

  @override
  State<DtsScanQrScreen> createState() => _DtsScanQrScreenState();
}

class _DtsScanQrScreenState extends State<DtsScanQrScreen> {
  final _repo = DtsRepository();
  final _userContextService = UserContextService();
  final _controller = MobileScannerController();
  late final Future<UserContext?> _contextFuture;
  bool _handling = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _contextFuture = _userContextService.getCurrent();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _canReceiveTransfer(
    UserContext userContext,
    DtsPendingTransfer pending,
  ) {
    final officeIdMatch =
        userContext.officeId != null &&
        userContext.officeId == pending.toOfficeId;
    final officeNameMatch =
        userContext.officeName != null &&
        pending.toOfficeName != null &&
        userContext.officeName!.trim().toLowerCase() ==
            pending.toOfficeName!.trim().toLowerCase();
    final recipientMatch =
        pending.toUid != null && pending.toUid == userContext.uid;
    return officeIdMatch || officeNameMatch || recipientMatch;
  }

  Future<bool> _blockedByWrongReceivingOffice(String docId) async {
    final messenger = ScaffoldMessenger.of(context);
    final userContext = await _contextFuture;
    if (userContext == null ||
        !userContext.isStaff ||
        userContext.isSuperAdmin) {
      return false;
    }

    final snap = await FirebaseFirestore.instance
        .collection('dts_documents')
        .doc(docId)
        .get();
    if (!snap.exists) return false;

    final doc = DtsDocument.fromDoc(snap);
    final pending = doc.pendingTransfer;
    if (pending == null) return false;
    if (_canReceiveTransfer(userContext, pending)) return false;

    if (mounted) {
      final officeLabel = pending.toOfficeName ?? pending.toOfficeId;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'This transfer is for $officeLabel. Please forward it to the correct office.',
          ),
        ),
      );
    }
    return true;
  }

  Future<void> _handleScan(String qrCode) async {
    if (_handling) return;
    final navigator = Navigator.of(context);
    setState(() {
      _handling = true;
      _error = null;
    });
    await _controller.stop();
    try {
      final docId = await _repo.resolveDocIdForQr(qrCode);
      if (!mounted) return;
      if (docId != null) {
        final blocked = await _blockedByWrongReceivingOffice(docId);
        if (blocked) return;
        await navigator.push(
          MaterialPageRoute(
            builder: (_) => DtsDocumentDetailScreen(docId: docId),
          ),
        );
      } else {
        await navigator.push(
          MaterialPageRoute(
            builder: (_) => DtsCreateDocumentScreen(qrCode: qrCode),
          ),
        );
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        final isPermissionIssue =
            e.code == 'permission-denied' || e.code == 'unauthenticated';
        setState(
          () => _error = isPermissionIssue
              ? 'You cannot access this document. It may belong to another office.'
              : 'Scan failed: ${e.message ?? e.code}',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Scan failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _handling = false);
        await _controller.start();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
              if (_handling) return;
              if (capture.barcodes.isEmpty) return;
              final barcode = capture.barcodes.first;
              final value = barcode.rawValue ?? barcode.displayValue;
              if (value == null || value.trim().isEmpty) return;
              _handleScan(value.trim());
            },
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Column(
              children: [
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: scheme.primary.withValues(alpha: 0.6),
                      ),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.25),
                    ),
                  ),
                  child: const Text(
                    'Align the QR sticker inside the frame.',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
