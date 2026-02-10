import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/ads_service.dart';
import '../shared/widgets/network_video_player.dart';

class AdminAdvertisementEditorScreen extends StatefulWidget {
  const AdminAdvertisementEditorScreen({
    super.key,
    this.adId,
    this.initialData,
  });

  final String? adId;
  final Map<String, dynamic>? initialData;

  @override
  State<AdminAdvertisementEditorScreen> createState() =>
      _AdminAdvertisementEditorScreenState();
}

class _AdminAdvertisementEditorScreenState
    extends State<AdminAdvertisementEditorScreen> {
  final _adsService = AdsService();
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _meta = TextEditingController();
  final _cta = TextEditingController();
  final _ctaUrl = TextEditingController();

  bool _loading = false;
  String _status = 'draft';
  String _mediaType = 'none';
  PlatformFile? _mediaFile;
  Map<String, dynamic>? _existingMedia;
  bool _removeMedia = false;

  @override
  void initState() {
    super.initState();
    final data = widget.initialData;
    if (data != null) {
      _title.text = (data['title'] ?? '').toString();
      _body.text = (data['body'] ?? '').toString();
      _meta.text = (data['meta'] ?? '').toString();
      _cta.text = (data['cta'] ?? '').toString();
      _ctaUrl.text = (data['ctaUrl'] ?? '').toString();
      _status = (data['status'] ?? 'draft').toString();
      _existingMedia = data['media'] as Map<String, dynamic>?;
      if (_existingMedia != null) {
        _mediaType = (_existingMedia!['type'] ?? 'none').toString();
      }
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _meta.dispose();
    _cta.dispose();
    _ctaUrl.dispose();
    super.dispose();
  }

  Future<void> _pickMedia() async {
    if (_mediaType == 'none') return;

    final allowedExtensions = _mediaType == 'image'
        ? ['jpg', 'jpeg', 'png', 'webp']
        : ['mp4', 'mov', 'mkv', 'webm'];
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
      allowMultiple: false,
      withData: false,
    );
    if (res == null || res.files.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No media selected. If the picker is empty, add a file to the emulator '
            'Downloads folder or try a physical device.',
          ),
        ),
      );
      return;
    }
    setState(() {
      _mediaFile = res.files.first;
      _removeMedia = false;
    });
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty || _body.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and description are required.')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      if (widget.adId == null) {
        await _adsService.createAd(
          title: _title.text,
          body: _body.text,
          meta: _meta.text,
          cta: _cta.text.isEmpty ? 'View' : _cta.text,
          ctaUrl: _ctaUrl.text,
          status: _status,
          mediaFile: _mediaFile,
          mediaType: _mediaType == 'none' ? null : _mediaType,
        );
      } else {
        await _adsService.updateAd(
          adId: widget.adId!,
          title: _title.text,
          body: _body.text,
          meta: _meta.text,
          cta: _cta.text.isEmpty ? 'View' : _cta.text,
          ctaUrl: _ctaUrl.text,
          status: _status,
          mediaFile: _mediaFile,
          mediaType: _mediaType == 'none' ? null : _mediaType,
          existingMediaPath: (_existingMedia?['path'] ?? '').toString(),
          removeMedia: _removeMedia,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final textTheme = GoogleFonts.poppinsTextTheme(baseTheme.textTheme);
    final dark = Theme.of(context).colorScheme.onSurface;
    const accent = Color(0xFFE46B2C);
    final border = Theme.of(context).dividerColor;

    InputDecoration inputDecoration(String label, IconData icon) {
      return InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: accent),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
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
          borderSide: const BorderSide(color: accent, width: 1.3),
        ),
      );
    }

    return Theme(
      data: baseTheme.copyWith(textTheme: textTheme),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(widget.adId == null ? 'New Advertisement' : 'Edit Ad'),
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          foregroundColor: dark,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _title,
              decoration: inputDecoration('Title', Icons.title),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _body,
              maxLines: 4,
              decoration: inputDecoration('Description', Icons.description),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _meta,
              decoration: inputDecoration('Meta (location/date)', Icons.info_outline),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _cta,
              decoration: inputDecoration('CTA Button Label', Icons.ads_click),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ctaUrl,
              keyboardType: TextInputType.url,
              decoration: inputDecoration('CTA URL (optional)', Icons.link),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'draft', child: Text('Draft')),
                DropdownMenuItem(value: 'published', child: Text('Published')),
              ],
              onChanged: (v) => setState(() => _status = v ?? _status),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _mediaType,
              decoration: const InputDecoration(
                labelText: 'Media Type',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'none', child: Text('None')),
                DropdownMenuItem(value: 'image', child: Text('Image')),
                DropdownMenuItem(value: 'video', child: Text('Video')),
              ],
              onChanged: (v) {
                final next = v ?? 'none';
                setState(() {
                  _mediaType = next;
                  if (next == 'none') {
                    _mediaFile = null;
                    _removeMedia = _existingMedia != null;
                  } else {
                    _removeMedia = false;
                  }
                });
              },
            ),
            const SizedBox(height: 10),
            if (_existingMedia != null && _mediaFile == null && !_removeMedia)
              _MediaPreview(
                media: _existingMedia!,
              ),
            if (_mediaFile != null) ...[
              const SizedBox(height: 8),
              Text(
                'Selected: ${_mediaFile!.name}',
                style: textTheme.bodySmall?.copyWith(
                  color: dark.withOpacity(0.7),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _mediaType == 'none' ? null : _pickMedia,
                    icon: const Icon(Icons.upload_file, color: accent),
                    label: const Text('Select Media'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: dark,
                      side: BorderSide(color: border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                if (_existingMedia != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _removeMedia = true;
                          _mediaFile = null;
                          _mediaType = 'none';
                        });
                      },
                      icon: const Icon(Icons.delete_outline, color: accent),
                      label: const Text('Remove'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: dark,
                        side: BorderSide(color: border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: _loading ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _loading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save Advertisement'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaPreview extends StatelessWidget {
  const _MediaPreview({required this.media});

  final Map<String, dynamic> media;

  @override
  Widget build(BuildContext context) {
    final border = Theme.of(context).dividerColor;
    const accent = Color(0xFFE46B2C);
    final type = (media['type'] ?? '').toString();
    final url = (media['url'] ?? '').toString();

    if (type == 'image' && url.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.network(
          url,
          height: 160,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback(context),
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return _fallback(context);
          },
        ),
      );
    }

    if (type == 'video' && url.isNotEmpty) {
      return NetworkVideoPlayer(
        url: url,
        height: 160,
        borderRadius: 16,
      );
    }

    return Container(
      height: 160,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        color: Theme.of(context).colorScheme.surface,
      ),
      child: const Center(
        child: Icon(Icons.play_circle, color: accent, size: 42),
      ),
    );
  }

  Widget _fallback(BuildContext context) {
    final border = Theme.of(context).dividerColor;
    return Container(
      height: 160,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        color: Theme.of(context).colorScheme.surface,
      ),
      child: const Center(child: Icon(Icons.image, color: Colors.black45)),
    );
  }
}
