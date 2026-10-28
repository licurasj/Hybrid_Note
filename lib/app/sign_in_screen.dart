import 'package:flutter/material.dart';

import '../backend/auth_service.dart';
import '../l10n/generated/app_localizations.dart';

// The signed-out state (Q-21 A): the app name and "Sign in with Google",
// nothing else. A successful sign-in reaches the gate through
// AuthService.userChanges; failures show as a snackbar.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key, required this.auth});

  final AuthService auth;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  bool _busy = false;

  Future<void> _signIn() async {
    final AppLocalizations loc = AppLocalizations.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await widget.auth.signInWithGoogle();
    } on AuthException catch (error) {
      debugPrint('Sign-in failed: $error');
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            error.reason == AuthFailure.network
                ? loc.signInOffline
                : loc.signInFailed,
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations loc = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  loc.appTitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  key: const ValueKey('sign-in'),
                  onPressed: _busy ? null : _signIn,
                  icon: const Icon(Icons.login),
                  label: Text(loc.signInWithGoogle),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
