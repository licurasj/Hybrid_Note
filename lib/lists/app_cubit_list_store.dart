import '../app_cubit.dart';
import 'builtin_templates.dart';
import 'list_rules.dart';
import 'list_store.dart';

// ListStore over today's AppCubit: changes become AppData updates with the
// usual tombstones, local save and Drive auto-sync.
class AppCubitListStore implements ListStore {
  const AppCubitListStore(this.cubit);

  final AppCubit cubit;

  @override
  Future<void> apply(ListChanges changes) {
    return cubit.applyListChanges(changes);
  }

  // Task categories are the only user options in the built-in lists.
  @override
  Future<void> addOption(String listId, String fieldKey, String value) async {
    if (listId == BuiltinTemplates.tasksId && fieldKey == 'category') {
      await cubit.addCategory(value);
    }
  }

  @override
  Future<void> removeOption(String listId, String fieldKey, String value) async {
    if (listId == BuiltinTemplates.tasksId && fieldKey == 'category') {
      await cubit.deleteCategory(value);
    }
  }

  @override
  Future<void> refresh() {
    return cubit.syncWithDrive();
  }
}
