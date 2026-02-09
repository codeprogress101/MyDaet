import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '/services/claims_service.dart';
import '/services/notification_service.dart';
import '/services/theme_controller.dart';

class _AccountPalette {
  const _AccountPalette({
    required this.bg,
    required this.card,
    required this.border,
    required this.title,
    required this.body,
    required this.subtitle,
    required this.iconBg,
    required this.iconFg,
    required this.sectionTitle,
  });

  static const accent = Color(0xFFE4573D);

  final Color bg;
  final Color card;
  final Color border;
  final Color title;
  final Color body;
  final Color subtitle;
  final Color iconBg;
  final Color iconFg;
  final Color sectionTitle;

  factory _AccountPalette.light() {
    return const _AccountPalette(
      bg: Color(0xFFFDFBFA),
      card: Colors.white,
      border: Color(0xFFE6E1DA),
      title: Color(0xFF1A1E2A),
      body: Color(0xFF1A1E2A),
      subtitle: Color(0xFF5C5F6B),
      iconBg: Color(0xFFF2EFEB),
      iconFg: Color(0xFF1A1E2A),
      sectionTitle: Color(0xFF1A1E2A),
    );
  }

  factory _AccountPalette.dark() {
    return const _AccountPalette(
      bg: Color(0xFF1F1F23),
      card: Color(0xFF2A2A30),
      border: Color(0xFF3A3A42),
      title: Color(0xFFF5F2EE),
      body: Color(0xFFF5F2EE),
      subtitle: Color(0xFFB9B4AC),
      iconBg: Color(0xFF3A3A42),
      iconFg: Color(0xFFF5F2EE),
      sectionTitle: Color(0xFFF5F2EE),
    );
  }
}

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key, this.showAppBar = true});

  final bool showAppBar;

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _claims = ClaimsService();
  final _displayName = TextEditingController();

  bool _loading = true;
  String _status = 'Loading...';
  String _role = 'guest';
  bool _savingName = false;
  String _nameStatus = '';
  _AccountPalette _palette = _AccountPalette.light();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _status = 'Fetching account...';
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _loading = false;
        _status = 'Not logged in';
        _role = 'guest';
      });
      return;
    }

    try {
      final role = await _claims.getMyRole();
      String displayName = user.displayName ?? '';
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final data = doc.data();
        final storedName = (data?['displayName'] ?? '').toString().trim();
        if (storedName.isNotEmpty) {
          displayName = storedName;
        }
      } catch (_) {}
      setState(() {
        _role = role.toLowerCase();
        _displayName.text = displayName;
        _loading = false;
        _status = 'OK';
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _status = 'Failed to load role: $e';
      });
    }
  }

  Future<void> _logout() async {
    await NotificationService.unregisterToken();
    await FirebaseAuth.instance.signOut();
    // AuthGate should react automatically
  }

  @override
  void dispose() {
    _displayName.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final name = _displayName.text.trim();
    if (name.isEmpty) {
      setState(() => _nameStatus = 'Name cannot be empty.');
      return;
    }

    setState(() {
      _savingName = true;
      _nameStatus = '';
    });
    try {
      await user.updateDisplayName(name);
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(
        {
          'displayName': name,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      setState(() => _nameStatus = 'Name updated.');
    } catch (e) {
      setState(() => _nameStatus = 'Failed to update name: $e');
    } finally {
      if (mounted) setState(() => _savingName = false);
    }
  }

  String _initials(String nameOrEmail) {
    final cleaned = nameOrEmail.trim();
    if (cleaned.isEmpty) return 'U';
    final parts = cleaned.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    final first = parts.first.isNotEmpty ? parts.first[0] : '';
    final last = parts.last.isNotEmpty ? parts.last[0] : '';
    final combined = '$first$last'.trim();
    return combined.isEmpty ? cleaned[0].toUpperCase() : combined.toUpperCase();
  }

  Future<void> _showEditNameDialog() async {
    final controller = TextEditingController(text: _displayName.text.trim());
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit display name'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Your name',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                _displayName.text = controller.text.trim();
                Navigator.of(context).pop();
                await _saveName();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openLink(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      _toast(context, 'Invalid link.');
      return;
    }
    final canOpen = await canLaunchUrl(uri);
    if (!canOpen) {
      _toast(context, 'Unable to open link.');
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _showAppearanceSheet(
    BuildContext context,
    _AccountPalette palette,
  ) async {
    final controller = ThemeController.instance;
    final selected = await showModalBottomSheet<ThemeMode>(
      context: context,
      backgroundColor: palette.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Appearance',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: palette.title,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 12),
              _appearanceOption(
                context,
                palette,
                label: 'Light',
                value: ThemeMode.light,
                selected: controller.mode,
              ),
              _appearanceOption(
                context,
                palette,
                label: 'Dark',
                value: ThemeMode.dark,
                selected: controller.mode,
              ),
            ],
          ),
        );
      },
    );

    if (selected != null && selected != controller.mode) {
      await controller.setMode(selected);
      _toast(
        context,
        'Appearance set to ${selected == ThemeMode.dark ? 'Dark' : 'Light'}.',
      );
    }
  }

  Widget _appearanceOption(
    BuildContext context,
    _AccountPalette palette, {
    required String label,
    required ThemeMode value,
    required ThemeMode selected,
  }) {
    final isSelected = selected == value;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
        color: isSelected ? _AccountPalette.accent : palette.subtitle,
      ),
      title: Text(
        label,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: palette.title,
              fontWeight: FontWeight.w600,
            ),
      ),
      onTap: () => Navigator.of(context).pop(value),
    );
  }

  Widget _headerCard(
    BuildContext context, {
    required User? user,
    required String displayName,
    required String email,
  }) {
    const accent = Color(0xFFE4573D);
    const light = Color(0xFFF5F2EE);
    final textTheme = Theme.of(context).textTheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF05D4B), Color(0xFFB7371E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -40,
              right: -30,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              bottom: -50,
              left: -10,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Center(
                      child: user == null
                          ? Icon(Icons.person, color: accent, size: 42)
                          : Text(
                              _initials(displayName),
                              style: textTheme.titleLarge?.copyWith(
                                color: accent,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user == null ? 'Get the Full Experience' : displayName,
                          style: textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user == null
                              ? 'Sign in to access full features and services.'
                              : email,
                          style: textTheme.bodySmall?.copyWith(
                            color: Colors.white.withOpacity(0.85),
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (user == null)
                          SizedBox(
                            height: 34,
                            child: FilledButton(
                              onPressed: () => Navigator.of(context)
                                  .popUntil((r) => r.isFirst),
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: accent,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 22),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                              child: const Text('Sign in'),
                            ),
                          )
                        else
                          SizedBox(
                            height: 34,
                            child: OutlinedButton(
                              onPressed: _showEditNameDialog,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: BorderSide(
                                  color: Colors.white.withOpacity(0.7),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                              child: const Text('Edit profile'),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (user != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _role,
                        style: textTheme.labelSmall?.copyWith(
                          color: light,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: _palette.sectionTitle,
            fontWeight: FontWeight.w700,
          ),
    );
  }

  Widget _sectionCard(BuildContext context, {required List<Widget> children}) {
    final card = _palette.card;
    final border = _palette.border;
    final tiles = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      tiles.add(children[i]);
      if (i < children.length - 1) {
        tiles.add(
          Divider(
            height: 1,
            color: border.withOpacity(0.8),
          ),
        );
      }
    }
    return Container(
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(children: tiles),
    );
  }

  Widget _actionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    final light = _palette.body;
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: _palette.iconBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: _palette.iconFg, size: 18),
      ),
      title: Text(
        title,
        style: TextStyle(color: light, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: _palette.subtitle),
      ),
      trailing: Icon(Icons.chevron_right, color: _palette.subtitle),
      onTap: onTap,
    );
  }

  Widget _infoTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final light = _palette.body;
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: _palette.iconBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: _palette.iconFg, size: 18),
      ),
      title: Text(
        title,
        style: TextStyle(color: light, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: _palette.subtitle),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final baseTheme = Theme.of(context);
    final textTheme = GoogleFonts.poppinsTextTheme(baseTheme.textTheme);
    const accent = Color(0xFFE4573D);
    final palette = baseTheme.brightness == Brightness.dark
        ? _AccountPalette.dark()
        : _AccountPalette.light();
    _palette = palette;

    final email = user?.email ?? 'Not signed in';
    final name = _displayName.text.trim();
    final displayName = name.isNotEmpty ? name : email;

    if (_loading) {
      return Theme(
        data: baseTheme.copyWith(textTheme: textTheme),
        child: Scaffold(
          backgroundColor: palette.bg,
          appBar: widget.showAppBar
              ? AppBar(
                  title: const Text('Account'),
                  backgroundColor: palette.bg,
                  foregroundColor: palette.title,
                  elevation: 0,
                )
              : null,
          body: Center(
            child: Text(
              _status,
              style: textTheme.bodyMedium?.copyWith(color: palette.title),
            ),
          ),
        ),
      );
    }

    return Theme(
        data: baseTheme.copyWith(textTheme: textTheme),
        child: Scaffold(
        backgroundColor: palette.bg,
        appBar: widget.showAppBar
            ? AppBar(
                title: const Text('Account'),
                backgroundColor: palette.bg,
                foregroundColor: palette.title,
                elevation: 0,
                actions: [
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              )
            : null,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _headerCard(
                context,
                user: user,
                displayName: displayName,
                email: email,
              ),
              if (_nameStatus.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  _nameStatus,
                  style: textTheme.bodySmall?.copyWith(
                    color: palette.subtitle,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              _sectionTitle(context, 'Preferences'),
              const SizedBox(height: 10),
              _sectionCard(
                context,
                children: [
                  _actionTile(
                    context,
                    icon: Icons.person_outline,
                    title: 'Edit profile',
                    subtitle: 'Change display name',
                    onTap: user == null ? null : _showEditNameDialog,
                  ),
                  _actionTile(
                    context,
                    icon: Icons.palette_outlined,
                    title: 'Appearance',
                    subtitle: 'Light / Dark mode',
                    onTap: () => _showAppearanceSheet(context, palette),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _sectionTitle(context, 'Support'),
              const SizedBox(height: 10),
              _sectionCard(
                context,
                children: [
                  _actionTile(
                    context,
                    icon: Icons.facebook,
                    title: 'Facebook',
                    subtitle: 'Follow us on Facebook',
                    onTap: () => _openLink(
                      context,
                      'https://www.facebook.com',
                    ),
                  ),
                  _actionTile(
                    context,
                    icon: Icons.public,
                    title: 'Daet Gov Website',
                    subtitle: 'Official website',
                    onTap: () => _openLink(
                      context,
                      'https://www.gov.ph',
                    ),
                  ),
                  _actionTile(
                    context,
                    icon: Icons.info_outline,
                    title: 'About Us',
                    subtitle: 'Learn more about MyDaet',
                    onTap: () => _toast(context, 'About page coming soon.'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _sectionTitle(context, 'Account'),
              const SizedBox(height: 10),
              _sectionCard(
                context,
                children: [
                  _infoTile(
                    context,
                    icon: Icons.badge_outlined,
                    title: 'User ID',
                    subtitle: user?.uid ?? 'N/A',
                  ),
                  _infoTile(
                    context,
                    icon: Icons.mail_outline,
                    title: 'Email',
                    subtitle: email,
                  ),
                  _infoTile(
                    context,
                    icon: Icons.verified_user_outlined,
                    title: 'Role',
                    subtitle: _role,
                  ),
                  _infoTile(
                    context,
                    icon: Icons.check_circle_outline,
                    title: 'Session Status',
                    subtitle: _status,
                  ),
                ],
              ),
              if (user != null) ...[
                const SizedBox(height: 18),
                SizedBox(
                  height: 46,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: _logout,
                    icon: const Icon(Icons.logout),
                    label: const Text('Logout'),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                'Role is controlled by Firebase custom claims.\n'
                'If role was updated, press Refresh.',
                style: textTheme.bodySmall?.copyWith(
                  color: palette.subtitle,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

}
