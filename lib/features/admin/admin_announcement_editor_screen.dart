import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/announcements_service.dart';

class AdminAnnouncementEditorScreen extends StatefulWidget {
  const AdminAnnouncementEditorScreen({
    super.key,
    this.announcementId,
    this.initialData,
  });

  final String? announcementId;
  final Map<String, dynamic>? initialData;

  @override
  State<AdminAnnouncementEditorScreen> createState() =>
      _AdminAnnouncementEditorScreenState();
}

class _AdminAnnouncementEditorScreenState
    extends State<AdminAnnouncementEditorScreen> {
  final _service = AnnouncementsService();
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _meta = TextEditingController();

  bool _loading = false;
  String _status = 'draft';
  String _category = 'General';
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
      _status = (data['status'] ?? 'draft').toString();
      _category = (data['category'] ?? 'General').toString();
      _existingMedia = data['media'] as Map<String, dynamic>?;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _meta.dispose();
    super.dispose();
  }

  Future<void> _pickMedia() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
      allowMultiple: false,
      withData: false,
    );
    if (res == null || res.files.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No image selected.')),
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
      if (widget.announcementId == null) {
        await _service.createAnnouncement(
          title: _title.text,
          body: _body.text,
          meta: _meta.text,
          status: _status,
          category: _category,
          mediaFile: _mediaFile,
        );
      } else {
        await _service.updateAnnouncement(
          announcementId: widget.announcementId!,
          title: _title.text,
          body: _body.text,
          meta: _meta.text,
          status: _status,
          category: _category,
          mediaFile: _mediaFile,
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
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.onSurface;
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
          title: Text(
            widget.announcementId == null
                ? 'New Announcement'
                : 'Edit Announcement',
          ),
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
              maxLines: 5,
              decoration: inputDecoration('Description', Icons.description),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _meta,
              decoration: inputDecoration('Meta (location/date)', Icons.info_outline),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'General', child: Text('General')),
                DropdownMenuItem(value: 'Advisory', child: Text('Advisory')),
                DropdownMenuItem(value: 'Event', child: Text('Event')),
                DropdownMenuItem(value: 'Notice', child: Text('Notice')),
              ],
              onChanged: (v) => setState(() => _category = v ?? _category),
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
            if (_existingMedia != null && _mediaFile == null && !_removeMedia)
              _MediaPreview(media: _existingMedia!),
            if (_mediaFile != null) ...[
              const SizedBox(height: 8),
              _SelectedPreview(file: _mediaFile!),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickMedia,
                    icon: const Icon(Icons.upload_file, color: accent),
                    label: const Text('Select Image'),
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
                    : const Text('Save Announcement'),
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
    final url = (media['url'] ?? '').toString();

    if (url.isEmpty) {
      return Container(
        height: 160,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
          color: Theme.of(context).colorScheme.surface,
        ),
        child: const Center(
          child: Icon(Icons.image, color: accent, size: 42),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.network(
        url,
        height: 160,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _fallback(context),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return _fallback(context);
        },
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

class _SelectedPreview extends StatelessWidget {
  const _SelectedPreview({required this.file});

  final PlatformFile file;

  @override
  Widget build(BuildContext context) {
    final path = file.path;
    if (path == null) {
      return Text(
        'Selected: ${file.name}',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.file(
        File(path),
        height: 160,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Text(
          'Selected: ${file.name}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }
}
