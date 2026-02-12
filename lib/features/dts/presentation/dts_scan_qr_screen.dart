import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../data/dts_repository.dart';
import 'dts_create_document_screen.dart';
import 'dts_document_detail_screen.dart';

class DtsScanQrScreen extends StatefulWidget {
  const DtsScanQrScreen({super.key});

  @override
  State<DtsScanQrScreen> createState() => _DtsScanQrScreenState();
}

class _DtsScanQrScreenState extends State<DtsScanQrScreen> {
  final _repo = DtsRepository();
  final _controller = MobileScannerController();
  bool _handling = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleScan(String qrCode) async {
    if (_handling) return;
    setState(() {
      _handling = true;
      _error = null;
    });
    await _controller.stop();
    try {
      final docId = await _repo.resolveDocIdForQr(qrCode);
      if (!mounted) return;
      if (docId != null) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DtsDocumentDetailScreen(docId: docId),
          ),
        );
      } else {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DtsCreateDocumentScreen(qrCode: qrCode),
          ),
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
