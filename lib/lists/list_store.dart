import 'list_catalog.dart';
import 'list_definition.dart';
import 'list_item.dart';
import 'list_patch.dart';
import 'list_rules.dart';

// Where the screens read and write lists. LocalListStore keeps today's
// storage behind it (AppData with Drive sync for the built-ins, a local file
// for the user's own lists); FirestoreListStore will implement the same
// interface and run the same contract tests
// (test/lists/list_store_contract_test.dart).
//
// Fit for Firestore (Q-5 A: lists/{listId} with an items subcollection, in
// the list engine JSON format):
// - Every write is async and may finish after the UI moved on; the read side
//   reports the result, so callers do not wait for it to redraw.
// - Ids are made by the client (list and item ids are UUID-based), so a
//   write never waits for the store to hand out an id.
// - patchList applies the ops on the store's current data, not on what the
//   caller saw (Q-12 A); in Firestore that is a transaction over the list
//   document and its items, so two devices cannot overwrite each other.
// - deleteList is a subtree delete (the list document and all its items); it
//   returns what restoreList needs to bring both back (Undo, D-5).
// - A store may refuse a write. patchList and createList return the reasons
//   and change nothing in that case.
abstract interface class ListStore {
  // Read side (Q-11 A): one snapshot of every list and item. watch() emits
  // the current snapshot to each new listener, then once after each change.
  ListCatalog get current;
  Stream<ListCatalog> watch();

  // Item writes.
  Future<void> apply(ListChanges changes);

  // Adds or removes a user option of a category or tags field (for example a
  // task category). Removing may be refused while items still use it.
  Future<void> addOption(String listId, String fieldKey, String value);
  Future<void> removeOption(String listId, String fieldKey, String value);

  Future<void> refresh();

  // List writes. createList validates the definition and items and returns
  // the errors; empty means the list was created.
  Future<List<String>> createList(
    ListDefinition definition, {
    List<ListItem> items = const [],
  });

  // Applies ops to the list's current definition and items and saves the
  // result only when it is valid. Name, icon, colour and AI changes of the
  // built-in lists go through here too (setListInfo). Returns null when the
  // list does not exist.
  Future<ListPatchResult?> patchList(String listId, List<ListPatchOp> ops);

  // Returns null when the list does not exist or cannot be deleted.
  Future<DeletedList?> deleteList(String listId);
  Future<void> restoreList(DeletedList deleted);
}

// A deleted list with its items, kept in memory so Undo can bring it back
// (D-5).
class DeletedList {
  const DeletedList({required this.definition, required this.items});

  final ListDefinition definition;
  final List<ListItem> items;
}
