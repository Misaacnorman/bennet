import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/auth_shell.dart';

/// Email/password registration for Firebase-backed Bennet.
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    final confirm = _confirmCtrl.text;

    if (password != confirm) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    if (password.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: password);
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
    final scheme = Theme.of(context).colorScheme;

    return AuthShell(
      headline: 'Create account',
      subtitle: 'Set up your Bennet workspace',
      formCard: AuthShell.card(
        context,
        children: [
          TextField(
            controller: _emailCtrl,
            decoration: const InputDecoration(labelText: 'Email'),
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordCtrl,
            decoration: const InputDecoration(
              labelText: 'Password',
              helperText: 'At least 6 characters',
            ),
            obscureText: true,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newPassword],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _confirmCtrl,
            decoration: const InputDecoration(labelText: 'Confirm password'),
            obscureText: true,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.newPassword],
            onSubmitted: (_) {
              if (!_busy) _submit();
            },
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: scheme.error, height: 1.35)),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: const Text('Create account'),
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(top: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
      footerLink: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'Already have an account? ',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          TextButton(
            onPressed: _busy ? null : () => context.go('/login'),
            child: const Text('Sign in'),
          ),
        ],
      ),
      footerText:
          'Uses Firebase Authentication and Cloud Firestore. Enable Email/Password in the Firebase console if needed.',
    );
  }
}
