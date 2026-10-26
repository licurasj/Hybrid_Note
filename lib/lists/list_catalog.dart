import '../app_cubit.dart';
import '../app_state.dart';
import 'app_cubit_list_store.dart';
import 'builtin_templates.dart';
import 'custom_lists.dart';
import 'legacy_lists.dart';
import 'list_definition.dart';
import 'list_item.dart';
import 'list_patch.dart';
import 'list_rules.dart';
import 'list_store.dart';

// Every list the app shows: the four built-ins (from AppData, with any name,
// icon or colour changes) followed by the user's own lists.
class ListCatalog {
  const ListCatalog({required this.definitions, required this.items});

  final List<ListDefinition> definitions;
  final List<ListItem> items;

  factory ListCatalog.from(AppState app, CustomListsData custom) {
    final LegacyImport builtin = LegacyLists.importAppData(app.data);
    return ListCatalog(
      definitions: [
        for (final ListDefinition definition in builtin.definitions)
          _withInfo(definition, custom.builtinInfo[definition.id]),
        ...custom.definitions,
      ],
      items: [...builtin.items, ...custom.items],
    );
  }

  static ListDefinition _withInfo(
    ListDefinition definition,
    Map<String, dynamic>? info,
  ) {
    if (info == null || info.isEmpty) {
      return definition;
    }
    final ListDefinition patched = ListPatch.apply(definition, const [], [
      ListPatchOp(PatchOpKind.setListInfo, info),
    ], definition.updatedAt).definition;
    // Cosmetic changes do not count as a definition revision.
    return ListDefinition.fromJson({
      ...patched.toJson(),
      'schemaRevision': definition.schemaRevision,
    });
  }

  ListDefinition? definition(String listId) {
    return definitions
        .where((definition) => definition.id == listId)
        .firstOrNull;
  }

  List<ListItem> itemsOf(String listId) {
    return items.where((item) => item.listId == listId).toList();
  }
}

// Sends each change to where its list lives: built-ins to AppCubit (AppData
// and Drive sync), the user's own lists to CustomListsCubit.
class RoutingListStore implements ListStore {
  RoutingListStore(this.app, this.custom) : _builtin = AppCubitListStore(app);

  final AppCubit app;
  final CustomListsCubit custom;
  final AppCubitListStore _builtin;

  @override
  Future<void> apply(ListChanges changes) async {
    final Set<String> customIds = custom.state.items
        .map((item) => item.id)
        .toSet();
    final ListChanges builtinChanges = ListChanges(
      saved: changes.saved
          .where((item) => BuiltinTemplates.isBuiltin(item.listId))
          .toList(),
      deletedIds: changes.deletedIds
          .where((id) => !customIds.contains(id))
          .toList(),
    );
    final ListChanges customChanges = ListChanges(
      saved: changes.saved
          .where((item) => !BuiltinTemplates.isBuiltin(item.listId))
          .toList(),
      deletedIds: changes.deletedIds.where(customIds.contains).toList(),
    );

    if (!builtinChanges.isEmpty) {
      await _builtin.apply(builtinChanges);
    }
    if (!customChanges.isEmpty) {
      await custom.apply(customChanges);
    }
  }

  Future<void> _changeOptions(
    String listId,
    String fieldKey,
    List<FieldOption> Function(List<FieldOption> options) change,
  ) async {
    final ListDefinition? definition = custom.state.definitions
        .where((definition) => definition.id == listId)
        .firstOrNull;
    final FieldDefinition? field = definition?.field(fieldKey);
    if (definition == null || field == null) {
      return;
    }
    final List<ListPatchOp> ops = [
      ListPatchOp(PatchOpKind.setOptions, {
        'key': fieldKey,
        'options': change(
          field.options,
        ).map((option) => option.toJson()).toList(),
      }),
    ];
    final ListPatchResult result = ListPatch.apply(
      definition,
      custom.state.items.where((item) => item.listId == listId).toList(),
      ops,
      DateTime.now().toUtc(),
    );
    if (result.isValid) {
      await custom.savePatched(result, ops);
    }
  }

  @override
  Future<void> addOption(String listId, String fieldKey, String value) {
    if (BuiltinTemplates.isBuiltin(listId)) {
      return _builtin.addOption(listId, fieldKey, value);
    }
    return _changeOptions(
      listId,
      fieldKey,
      (options) => options.any((option) => option.value == value)
          ? options
          : [...options, FieldOption(value: value, label: value)],
    );
  }

  @override
  Future<void> removeOption(String listId, String fieldKey, String value) {
    if (BuiltinTemplates.isBuiltin(listId)) {
      return _builtin.removeOption(listId, fieldKey, value);
    }
    return _changeOptions(
      listId,
      fieldKey,
      (options) => options.where((option) => option.value != value).toList(),
    );
  }

  @override
  Future<void> refresh() => _builtin.refresh();
}
