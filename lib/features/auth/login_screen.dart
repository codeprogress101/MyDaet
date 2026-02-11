import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_fonts/google_fonts.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onSwitch});
  final VoidCallback onSwitch;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _loading = false;
  String _status = '';
  bool _obscure = true;

  void _showSuccess(String message) {
    if (!mounted) return;
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        backgroundColor: scheme.inverseSurface,
        content: Row(
          children: [
            Icon(Icons.check_circle, color: scheme.onInverseSurface),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: scheme.onInverseSurface),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loginEmail() async {
    setState(() {
      _loading = true;
      _status = 'Logging in...';
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _pass.text.trim(),
      );
      // ✅ AuthGate listens to authStateChanges, so no navigation here.
      if (mounted) {
        setState(() => _status = '');
        _showSuccess('Login successful. Welcome back.');
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _status = e.message ?? e.code);
    } catch (e) {
      if (mounted) setState(() => _status = 'Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loginGoogle() async {
    setState(() {
      _loading = true;
      _status = 'Signing in with Google...';
    });

    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        if (mounted) setState(() => _status = 'Cancelled.');
        return;
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);
      if (mounted) {
        setState(() => _status = '');
        _showSuccess('Signed in with Google.');
      }
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
    _email.dispose();
    _pass.dispose();
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
                            'Welcome back to\nMyDaet',
                            style: textTheme.headlineSmall?.copyWith(
                              color: dark,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Sign in to your account',
                            style: textTheme.bodyMedium?.copyWith(
                              color: dark.withValues(alpha: 0.6),
                            ),
                          ),
                          const SizedBox(height: 24),
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
                              'Password',
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
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) {
                              if (!_loading) _loginEmail();
                            },
                            autofillHints: const [AutofillHints.password],
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'Forgot password?',
                                style: textTheme.bodySmall?.copyWith(
                                  color: accent,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 46,
                            child: ElevatedButton(
                              onPressed: _loading ? null : _loginEmail,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accent,
                                foregroundColor: scheme.onPrimary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                _loading ? 'Signing in...' : 'Sign In',
                                style:
                                    const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              const Expanded(
                                child: Divider(color: Color(0xFFE5E0DA)),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 10),
                                child: Text(
                                  'OR',
                                  style: textTheme.labelSmall?.copyWith(
                                    color: dark.withValues(alpha: 0.5),
                                  ),
                                ),
                              ),
                              const Expanded(
                                child: Divider(color: Color(0xFFE5E0DA)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 46,
                            child: OutlinedButton(
                              onPressed: _loading ? null : _loginGoogle,
                              style: OutlinedButton.styleFrom(
                                backgroundColor: scheme.surface,
                                foregroundColor: dark,
                                side: BorderSide(color: scheme.outlineVariant),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.asset(
                                    'assets/images/google_logo.png',
                                    width: 18,
                                    height: 18,
                                  ),
                                  const SizedBox(width: 10),
                                  const Text('Sign In with Google'),
                                ],
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
                            'By signing in, you agree to our\nTerms of Service and Privacy Policy.',
                            textAlign: TextAlign.center,
                            style: textTheme.bodySmall?.copyWith(
                              color: dark.withValues(alpha: 0.6),
                            ),
                          ),
                          const SizedBox(height: 18),
                          TextButton(
                            onPressed: _loading ? null : widget.onSwitch,
                            child: Text(
                              "Don't have an account? Register",
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
