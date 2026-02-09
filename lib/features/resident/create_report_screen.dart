import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';

import 'daet_geo.dart';
import 'location_picker_screen.dart';
import 'picked_location.dart';

class CreateReportScreen extends StatefulWidget {
  const CreateReportScreen({super.key});

  @override
  State<CreateReportScreen> createState() => _CreateReportScreenState();
}

class _CreateReportScreenState extends State<CreateReportScreen> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _contact = TextEditingController();

  final _categories = const [
    'Solid Waste',
    'Road/Traffic',
    'Streetlight',
    'Peace & Order',
    'Health',
    'Others',
  ];

  String _category = 'Solid Waste';
  bool _loading = false;
  String _status = '';

  double? _lat;
  double? _lng;
  String? _address;

  final List<PlatformFile> _files = [];

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _contact.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    final res = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: false,
      type: FileType.any,
    );
    if (res == null) return;

    setState(() {
      _files.addAll(res.files.where((f) => f.path != null));
    });
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _status = 'Checking location permissions...');
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      setState(() => _status = 'Location services disabled.');
      return;
    }

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      setState(() => _status = 'Location permission denied.');
      return;
    }

    setState(() => _status = 'Getting GPS location...');
    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    if (!isWithinDaet(pos.latitude, pos.longitude)) {
      setState(() {
        _lat = null;
        _lng = null;
        _address = null;
        _status = 'Location is outside Daet, Camarines Norte.';
      });
      return;
    }

    setState(() {
      _lat = pos.latitude;
      _lng = pos.longitude;
      _address = null;
    });

    await _reverseGeocode();
  }

  Future<void> _reverseGeocode() async {
    if (_lat == null || _lng == null) return;
    try {
      final placemarks = await placemarkFromCoordinates(_lat!, _lng!);
      if (placemarks.isEmpty) return;

      final p = placemarks.first;
      final s = [
        if ((p.street ?? '').trim().isNotEmpty) p.street,
        if ((p.subLocality ?? '').trim().isNotEmpty) p.subLocality,
        if ((p.locality ?? '').trim().isNotEmpty) p.locality,
        if ((p.administrativeArea ?? '').trim().isNotEmpty)
          p.administrativeArea,
      ].whereType<String>().join(', ');

      setState(() => _address = s);
    } catch (_) {
      // ignore reverse geocode failures
    }
  }

  Future<void> _pickOnMap() async {
    final picked = await Navigator.of(context).push<PickedLocation>(
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          initialLat: _lat,
          initialLng: _lng,
        ),
      ),
    );
    if (picked == null) return;

    if (!isWithinDaet(picked.lat, picked.lng)) {
      setState(() => _status = 'Location must be within Daet, Camarines Norte.');
      return;
    }

    setState(() {
      _lat = picked.lat;
      _lng = picked.lng;
      _address = null;
    });

    await _reverseGeocode();
  }

  Future<List<Map<String, dynamic>>> _uploadAttachments(String reportId) async {
    if (_files.isEmpty) return [];

    final uid = FirebaseAuth.instance.currentUser!.uid;
    final List<Map<String, dynamic>> uploaded = [];

    for (final f in _files) {
      final path = f.path;
      if (path == null) continue;

      final file = File(path);
      final fileName = f.name;

      final storagePath = 'reports/$uid/$reportId/$fileName';
      final ref = FirebaseStorage.instance.ref(storagePath);

      final task = await ref.putFile(file);
      final url = await task.ref.getDownloadURL();

      uploaded.add({
        'name': fileName,
        'path': storagePath,
        'url': url,
        'size': f.size,
        'contentType': task.metadata?.contentType,
        'uploadedAt': Timestamp.now(),
      });
    }

    return uploaded;
  }

  Future<void> _submit() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _status = 'Please login first.');
      return;
    }

    if (_title.text.trim().isEmpty || _desc.text.trim().isEmpty) {
      setState(() => _status = 'Title and description are required.');
      return;
    }

    if (_lat == null || _lng == null) {
      setState(() => _status = 'Please add location (GPS or Map Pin).');
      return;
    }

    setState(() {
      _loading = true;
      _status = 'Submitting report...';
    });

    try {
      final reports = FirebaseFirestore.instance.collection('reports');
      final doc = reports.doc();
      final reportId = doc.id;

      setState(() => _status = 'Uploading attachments...');
      final attachments = await _uploadAttachments(reportId);

      setState(() => _status = 'Saving report...');
      await doc.set({
        'title': _title.text.trim(),
        'description': _desc.text.trim(),
        'category': _category,
        'status': 'submitted',
        'createdByUid': user.uid,
        'createdByEmail': user.email,
        'createdByName': user.displayName,
        'contactNumber':
            _contact.text.trim().isEmpty ? null : _contact.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'location': {
          'lat': _lat,
          'lng': _lng,
          'address': _address,
        },
        'attachments': attachments,
        'assignedToUid': null,
        'assignedToEmail': null,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report submitted.')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      setState(() => _status = 'Submit failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasLoc = _lat != null && _lng != null;
    final baseTheme = Theme.of(context);
    final textTheme = GoogleFonts.poppinsTextTheme(baseTheme.textTheme);
    const accent = Color(0xFFE46B2C);
    final dark = Theme.of(context).colorScheme.onSurface;
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
          title: const Text('Create Report'),
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          foregroundColor: dark,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<String>(
              value: _category,
              items: _categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: _loading
                  ? null
                  : (v) => setState(() => _category = v ?? _category),
              decoration: inputDecoration('Category', Icons.category_outlined),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              enabled: !_loading,
              decoration: inputDecoration('Title', Icons.title),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _desc,
              enabled: !_loading,
              maxLines: 5,
              decoration: inputDecoration('Description', Icons.description),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contact,
              enabled: !_loading,
              keyboardType: TextInputType.phone,
              decoration: inputDecoration('Contact Number', Icons.phone),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _loading ? null : _getCurrentLocation,
                    icon: const Icon(Icons.my_location, color: accent),
                    label: const Text('Use GPS'),
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
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _loading ? null : _pickOnMap,
                    icon: const Icon(Icons.location_pin, color: accent),
                    label: const Text('Map Pin'),
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
            const SizedBox(height: 10),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: border),
              ),
              child: ListTile(
                leading: Icon(
                  hasLoc ? Icons.check_circle : Icons.info_outline,
                  color: hasLoc ? accent : dark,
                ),
                title: Text(hasLoc ? 'Location added' : 'No location yet'),
                subtitle: Text(
                  hasLoc
                      ? '${_lat!.toStringAsFixed(6)}, ${_lng!.toStringAsFixed(6)}\n${_address ?? 'Address lookup pending...'}'
                      : 'Required: tag location using GPS or map pin.',
                ),
                isThreeLine: true,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _loading ? null : _pickFiles,
              icon: const Icon(Icons.attach_file, color: accent),
              label: const Text('Add Attachment'),
              style: OutlinedButton.styleFrom(
                foregroundColor: dark,
                side: BorderSide(color: border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (_files.isEmpty)
              Text(
                'No attachments yet (optional).',
                style: textTheme.bodySmall?.copyWith(
                  color: dark.withOpacity(0.7),
                ),
              )
            else
              ..._files.map(
                (f) => Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: border),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.insert_drive_file_outlined),
                    title: Text(f.name),
                    subtitle:
                        Text('${(f.size / 1024).toStringAsFixed(1)} KB'),
                    trailing: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed:
                          _loading ? null : () => setState(() => _files.remove(f)),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: _loading ? null : _submit,
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
                    : const Text('Submit Report'),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _status,
              style: textTheme.bodySmall?.copyWith(
                color: dark.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
