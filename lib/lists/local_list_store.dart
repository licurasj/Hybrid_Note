import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../app_cubit.dart';
import '../app_state.dart';
import 'builtin_templates.dart';
import 'custom_lists.dart';
import 'legacy_lists.dart';
import 'list_catalog.dart';
import 'list_definition.dart';
import 'list_item.dart';
import 'list_patch.dart';
import 'list_rules.dart';
import 'list_store.dart';

// ListStore over today's storage: the four built-ins live in AppData (local
// save and Drive auto-sync through AppCubit), with their name, icon and
// colour changes kept beside the user's own lists in CustomListsCubit.
class LocalListStore implements ListStore {
  LocalListStore(this.app, this.custom) {
    _subscriptions = [
      app.stream.listen((_) => _update()),
      custom.stream.listen((_) => _update()),
    ];
    _customLoaded = custom.isLoaded;
    if (_isLoaded) {
      _ready.complete();
    } else {
      custom.loaded.then((_) {
        _customLoaded = true;
        _update();
      });
    }
  }

  final AppCubit app;
  final CustomListsCubit custom;

  // Provides a LocalListStore over the AppCubit and CustomListsCubit above it.
  static RepositoryProvider<ListStore> provider() {
    return RepositoryProvider<ListStore>(
      create: (context) => LocalListStore(
        context.read<AppCubit>(),
        context.read<CustomListsCubit>(),
      ),
      dispose: (store) => (store as LocalListStore).close(),
    );
  }

  // The last snapshot and the cubit states it was built from.
  ListCatalog? _catalog;
  AppState? _appState;
  CustomListsData? _customState;
  late final List<StreamSubscription<Object?>> _subscriptions;
  final StreamController<ListCatalog> _changes =
      StreamController<ListCatalog>.broadcast();

