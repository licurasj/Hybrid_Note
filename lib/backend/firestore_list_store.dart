import 'dart:async';
import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../lists/builtin_templates.dart';
import '../lists/list_catalog.dart';
import '../lists/list_definition.dart';
import '../lists/list_item.dart';
import '../lists/list_patch.dart';
import '../lists/list_rules.dart';
import '../lists/list_store.dart';

// ListStore over Firestore (Q-5 A): users/{uid}/lists/{listId} holds a
// definition and users/{uid}/lists/{listId}/items/{itemId} an item, each as
// its toJson(). The built-ins are ordinary definition documents with their
// fixed ids; writing them for a new user is the Block B switch-over's job.
//
// Reads come from one listener on the lists and one per list on its items.
// watch() emits nothing until the lists and every list's items have loaded
// (D-12); after that a change may arrive in steps. Documents that do not
// parse are skipped and reported, and the rest still loads (Q-8).
//
// Writes go out as batched writes of at most [batchLimit] documents, all
// committed at once so that offline they all queue in the local cache.
class FirestoreListStore implements ListStore {
  FirestoreListStore(
    this.firestore,
    this.uid, {
    void Function(String path, Object error)? onSkipped,
    this.batchLimit = maxBatchWrites,
  }) : _onSkipped = onSkipped ?? _log {
    _listsSubscription = _lists.snapshots().listen(
      _onLists,
      onError: (Object error) => _log(_lists.path, error),
    );
  }

  final FirebaseFirestore firestore;
  final String uid;
  final void Function(String path, Object error) _onSkipped;

  // Firestore's limit of writes in one batch; tests pass a smaller one.
  static const int maxBatchWrites = 500;
  final int batchLimit;

  // Firestore rejects an array directly inside an array, which a hidden
  // tags or checklist value in `_legacy` is (D-10). Such an inner list is
  // stored as {"__array": [...]}.
  static const String _arrayKey = '__array';

  CollectionReference<Map<String, dynamic>> get _lists =>
      firestore.collection('users').doc(uid).collection('lists');

  CollectionReference<Map<String, dynamic>> _itemsOf(String listId) =>
      _lists.doc(listId).collection('items');

  final Map<String, ListDefinition> _definitions = {};
  final Map<String, Map<String, ListItem>> _items = {};
  final Map<String, StreamSubscription<Object?>> _itemSubscriptions = {};
  late final StreamSubscription<Object?> _listsSubscription;
  // Paths already reported, so a skipped document is logged once.
  final Set<String> _reported = {};

  bool _listsLoaded = false;
  final Completer<void> _ready = Completer<void>();
  ListCatalog? _catalog;
  final StreamController<ListCatalog> _changes =
      StreamController<ListCatalog>.broadcast();

  static const ListCatalog _empty = ListCatalog(definitions: [], items: []);

  static void _log(String path, Object error) {
    developer.log('skipped $path: $error', name: 'FirestoreListStore');
  }

  void _skip(String path, Object error) {
    if (_reported.add(path)) {
      _onSkipped(path, error);
    }
  }

  void _onLists(QuerySnapshot<Map<String, dynamic>> snapshot) {
    _definitions.clear();
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in snapshot.docs) {
      try {
        final ListDefinition definition = ListDefinition.fromJson(
          _decode(doc.data()),
        );
        if (definition.id != doc.id) {
          throw FormatException('id "${definition.id}" is not the document id');
        }
        _definitions[doc.id] = definition;
        _reported.remove(doc.reference.path);
      } on Object catch (error) {
        _skip(doc.reference.path, error);
      }
    }

