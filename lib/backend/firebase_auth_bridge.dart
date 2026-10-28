import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

// Keeps Firebase Auth signed in alongside the Google sign-in (T-14, Q-7 A).
// Android: the native Google account sheet stays; its tokens become a
// Firebase credential. Web: the Firebase pop-up, without the Drive scope.
// Firebase failures are logged and reported as false; they never block Drive.
class FirebaseAuthBridge {
  FirebaseAuthBridge({FirebaseAuth? auth}) : _authOverride = auth;

  final FirebaseAuth? _authOverride;

  // Resolved on first use so constructing the bridge needs no Firebase app.
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

  bool get isSignedIn => _auth.currentUser != null;

  String? get signedInEmail => _auth.currentUser?.email;

  // Waits for Firebase to load a persisted session (web restores it async).
  Future<bool> restore() async {
    try {
      final User? user = await _auth.authStateChanges().first;
      return user != null;
    } catch (error) {
      debugPrint('Firebase Auth: restore failed: $error');
      return false;
    }
  }

  Future<bool> signInWithGoogleAccount(GoogleSignInAccount account) async {
    try {
      if (_auth.currentUser != null) {
        return true;
      }

      final GoogleSignInAuthentication tokens = await account.authentication;

      if (tokens.idToken == null && tokens.accessToken == null) {
        debugPrint('Firebase Auth: Google account returned no tokens.');
        return false;
      }

      final OAuthCredential credential = GoogleAuthProvider.credential(
        idToken: tokens.idToken,
        accessToken: tokens.accessToken,
      );
      await _auth.signInWithCredential(credential);
      return _auth.currentUser != null;
    } catch (error) {
      debugPrint('Firebase Auth: credential sign-in failed: $error');
      return false;
    }
  }

  Future<bool> signInWithPopup() async {
    try {
      if (_auth.currentUser != null) {
        return true;
      }

      await _auth.signInWithPopup(GoogleAuthProvider());
      return _auth.currentUser != null;
    } catch (error) {
      debugPrint('Firebase Auth: pop-up sign-in failed: $error');
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (error) {
      debugPrint('Firebase Auth: sign-out failed: $error');
    }
  }
}