  // The built-ins first (with any name, icon or colour changes), then the
  // user's own lists.
  static ListCatalog catalogOf(AppState app, CustomListsData custom) {
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

  // Cubits deliver their stream events a little after the state changed, so
  // the snapshot follows the states themselves; writes read it right away.
  ListCatalog get _current {
    if (_catalog == null ||
        !identical(_appState, app.state) ||
        !identical(_customState, custom.state)) {
      _appState = app.state;
      _customState = custom.state;
      _catalog = catalogOf(app.state, custom.state);
    }
    return _catalog!;
  }

  // Nothing is read out until both stores have loaded (D-12): AppData and
  // the custom-lists file.
  bool _customLoaded = false;
  final Completer<void> _ready = Completer<void>();

  bool get _isLoaded => _customLoaded && !app.state.isLoading;

  static const ListCatalog _empty = ListCatalog(definitions: [], items: []);

  ListCatalog? _emitted;

  void _update() {
    if (!_isLoaded || _changes.isClosed) {
      return;
    }
    if (!_ready.isCompleted) {
      _ready.complete();
    }
    final ListCatalog catalog = _current;
    // Both cubits may report one change; emit each snapshot once.
    if (!identical(catalog, _emitted)) {
      _emitted = catalog;
      _changes.add(catalog);
    }
  }

  Future<void> close() async {
    for (final StreamSubscription<Object?> subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _changes.close();
  }

  // Empty until the initial load is complete.
  @override
  ListCatalog get current => _isLoaded ? _current : _empty;

  @override
  Stream<ListCatalog> watch() {
    late final StreamController<ListCatalog> controller;
    StreamSubscription<ListCatalog>? subscription;
    controller = StreamController<ListCatalog>(
      onListen: () {
        if (_isLoaded) {
          controller.add(_current);
        }
        subscription = _changes.stream.listen(
          controller.add,
          onDone: controller.close,
        );
      },
      onCancel: () => subscription?.cancel(),
    );
    return controller.stream;
  }

  // Sends each change to where its list lives.
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
      await app.applyListChanges(builtinChanges);
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
    await _ready.future;
    final FieldDefinition? field = custom.state.definitions
        .where((definition) => definition.id == listId)
        .firstOrNull
        ?.field(fieldKey);
    if (field == null) {
      return;
    }
    await patchList(listId, [
      ListPatchOp(PatchOpKind.setOptions, {
        'key': fieldKey,
        'options': change(
          field.options,
        ).map((option) => option.toJson()).toList(),
      }),
    ]);
  }

  // Task categories are the only user options in the built-in lists.
  @override
  Future<void> addOption(String listId, String fieldKey, String value) async {
    if (BuiltinTemplates.isBuiltin(listId)) {
      if (listId == BuiltinTemplates.tasksId && fieldKey == 'category') {
        await app.addCategory(value);
      }
      return;
    }
    await _changeOptions(
      listId,
      fieldKey,
      (options) => options.any((option) => option.value == value)
          ? options
          : [...options, FieldOption(value: value, label: value)],
    );
  }

  @override
  Future<void> removeOption(String listId, String fieldKey, String value) async {
    if (BuiltinTemplates.isBuiltin(listId)) {
      if (listId == BuiltinTemplates.tasksId && fieldKey == 'category') {
        await app.deleteCategory(value);
      }
      return;
    }
    await _changeOptions(
      listId,
      fieldKey,
      (options) => options.where((option) => option.value != value).toList(),
    );
  }

  @override
  Future<void> refresh() => app.syncWithDrive();

  @override
  Future<List<String>> createList(
    ListDefinition definition, {
    List<ListItem> items = const [],
  }) async {
    await _ready.future;
    if (_current.definition(definition.id) != null ||
        BuiltinTemplates.isBuiltin(definition.id)) {
      return ['list "${definition.id}" already exists'];
    }
    // Item ids must be unique: within the new list (one document per item
    // in Firestore) and, in this store, across every list, since item writes
    // are routed by id.
    final Set<String> usedIds = {
      for (final ListItem item in _current.items) item.id,
    };
    final Set<String> newIds = {};
    final List<String> errors = [
      ...definition.validate(),
      for (final ListItem item in items)
        if (!newIds.add(item.id))
          'item "${item.id}": duplicate id'
        else if (usedIds.contains(item.id))
          'item "${item.id}": id already used by another list',
      for (final ListItem item in items)
        if (item.listId != definition.id)
          'item "${item.id}": belongs to list "${item.listId}"'
        else
          for (final String error in item.validateAgainst(definition))
            'item "${item.id}": $error',
    ];
    if (errors.isEmpty) {
      await custom.createList(definition, items: items);
    }
    return errors;
  }

  @override
  Future<ListPatchResult?> patchList(
    String listId,
    List<ListPatchOp> ops,
  ) async {
    await _ready.future;
    final ListDefinition? definition = _current.definition(listId);
    if (definition == null) {
      return null;
    }
    final ListPatchResult result = ListPatch.apply(
      definition,
      _current.itemsOf(listId),
      ops,
      DateTime.now().toUtc(),
    );

    // Until the move to Firestore the built-ins' fields live in AppData, so
    // only their name, icon, colour and AI switch can change. Anything else
    // is refused rather than dropped.
    if (BuiltinTemplates.isBuiltin(listId)) {
      final List<String> refused = [
        for (final ListPatchOp op in ops)
          if (op.kind != PatchOpKind.setListInfo)
            'built-in list "$listId": only setListInfo is supported, '
                'not ${op.kind.wire}',
      ];
      if (refused.isNotEmpty) {
        return ListPatchResult(
          definition: definition,
          items: _current.itemsOf(listId),
          changedItemIds: const {},
          hiddenValues: 0,
          errors: refused,
        );
      }
    }

    if (result.isValid) {
      await custom.savePatched(result, ops);
    }
    return result;
  }

  @override
  Future<DeletedList?> deleteList(String listId) async {
    await _ready.future;
    // The built-ins cannot be deleted.
    return custom.deleteList(listId);
  }

  @override
  Future<void> restoreList(DeletedList deleted) async {
    await _ready.future;
    await custom.restoreList(deleted);
  }
}