    for (final String listId in _itemSubscriptions.keys.toList()) {
      if (!_definitions.containsKey(listId)) {
        _itemSubscriptions.remove(listId)!.cancel();
        _items.remove(listId);
      }
    }
    for (final String listId in _definitions.keys) {
      _itemSubscriptions.putIfAbsent(
        listId,
        () => _itemsOf(listId).snapshots().listen(
          (snapshot) => _onItems(listId, snapshot),
          onError: (Object error) => _log(_itemsOf(listId).path, error),
        ),
      );
    }
    _listsLoaded = true;
    _update();
  }

  void _onItems(String listId, QuerySnapshot<Map<String, dynamic>> snapshot) {
    if (!_itemSubscriptions.containsKey(listId)) {
      return;
    }
    final Map<String, ListItem> items = {};
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in snapshot.docs) {
      try {
        final ListItem item = ListItem.fromJson(_decode(doc.data()));
        if (item.id != doc.id) {
          throw FormatException('id "${item.id}" is not the document id');
        }
        if (item.listId != listId) {
          throw FormatException('listId "${item.listId}" is not its list');
        }
        items[item.id] = item;
        _reported.remove(doc.reference.path);
      } on Object catch (error) {
        _skip(doc.reference.path, error);
      }
    }
    _items[listId] = items;
    _update();
  }

  // Loaded once the lists and every list's items have arrived.
  bool get _isLoaded =>
      _ready.isCompleted ||
      (_listsLoaded && _definitions.keys.every(_items.containsKey));

  void _update() {
    if (!_isLoaded || _changes.isClosed) {
      return;
    }
    if (!_ready.isCompleted) {
      _ready.complete();
    }
    _catalog = _build();
    _changes.add(_catalog!);
  }

  // The built-ins first, in their usual order, then the user's lists.
  ListCatalog _build() {
    const List<String> builtinOrder = [
      BuiltinTemplates.tasksId,
      BuiltinTemplates.groceryId,
      BuiltinTemplates.journalId,
      BuiltinTemplates.watchReadId,
    ];
    final List<String> userIds =
        _definitions.keys
            .where((id) => !BuiltinTemplates.isBuiltin(id))
            .toList()
          ..sort();
    final List<ListDefinition> definitions = [
      for (final String id in [...builtinOrder, ...userIds])
        if (_definitions[id] != null) _definitions[id]!,
    ];
    return ListCatalog(
      definitions: definitions,
      items: [
        for (final ListDefinition definition in definitions)
          ...?_items[definition.id]?.values,
      ],
    );
  }

  Future<void> close() async {
    await _listsSubscription.cancel();
    for (final StreamSubscription<Object?> subscription
        in _itemSubscriptions.values) {
      await subscription.cancel();
    }
    _itemSubscriptions.clear();
    await _changes.close();
  }

  // Empty until the initial load is complete.
  @override
  ListCatalog get current => _catalog ?? _empty;

  @override
  Stream<ListCatalog> watch() {
    late final StreamController<ListCatalog> controller;
    StreamSubscription<ListCatalog>? subscription;
    controller = StreamController<ListCatalog>(
      onListen: () {
        if (_catalog != null) {
          controller.add(_catalog!);
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

  // The list an item is stored under, from the loaded catalog.
  String? _listOfItem(String itemId) {
    for (final MapEntry<String, Map<String, ListItem>> entry
        in _items.entries) {
      if (entry.value.containsKey(itemId)) {
        return entry.key;
      }
    }
    return null;
  }

  // Commits the writes in batches of at most [batchLimit], in order. The
  // batches are committed together rather than one after the other, so
  // offline they all go into the local cache at once.
  Future<void> _write(List<void Function(WriteBatch batch)> writes) async {
    final List<Future<void>> commits = [];
    for (int start = 0; start < writes.length; start += batchLimit) {
      final WriteBatch batch = firestore.batch();
      for (final void Function(WriteBatch batch) write
          in writes.skip(start).take(batchLimit)) {
        write(batch);
      }
      commits.add(batch.commit());
    }
    await Future.wait(commits);
  }

  void Function(WriteBatch batch) _setDefinition(ListDefinition definition) {
    return (batch) => batch.set(
      _lists.doc(definition.id),
      _encode(definition.toJson()) as Map<String, dynamic>,
    );
  }

  void Function(WriteBatch batch) _setItem(ListItem item) {
    return (batch) => batch.set(
      _itemsOf(item.listId).doc(item.id),
      _encode(item.toJson()) as Map<String, dynamic>,
    );
  }

  void Function(WriteBatch batch) _deleteItem(String listId, String itemId) {
    return (batch) => batch.delete(_itemsOf(listId).doc(itemId));
  }

  @override
  Future<void> apply(ListChanges changes) async {
    await _ready.future;
    final List<void Function(WriteBatch batch)> writes = [];
    for (final ListItem item in changes.saved) {
      // An item that moved to another list leaves its old document.
      final String? from = _listOfItem(item.id);
      if (from != null && from != item.listId) {
        writes.add(_deleteItem(from, item.id));
      }
      writes.add(_setItem(item));
    }
    for (final String itemId in changes.deletedIds) {
      final String? listId = _listOfItem(itemId);
      if (listId != null) {
        writes.add(_deleteItem(listId, itemId));
      }
    }
    await _write(writes);
  }

  Future<void> _changeOptions(
    String listId,
    String fieldKey,
    List<FieldOption> Function(List<FieldOption> options) change,
  ) async {
    await _ready.future;
    final FieldDefinition? field = _definitions[listId]?.field(fieldKey);
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

  @override
  Future<void> addOption(String listId, String fieldKey, String value) {
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
    return _changeOptions(
      listId,
      fieldKey,
      (options) => options.where((option) => option.value != value).toList(),
    );
  }

  // The listeners keep the catalog current; there is nothing to pull.
  @override
  Future<void> refresh() async {}

  @override
  Future<List<String>> createList(
    ListDefinition definition, {
    List<ListItem> items = const [],
  }) async {
    await _ready.future;
    if (_definitions.containsKey(definition.id) ||
        BuiltinTemplates.isBuiltin(definition.id)) {
      return ['list "${definition.id}" already exists'];
    }
    // Item ids are unique across every list, since item deletes go by id.
    final Set<String> newIds = {};
    final List<String> errors = [
      ...definition.validate(),
      for (final ListItem item in items)
        if (!newIds.add(item.id))
          'item "${item.id}": duplicate id'
        else if (_listOfItem(item.id) != null)
          'item "${item.id}": id already used by another list',
      for (final ListItem item in items)
        if (item.listId != definition.id)
          'item "${item.id}": belongs to list "${item.listId}"'
        else
          for (final String error in item.validateAgainst(definition))
            'item "${item.id}": $error',
    ];
    if (errors.isEmpty) {
      await _write([_setDefinition(definition), ...items.map(_setItem)]);
    }
    return errors;
  }

  // Provisional until the owner answers Q-16 (T-14): the ops are applied to
  // the cached list and saved as a batch, with no transaction and no repair
  // of items another device adds meanwhile.
  @override
  Future<ListPatchResult?> patchList(
    String listId,
    List<ListPatchOp> ops,
  ) async {
    await _ready.future;
    final ListDefinition? definition = _definitions[listId];
    if (definition == null) {
      return null;
    }
    final ListPatchResult result = ListPatch.apply(
      definition,
      _items[listId]?.values.toList() ?? const [],
      ops,
      DateTime.now().toUtc(),
    );
    if (result.isValid) {
      await _write([
        _setDefinition(result.definition),
        for (final ListItem item in result.items)
          if (result.changedItemIds.contains(item.id)) _setItem(item),
      ]);
    }
    return result;
  }

  // Deletes the items first and the list document last, so an interrupted
  // delete leaves the list visible rather than its items orphaned.
  @override
  Future<DeletedList?> deleteList(String listId) async {
    await _ready.future;
    final ListDefinition? definition = _definitions[listId];
    if (definition == null) {
      return null;
    }
    final List<ListItem> items = _items[listId]?.values.toList() ?? const [];
    await _write([
      for (final ListItem item in items) _deleteItem(listId, item.id),
      (batch) => batch.delete(_lists.doc(listId)),
    ]);
    return DeletedList(definition: definition, items: items);
  }

  @override
  Future<void> restoreList(DeletedList deleted) async {
    await _ready.future;
    await _write([
      _setDefinition(deleted.definition),
      ...deleted.items.map(_setItem),
    ]);
  }

  static Object? _encode(Object? value, {bool inList = false}) {
    if (value is Map) {
      return {
        for (final MapEntry<Object?, Object?> entry in value.entries)
          '${entry.key}': _encode(entry.value),
      };
    }
    if (value is List) {
      final List<Object?> list = [
        for (final Object? element in value) _encode(element, inList: true),
      ];
      return inList ? {_arrayKey: list} : list;
    }
    return value;
  }

  static Map<String, dynamic> _decode(Map<String, dynamic> data) {
    return _decodeValue(data) as Map<String, dynamic>;
  }

  static Object? _decodeValue(Object? value) {
    if (value is Map) {
      if (value.length == 1 && value[_arrayKey] is List) {
        return _decodeValue(value[_arrayKey]);
      }
      return <String, dynamic>{
        for (final MapEntry<Object?, Object?> entry in value.entries)
          '${entry.key}': _decodeValue(entry.value),
      };
    }
    if (value is List) {
      return [for (final Object? element in value) _decodeValue(element)];
    }
    return value;
  }
}
