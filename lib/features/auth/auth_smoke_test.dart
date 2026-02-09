import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';

class AuthSmokeTestScreen extends StatefulWidget {
  const AuthSmokeTestScreen({super.key});

  @override
  State<AuthSmokeTestScreen> createState() => _AuthSmokeTestScreenState();
}

class _AuthSmokeTestScreenState extends State<AuthSmokeTestScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  String _status = 'Ready';

  // Make sure we always call the deployed region (your functions are in us-central1)
  FirebaseFunctions get _functions => FirebaseFunctions.instanceFor(
        app: Firebase.app(),
        region: 'us-central1',
      );

  Future<void> _signup() async {
    setState(() => _status = 'Signing up...');
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _email.text.trim(),
        password: _pass.text.trim(),
      );
      setState(() => _status = 'Signup OK: ${cred.user?.uid}');
    } catch (e) {
      setState(() => _status = 'Signup failed: $e');
    }
  }
  Future<void> _forceRefreshToken() async {
  setState(() => _status = 'Refreshing token...');
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _status = 'Not logged in');
      return;
    }
    await user.getIdToken(true); // force refresh
    setState(() => _status = 'Token refreshed ✅');
  } catch (e) {
    setState(() => _status = 'Token refresh failed: $e');
  }
}

  Future<void> _login() async {
    setState(() => _status = 'Logging in...');
    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _pass.text.trim(),
      );
      setState(() => _status = 'Login OK: ${cred.user?.uid}');
    } catch (e) {
      setState(() => _status = 'Login failed: $e');
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    setState(() => _status = 'Logged out');
  }

  // 🔐 TEMP: Run once to grant super_admin to your target UID (server enforces UID match)
  Future<void> _bootstrapSuperAdmin() async {
    setState(() => _status = 'Granting super_admin...');
    try {
      final callable = _functions.httpsCallable('bootstrapSuperAdmin');
      final res = await callable.call();
      setState(() => _status = 'Bootstrap OK: ${res.data}');
    } catch (e) {
      setState(() => _status = 'Bootstrap failed: $e');
    }
  }

  // 🔍 Verify the current user's token claims from backend
  Future<void> _getMyClaims() async {
    setState(() => _status = 'Fetching claims...');
    try {
      final callable = _functions.httpsCallable('getMyClaims');
      final res = await callable.call();
      setState(() => _status = 'Claims: ${res.data}');
    } catch (e) {
      setState(() => _status = 'Claims error: $e');
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
    return Scaffold(
      appBar: AppBar(title: const Text('Auth Smoke Test')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _email,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pass,
              decoration: const InputDecoration(labelText: 'Password (min 6)'),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _signup,
                    child: const Text('Sign up'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _login,
                    child: const Text('Log in'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _logout,
              child: const Text('Log out'),
            ),
            const SizedBox(height: 16),

            // ✅ Bootstrap + Claims buttons
            ElevatedButton(
              onPressed: _bootstrapSuperAdmin,
              child: const Text('Grant Super Admin (Bootstrap)'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _getMyClaims,
              child: const Text('Get My Claims'),
            ),
            ElevatedButton(
          onPressed: _forceRefreshToken,
          child: const Text('Force Refresh Token'),
        ),


            const SizedBox(height: 16),
            SelectableText(
              _status,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
