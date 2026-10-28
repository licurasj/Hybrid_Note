import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hybrid_note/backend/firestore_list_store.dart';
import 'package:hybrid_note/lists/builtin_templates.dart';
import 'package:hybrid_note/lists/list_definition.dart';
import 'package:hybrid_note/lists/list_item.dart';
import 'package:hybrid_note/lists/list_rules.dart';

// The user every test store belongs to.
const String testUid = 'user-1';

// One starter copy of each template, as a new account gets them (Q-22 D).
// Here a copy keeps its template's id as its list id, so a test can name
// the list (BuiltinTemplates.groceryId). The real seeding gives copies
// fresh ids, so nothing in lib/ may rely on these ids; it finds a copy's
// template by `templateId`.
List<ListDefinition> starterLists({List<String> taskCategories = const []}) {
  return BuiltinTemplates.all(taskCategories: taskCategories);
}

// A loaded FirestoreListStore on fake_cloud_firestore holding [lists]
// (the starter lists unless given) and [items], saved through the store.
// It is closed when the test ends.
Future<FirestoreListStore> fakeFirestoreStore({
  FakeFirebaseFirestore? firestore,
  List<ListDefinition>? lists,
  List<ListItem> items = const [],
}) async {
  final FakeFirebaseFirestore db = firestore ?? FakeFirebaseFirestore();
  for (final ListDefinition definition in lists ?? starterLists()) {
    await db
        .doc('users/$testUid/lists/${definition.id}')
        .set(definition.toJson());
  }
  final FirestoreListStore store = FirestoreListStore(db, testUid);
  addTearDown(store.close);
  await store.watch().first.timeout(const Duration(seconds: 10));
  if (items.isNotEmpty) {
    await store.apply(ListChanges(saved: items));
    await store
        .watch()
        .firstWhere(
          (catalog) => items.every(
            (item) => catalog.itemsOf(item.listId).any((i) => i.id == item.id),
          ),
        )
        .timeout(const Duration(seconds: 10));
  }
  return store;
}

// Widget tests: fake_cloud_firestore runs on the real event loop and does
// not advance with a widget test's fake clock, so FirestoreListStore's load
// never finishes there. The store is built in tester.runAsync, and [settle]
// gives its writes and snapshots real time before the widgets settle; use it
// wherever the test waits for the store.
Future<FirestoreListStore> widgetTestStore(
  WidgetTester tester, {
  List<ListDefinition>? lists,
  List<ListItem> items = const [],
}) async {
  return (await tester.runAsync(
    () => fakeFirestoreStore(lists: lists, items: items),
  ))!;
}

Future<void> settle(WidgetTester tester) async {
  for (int i = 0; i < 5; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}
