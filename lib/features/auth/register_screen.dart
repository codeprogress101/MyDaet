import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, required this.onSwitch});
  final VoidCallback onSwitch;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _pass2 = TextEditingController();

  bool _loading = false;
  String _status = '';
  bool _obscure = true;
  bool _obscure2 = true;

  Future<void> _register() async {
    setState(() {
      _loading = true;
      _status = 'Creating account...';
    });

    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() {
        _loading = false;
        _status = 'Full name is required.';
      });
      return;
    }

    final p1 = _pass.text.trim();
    final p2 = _pass2.text.trim();
    if (p1 != p2) {
      setState(() {
        _loading = false;
        _status = 'Passwords do not match.';
      });
      return;
    }

    try {
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _email.text.trim(),
        password: p1,
      );
      final user = credential.user;
      if (user != null) {
        await user.updateDisplayName(name);
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set(
          {
            'uid': user.uid,
            'role': 'resident',
            'officeId': null,
            'officeName': null,
            'isActive': true,
            'displayName': name,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      // ✅ show success
      setState(() => _status = 'Registered OK ✅ Redirecting to Login...');

      // ✅ If you want user to log in manually after register:
      await FirebaseAuth.instance.signOut();

      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      widget.onSwitch(); // go back to login screen
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _status = e.message ?? e.code);
    } catch (e) {
      if (mounted) setState(() => _status = 'Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _pass.dispose();
    _pass2.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final textTheme = GoogleFonts.poppinsTextTheme(baseTheme.textTheme);
    const accent = Color(0xFFE46B2C);
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.onSurface;

    InputDecoration inputDecoration(String label, IconData icon) {
      return InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: accent),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE6E1DB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE6E1DB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accent, width: 1.3),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Theme(
        data: baseTheme.copyWith(textTheme: textTheme),
        child: SafeArea(
          child: Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: 460,
                      minHeight: constraints.maxHeight - 36,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Image.asset(
                                'assets/images/app_logo.png',
                                width: 28,
                                height: 28,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'MyDaet',
                                style: textTheme.titleMedium?.copyWith(
                                  color: dark,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),
                          Text(
                            'Create an Account',
                            style: textTheme.headlineSmall?.copyWith(
                              color: dark,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Join MyDaet and stay updated with your community.',
                            style: textTheme.bodyMedium?.copyWith(
                              color: dark.withValues(alpha: 0.6),
                            ),
                          ),
                          const SizedBox(height: 24),
                          TextField(
                            controller: _name,
                            decoration: inputDecoration(
                              'Full Name',
                              Icons.person_outline,
                            ),
                            textInputAction: TextInputAction.next,
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _email,
                            decoration: inputDecoration(
                              'Email Address',
                              Icons.mail_outline,
                            ).copyWith(
                              suffixIcon: _email.text.trim().contains('@')
                                  ? const Icon(
                                      Icons.check_circle,
                                      color: accent,
                                    )
                                  : null,
                            ),
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _pass,
                            decoration: inputDecoration(
                              'Password (min 6)',
                              Icons.lock_outline,
                            ).copyWith(
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscure
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                  color: accent,
                                ),
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                              ),
                            ),
                            obscureText: _obscure,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.newPassword],
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _pass2,
                            decoration: inputDecoration(
                              'Confirm Password',
                              Icons.lock_reset,
                            ).copyWith(
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscure2
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                  color: accent,
                                ),
                                onPressed: () =>
                                    setState(() => _obscure2 = !_obscure2),
                              ),
                            ),
                            obscureText: _obscure2,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) {
                              if (!_loading) _register();
                            },
                            autofillHints: const [AutofillHints.newPassword],
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 46,
                            child: ElevatedButton(
                              onPressed: _loading ? null : _register,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accent,
                                foregroundColor: scheme.onPrimary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                _loading ? 'Creating account...' : 'Sign Up',
                                style:
                                    const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                          if (_status.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              _status,
                              style: textTheme.bodySmall?.copyWith(
                                color: dark.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                          const Spacer(),
                          Text(
                            'By signing up, you agree to our\nTerms of Service and Privacy Policy.',
                            textAlign: TextAlign.center,
                            style: textTheme.bodySmall?.copyWith(
                              color: dark.withValues(alpha: 0.6),
                            ),
                          ),
                          const SizedBox(height: 18),
                          TextButton(
                            onPressed: _loading ? null : widget.onSwitch,
                            child: Text(
                              'Already have an account? Sign in',
                              style: textTheme.bodyMedium?.copyWith(
                                color: accent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
