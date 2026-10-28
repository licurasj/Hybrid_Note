import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hybrid_note/app/app_settings.dart';
import 'package:hybrid_note/app/hybrid_note_app.dart';
import 'package:hybrid_note/backend/auth_service.dart';
import 'package:hybrid_note/backend/firestore_list_store.dart';

import 'firestore_store.dart';

const AuthUser testUser = AuthUser(uid: testUid, email: 'owner@example.com');

// AuthService without Firebase: [signInWithGoogle] signs in as [nextUser]
// (or throws [signInError]); [calls] records what was called.
class FakeAuthService implements AuthService {
  FakeAuthService({AuthUser? user, this.nextUser = testUser}) : _user = user;

  AuthUser? _user;
  AuthUser? nextUser;
  AuthException? signInError;
  final List<String> calls = [];
  final StreamController<AuthUser?> _changes =
      StreamController<AuthUser?>.broadcast();

  void emit(AuthUser? user) {
    _user = user;
    _changes.add(user);
  }

  @override
  Future<void> Function()? get clearCache => null;

  @override
  AuthUser? get currentUser => _user;

  @override
  Stream<AuthUser?> get userChanges async* {
    yield _user;
    yield* _changes.stream;
  }

  @override
  Future<AuthUser?> restore() async => _user;

  @override
  Future<AuthUser?> signInWithGoogle() async {
    calls.add('signIn');
    if (signInError != null) {
      throw signInError!;
    }
    emit(nextUser);
    return nextUser;
  }

  @override
  Future<void> signOut() async {
    calls.add('signOut');
    emit(null);
  }
}

// The whole app (gate, shell, settings) on [auth], opening [store] for
// whoever signs in. Call SharedPreferences.setMockInitialValues first.
Future<Widget> testApp({
  required FakeAuthService auth,
  required FirestoreListStore Function(AuthUser user) openStore,
}) async {
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  return BlocProvider(
    create: (_) => AppSettingsCubit(preferences),
    child: HybridNoteApp(auth: auth, openStore: openStore),
  );
}
