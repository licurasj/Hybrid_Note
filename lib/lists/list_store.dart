import 'list_rules.dart';

// Where the generic screens read and write lists. Today AppCubitListStore
// maps everything onto AppData and Drive sync; a Firestore store will
// implement the same interface.
abstract interface class ListStore {
  Future<void> apply(ListChanges changes);

  // Adds or removes a user option of a category or tags field (for example a
  // task category). Removing may be refused while items still use it.
  Future<void> addOption(String listId, String fieldKey, String value);
  Future<void> removeOption(String listId, String fieldKey, String value);

  Future<void> refresh();
}
