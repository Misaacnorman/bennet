import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Email/password and anonymous sign-in for Firebase-backed Bennet.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _handle(Future<void> Function() fn) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await fn();
      if (mounted) context.go('/');
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? e.code);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Bennet uses Firebase Authentication and Cloud Firestore. '
            'Enable Email/Password (and Anonymous if you want demo sign-in) in the Firebase console.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _emailCtrl,
            decoration: const InputDecoration(labelText: 'Email'),
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordCtrl,
            decoration: const InputDecoration(labelText: 'Password'),
            obscureText: true,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy
                ? null
                : () => _handle(() async {
                      await FirebaseAuth.instance.signInWithEmailAndPassword(
                        email: _emailCtrl.text.trim(),
                        password: _passwordCtrl.text,
                      );
                    }),
            child: const Text('Sign in'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _busy
                ? null
                : () => _handle(() async {
                      await FirebaseAuth.instance.createUserWithEmailAndPassword(
                        email: _emailCtrl.text.trim(),
                        password: _passwordCtrl.text,
                      );
                    }),
            child: const Text('Create account'),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _busy
                ? null
                : () => _handle(() async {
                      await FirebaseAuth.instance.signInAnonymously();
                    }),
            icon: const Icon(Icons.person_outline),
            label: const Text('Continue anonymously (demo)'),
          ),
          if (_busy) const Padding(padding: EdgeInsets.only(top: 24), child: Center(child: CircularProgressIndicator())),
        ],
      ),
    );
  }
}
