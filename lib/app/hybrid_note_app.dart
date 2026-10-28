import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../backend/auth_service.dart';
import '../backend/firestore_list_store.dart';
import '../l10n/generated/app_localizations.dart';
import '../lists/list_store.dart';
import 'app_settings.dart';
import 'app_theme.dart';
import 'main_shell.dart';
import 'sign_in_screen.dart';

// Opens the list store of a signed-in user (FirestoreSetup.openStore in the
// app, a fake_cloud_firestore store in tests).
typedef StoreOpener = FirestoreListStore Function(AuthUser user);

// The signed-in account as the shell sees it: who is signed in, and how to
// sign out (the gate closes the store first).
class SignedInAccount {
  const SignedInAccount({required this.user, required this.signOut});

  final AuthUser user;
  final Future<void> Function() signOut;
}

// Signed out: the sign-in screen and nothing else (Q-21 A). Signed in: the
// shell on a store for that user's uid, whatever the sign-in method (D-13).
// The providers sit above MaterialApp so pushed pages see them, and the app
// is keyed by uid: a new user (or none) gets a fresh page stack and store,
// so no list of the previous user stays on screen.
class HybridNoteApp extends StatefulWidget {
  const HybridNoteApp({
    super.key,
    required this.auth,
    required this.openStore,
    this.afterSignOut,
  });

  final AuthService auth;
  final StoreOpener openStore;
  // Runs once sign-out has finished and the cache is cleared; on web it
  // reloads the page, since the cleared Firestore instance cannot be used
  // again (FirestoreSetup). It does not run while the cache is still there.
  final VoidCallback? afterSignOut;

  @override
  State<HybridNoteApp> createState() => _HybridNoteAppState();
}

class _HybridNoteAppState extends State<HybridNoteApp> {
  final GlobalKey<ScaffoldMessengerState> _messenger =
      GlobalKey<ScaffoldMessengerState>();
  late final StreamSubscription<AuthUser?> _subscription;
  // False until Firebase has said whether a user is signed in, so a
  // restored session does not flash the sign-in screen.
  bool _known = false;
  AuthUser? _user;
  FirestoreListStore? _store;
  // Signed out, but the previous account's cache could not be cleared: the
  // sign-in screen says so and offers to try again (T-17 R1, Q-25 A).
  bool _cleanupFailed = false;

  @override
  void initState() {
    super.initState();
    _subscription = widget.auth.userChanges.listen(_onUser);
  }

  @override
  void dispose() {
    _subscription.cancel();
    unawaited(_store?.close());
    super.dispose();
  }

  void _onUser(AuthUser? user) {
    final FirestoreListStore? old = _store;
    final bool sameUser = user?.uid == _user?.uid;
    setState(() {
      _known = true;
      _user = user;
      if (!sameUser) {
        _store = user == null ? null : widget.openStore(user);
      }
    });
    if (!sameUser) {
      unawaited(old?.close());
    }
  }

  // Takes the lists off the screen at once, closes the store, then signs
  // out (which clears the cache, Q-25 A).
  Future<void> _signOut() async {
    final FirestoreListStore? store = _store;
    setState(() {
      _user = null;
      _store = null;
    });
    final bool cleared;
    try {
      await store?.close();
      cleared = await widget.auth.signOut();
    } on Object catch (error) {
      debugPrint('Sign-out failed: $error');
      final BuildContext? context = _messenger.currentContext;
      if (context != null && context.mounted) {
        _messenger.currentState?.showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).signOutFailed)),
        );
      }
      // Still signed in: back to that user's lists.
      if (mounted) {
        _onUser(widget.auth.currentUser);
      }
      return;
    }
    _afterCleanup(cleared);
  }

  Future<void> _retryCleanup() async {
    _afterCleanup(await widget.auth.clearLocalData());
  }

  // Signed out either way; only a cleared cache counts as done.
  void _afterCleanup(bool cleared) {
    if (!mounted) {
      return;
    }
    setState(() => _cleanupFailed = !cleared);
    if (cleared) {
      widget.afterSignOut?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AuthUser? user = _user;
    final FirestoreListStore? store = _store;
    final Widget home;
    if (!_known) {
      home = const Scaffold();
    } else if (user == null || store == null) {
      home = SignInScreen(
        auth: widget.auth,
        onRetryCleanup: _cleanupFailed ? _retryCleanup : null,
      );
    } else {
      home = const MainShell();
    }

    final Widget app = BlocBuilder<AppSettingsCubit, AppSettings>(
      builder: (context, settings) {
        return MaterialApp(
          key: ValueKey(user?.uid),
          scaffoldMessengerKey: _messenger,
          onGenerateTitle: (context) {
            return AppLocalizations.of(context).appTitle;
          },
          debugShowCheckedModeBanner: false,
          locale: settings.localeCode == null
              ? null
              : Locale(settings.localeCode!),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: settings.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          home: home,
        );
      },
    );

    if (user == null || store == null) {
      return app;
    }
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<ListStore>.value(value: store),
        RepositoryProvider<SignedInAccount>.value(
          value: SignedInAccount(user: user, signOut: _signOut),
        ),
      ],
      child: app,
    );
  }
}
