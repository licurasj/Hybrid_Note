import 'dart:async';
import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../lists/list_item.dart';
import 'firestore_list_store.dart';
import 'starter_lists.dart';

// Firestore for the app (Q-25 A, offline-first): the cache is on for
// Android and web, lists open from it, and sign-out clears it.
class FirestoreSetup {
  FirestoreSetup(this.firestore, {this.isWeb = kIsWeb});

  final FirebaseFirestore firestore;
  final bool isWeb;

  // Applies the cache settings. Firestore fixes its settings at first use,
  // so this must run before the first listener or read; main() calls it
  // right after Firebase.initializeApp. Android has persistence on by
  // default, web does not.
  void configure() {
    firestore.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  }

  // Opens the store for [uid] and writes the starter lists if the account
  // has none yet (StarterLists). The store opens at once from the cache;
  // seeding runs alongside, and its lists arrive through the store's
  // listener. [starter] completes with true when this call seeded, false
  // when the account was seeded before, and null when seeding failed (for
  // example offline); the failure goes to [onSeedError] and the next open
  // tries again.
  ({FirestoreListStore store, Future<bool?> starter}) openStore(
    String uid, {
    void Function(Object error)? onSeedError,
    void Function(String path, Object error)? onSkipped,
    Map<String, List<ListItem>> sampleItems = const {},
  }) {
    final FirestoreListStore store = FirestoreListStore(
      firestore,
      uid,
      onSkipped: onSkipped,
    );
    final Future<bool?> starter =
        StarterLists.ensure(firestore, uid, sampleItems: sampleItems)
            .then<bool?>((seeded) => seeded)
            .catchError((Object error) {
              (onSeedError ?? _logSeedError)(error);
              return null;
            });
    return (store: store, starter: starter);
  }

  static void _logSeedError(Object error) {
    developer.log('starter lists not written: $error', name: 'FirestoreSetup');
  }

  // Deletes the local cache, including writes not yet sent. Close every
  // store first: the instance is terminated, which ends its listeners.
  //
  // On Android the next use starts a fresh instance with the same settings.
  // On web the plugin keeps the terminated instance, so Firestore cannot be
  // used again until the page reloads ([reloadAfterClear]).
  Future<void> clearCache() async {
    await firestore.terminate();
    await firestore.clearPersistence();
  }

  bool get reloadAfterClear => isWeb;
}
