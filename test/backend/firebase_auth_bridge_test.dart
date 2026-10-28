import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:hybrid_note/backend/firebase_auth_bridge.dart';
import 'package:hybrid_note/drive_sync_service.dart';

class FakeUser implements User {
  FakeUser(this.email);

  @override
  final String? email;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeUserCredential implements UserCredential {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Records what the bridge asks of Firebase Auth.
class FakeFirebaseAuth implements FirebaseAuth {
  FakeFirebaseAuth({this.user, this.failSignIn = false});

  User? user;
  final bool failSignIn;
  final List<AuthCredential> credentials = [];
  final List<AuthProvider> popups = [];
  int signOuts = 0;

  @override
  User? get currentUser => user;

  @override
  Stream<User?> authStateChanges() => Stream<User?>.value(user);

  @override
  Future<UserCredential> signInWithCredential(AuthCredential credential) async {
    credentials.add(credential);
    if (failSignIn) {
      throw FirebaseAuthException(code: 'invalid-credential');
    }
    user = FakeUser('owner@example.com');
    return FakeUserCredential();
  }

  @override
  Future<UserCredential> signInWithPopup(AuthProvider provider) async {
    popups.add(provider);
    if (failSignIn) {
      throw FirebaseAuthException(code: 'popup-closed-by-user');
    }
    user = FakeUser('owner@example.com');
    return FakeUserCredential();
  }

  @override
  Future<void> signOut() async {
    signOuts++;
    user = null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeTokens implements GoogleSignInAuthentication {
  FakeTokens({this.idToken, this.accessToken});

  @override
  final String? idToken;

  @override
  final String? accessToken;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeGoogleAccount implements GoogleSignInAccount {
  FakeGoogleAccount(this.tokens);

  final FakeTokens tokens;

  @override
  Future<GoogleSignInAuthentication> get authentication async => tokens;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FirebaseAuthBridge', () {
    test('turns the Google account tokens into a Firebase sign-in', () async {
      final FakeFirebaseAuth auth = FakeFirebaseAuth();
      final FirebaseAuthBridge bridge = FirebaseAuthBridge(auth: auth);

      final bool signedIn = await bridge.signInWithGoogleAccount(
        FakeGoogleAccount(FakeTokens(idToken: 'id-1', accessToken: 'access-1')),
      );

      expect(signedIn, isTrue);
      expect(bridge.isSignedIn, isTrue);
      expect(bridge.signedInEmail, 'owner@example.com');
      final OAuthCredential credential =
          auth.credentials.single as OAuthCredential;
      expect(credential.providerId, 'google.com');
      expect(credential.idToken, 'id-1');
      expect(credential.accessToken, 'access-1');
    });

    test('keeps an existing Firebase session', () async {
      final FakeFirebaseAuth auth =
          FakeFirebaseAuth(user: FakeUser('owner@example.com'));
      final FirebaseAuthBridge bridge = FirebaseAuthBridge(auth: auth);

      final bool signedIn = await bridge.signInWithGoogleAccount(
        FakeGoogleAccount(FakeTokens(idToken: 'id-1')),
      );

      expect(signedIn, isTrue);
      expect(auth.credentials, isEmpty);
    });

    test('reports an account without tokens and does not call Firebase',
        () async {
      final FakeFirebaseAuth auth = FakeFirebaseAuth();
      final FirebaseAuthBridge bridge = FirebaseAuthBridge(auth: auth);

      final bool signedIn =
          await bridge.signInWithGoogleAccount(FakeGoogleAccount(FakeTokens()));

      expect(signedIn, isFalse);
      expect(auth.credentials, isEmpty);
    });

    test('a Firebase failure returns false instead of throwing', () async {
      final FakeFirebaseAuth auth = FakeFirebaseAuth(failSignIn: true);
      final FirebaseAuthBridge bridge = FirebaseAuthBridge(auth: auth);

      expect(
        await bridge.signInWithGoogleAccount(
          FakeGoogleAccount(FakeTokens(idToken: 'id-1')),
        ),
        isFalse,
      );
      expect(await bridge.signInWithPopup(), isFalse);
      expect(bridge.isSignedIn, isFalse);
    });

    test('the web pop-up asks Google for no extra scopes', () async {
      final FakeFirebaseAuth auth = FakeFirebaseAuth();
      final FirebaseAuthBridge bridge = FirebaseAuthBridge(auth: auth);

      expect(await bridge.signInWithPopup(), isTrue);

      final GoogleAuthProvider provider =
          auth.popups.single as GoogleAuthProvider;
      expect(provider.scopes, isEmpty);
    });

    test('restore reports the persisted session', () async {
      expect(
        await FirebaseAuthBridge(auth: FakeFirebaseAuth()).restore(),
        isFalse,
      );
      expect(
        await FirebaseAuthBridge(
          auth: FakeFirebaseAuth(user: FakeUser('owner@example.com')),
        ).restore(),
        isTrue,
      );
    });

    test('signOut signs out of Firebase', () async {
      final FakeFirebaseAuth auth =
          FakeFirebaseAuth(user: FakeUser('owner@example.com'));
      final FirebaseAuthBridge bridge = FirebaseAuthBridge(auth: auth);

      await bridge.signOut();

      expect(auth.signOuts, 1);
      expect(bridge.isSignedIn, isFalse);
    });
  });

  group('DriveSyncService with Firebase', () {
    const MethodChannel channel =
        MethodChannel('plugins.flutter.io/google_sign_in');
    final List<String> googleCalls = [];
    Map<String, dynamic>? silentAccount;

    setUp(() {
      googleCalls.clear();
      silentAccount = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        googleCalls.add(call.method);
        switch (call.method) {
          case 'signInSilently':
            return silentAccount;
          case 'getTokens':
            return <String, dynamic>{
              'idToken': 'id-restored',
              'accessToken': 'access-restored',
            };
          default:
            return null;
        }
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('restoring the Google sign-in also signs in to Firebase', () async {
      silentAccount = <String, dynamic>{
        'email': 'owner@example.com',
        'id': 'google-1',
      };
      final FakeFirebaseAuth auth = FakeFirebaseAuth();
      final DriveSyncService service =
          DriveSyncService(firebaseAuth: FirebaseAuthBridge(auth: auth));

      expect(await service.tryRestorePreviousSignIn(), isTrue);

      final OAuthCredential credential =
          auth.credentials.single as OAuthCredential;
      expect(credential.idToken, 'id-restored');
      expect(credential.accessToken, 'access-restored');
    });

    test('no restored Google account leaves Firebase alone', () async {
      final FakeFirebaseAuth auth = FakeFirebaseAuth();
      final DriveSyncService service =
          DriveSyncService(firebaseAuth: FirebaseAuthBridge(auth: auth));

      expect(await service.tryRestorePreviousSignIn(), isFalse);
      expect(auth.credentials, isEmpty);
    });

    test('signOut signs out of Firebase and Google', () async {
      final FakeFirebaseAuth auth =
          FakeFirebaseAuth(user: FakeUser('owner@example.com'));
      final DriveSyncService service =
          DriveSyncService(firebaseAuth: FirebaseAuthBridge(auth: auth));

      await service.signOut();

      expect(auth.signOuts, 1);
      expect(googleCalls, contains('signOut'));
    });
  });
}
