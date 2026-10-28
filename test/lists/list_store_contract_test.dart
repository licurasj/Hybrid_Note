import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:hybrid_note/app_cubit.dart';
import 'package:hybrid_note/lists/builtin_templates.dart';
import 'package:hybrid_note/lists/custom_lists.dart';
import 'package:hybrid_note/lists/list_catalog.dart';
import 'package:hybrid_note/lists/list_definition.dart';
import 'package:hybrid_note/lists/list_item.dart';
import 'package:hybrid_note/lists/list_patch.dart';
import 'package:hybrid_note/lists/list_rules.dart';
import 'package:hybrid_note/lists/list_store.dart';
import 'package:hybrid_note/lists/list_vocabulary.dart';
import 'package:hybrid_note/lists/local_list_store.dart';

import '../support/fakes.dart';

// The ListStore contract, written against the interface only. Every store
// runs it: LocalListStore below, FirestoreListStore in Backend's tests
// (import this file with `show listStoreContract`).
//
// `create` returns an empty store that holds the four built-in lists and no
// lists of the user; `dispose` releases it after each test. Each test first
// waits for the initial load (watch() emits nothing before it, D-12). Writes
// may reach the read side later than they finish and in steps (a list before
// its items), so the tests wait on watch() for all of the state they assert.
void listStoreContract(
  String name,
  Future<ListStore> Function() create, {
  Future<void> Function(ListStore store)? dispose,
}) {
  group('ListStore contract: $name', () {
    late ListStore store;

    setUp(() async {
      store = await create();
      await store.watch().first.timeout(const Duration(seconds: 10));
    });

    tearDown(() async {
      await dispose?.call(store);
    });

    Future<ListCatalog> until(bool Function(ListCatalog catalog) test) {
      return store.watch().firstWhere(test).timeout(const Duration(seconds: 10));
    }

    test('the initial load holds the built-ins and no lists of the user', () async {
      final ListCatalog first = await store.watch().first.timeout(const Duration(seconds: 10));
      expect(first.definitions.map((d) => d.id), containsAll(_builtinIds));
      expect(store.current.definitions.map((d) => d.id), containsAll(_builtinIds));
      expect(first.definition(_plantsId), isNull);
    });

    test('read after create: the list and its items', () async {
      final List<String> errors = await store.createList(_plants(), items: [_plant('fern', 'fern')]);
      expect(errors, isEmpty);

      final ListCatalog catalog = await until(
        (c) => c.definition(_plantsId) != null && c.itemsOf(_plantsId).length == 1,
      );
      expect(catalog.definition(_plantsId)!.toJson(), _plants().toJson());
      expect(catalog.itemsOf(_plantsId).single.toJson(), _plant('fern', 'fern').toJson());
      // The user's lists come after the built-ins.
      expect(catalog.definitions.last.id, _plantsId);
      expect(store.current.definition(_plantsId), isNotNull);
    });

    test('create refuses an invalid definition, bad or duplicate items and a taken id', () async {
      final ListDefinition noName = ListDefinition.fromJson({..._plantsJson(), 'name': ''});
      expect(await store.createList(noName), isNotEmpty);
      final ListItem untitled = ListItem(
        id: 'nameless',
        listId: _plantsId,
        values: const {'kind': 'fern'},
        createdAt: _t0,
        updatedAt: _t0,
      );
      expect(await store.createList(_plants(), items: [untitled]), isNotEmpty);
      // Two items with one id cannot both be kept (one document per item).
      expect(
        await store.createList(_plants(), items: [_plant('fern', 'fern'), _plant('fern', 'cactus')]),
        isNotEmpty,
      );
      await pumpEventQueue();
      expect(store.current.definition(_plantsId), isNull);
      expect(store.current.itemsOf(_plantsId), isEmpty);

      expect(await store.createList(_plants()), isEmpty);
      await until((c) => c.definition(_plantsId) != null);
      expect(await store.createList(_plants()), isNotEmpty);
      final ListDefinition builtin = ListDefinition.fromJson({
        ..._plantsJson(),
        'id': BuiltinTemplates.tasksId,
      });
      expect(await store.createList(builtin), isNotEmpty);
    });

    test('item save, edit and delete', () async {
      await store.createList(_plants());
      await until((c) => c.definition(_plantsId) != null);

      await store.apply(ListChanges(saved: [_plant('fern', 'fern'), _plant('cactus', 'cactus')]));
      ListCatalog catalog = await until((c) => c.itemsOf(_plantsId).length == 2);

      final ListItem fern = catalog.itemsOf(_plantsId).firstWhere((i) => i.id == 'fern');
      final ListItem edited = ListItem(
        id: fern.id,
        listId: fern.listId,
        values: const {'title': 'Big fern', 'kind': 'fern'},
        createdAt: fern.createdAt,
        updatedAt: _t0.add(const Duration(hours: 1)),
      );
      await store.apply(ListChanges(saved: [edited], deletedIds: const ['cactus']));
      catalog = await until(
        (c) => c.itemsOf(_plantsId).length == 1 && c.itemsOf(_plantsId).single['title'] == 'Big fern',
      );
      expect(catalog.itemsOf(_plantsId).single.id, 'fern');
    });

    test('patch: valid ops are applied to the current items and saved', () async {
      await store.createList(_plants(), items: [_plant('fern', 'fern')]);
      await until((c) => c.itemsOf(_plantsId).isNotEmpty);
      // An item added after the caller last looked is migrated too.
      await store.apply(ListChanges(saved: [_plant('cactus', 'cactus')]));
      await until((c) => c.itemsOf(_plantsId).length == 2);

      // A kind like "fern" is no whole number, so both values are hidden.
      final ListPatchResult? result = await store.patchList(_plantsId, const [
        ListPatchOp(PatchOpKind.renameField, {'key': 'kind', 'label': 'Pots'}),
        ListPatchOp(PatchOpKind.changeFieldType, {'key': 'kind', 'type': 'counter'}),
        ListPatchOp(PatchOpKind.addField, {
          'field': {'key': 'water', 'type': 'text', 'label': 'Water every'},
        }),
      ]);
      expect(result, isNotNull);
      expect(result!.errors, isEmpty);
      expect(result.hiddenValues, 2);

      final ListCatalog catalog = await until(
        (c) =>
            c.definition(_plantsId)!.field('water') != null &&
            c.itemsOf(_plantsId).length == 2 &&
            c.itemsOf(_plantsId).every((item) => item[ListPatch.legacyKey] != null),
      );
      final ListDefinition definition = catalog.definition(_plantsId)!;
      expect(definition.field('kind')!.label, 'Pots');
      expect(definition.field('kind')!.type, FieldType.counter);
      expect(
        {for (final ListItem item in catalog.itemsOf(_plantsId)) item.id: item[ListPatch.legacyKey]},
        {
          'fern': {'kind': ['fern']},
          'cactus': {'kind': ['cactus']},
        },
      );
    });

    test('patch: invalid ops are refused and change nothing', () async {
      await store.createList(_plants(), items: [_plant('fern', 'fern')]);
      await until((c) => c.itemsOf(_plantsId).isNotEmpty);

      final ListPatchResult? result = await store.patchList(_plantsId, const [
        ListPatchOp(PatchOpKind.addField, {
          'field': {'key': 'title', 'type': 'text', 'label': 'Again'},
        }),
      ]);
      expect(result, isNotNull);
      expect(result!.isValid, isFalse);
      expect(result.errors, isNotEmpty);
      expect(store.current.definition(_plantsId)!.toJson(), _plants().toJson());

      expect(await store.patchList('list-missing', const []), isNull);
    });

    test('delete and restore round trip', () async {
      await store.createList(_plants(), items: [_plant('fern', 'fern'), _plant('cactus', 'cactus')]);
      await until((c) => c.itemsOf(_plantsId).length == 2);

      final DeletedList? deleted = await store.deleteList(_plantsId);
      expect(deleted, isNotNull);
      expect(deleted!.definition.id, _plantsId);
      expect(deleted.items.map((i) => i.id), unorderedEquals(['fern', 'cactus']));
      ListCatalog catalog = await until(
        (c) => c.definition(_plantsId) == null && c.itemsOf(_plantsId).isEmpty,
      );
      expect(catalog.definitions.map((d) => d.id), isNot(contains(_plantsId)));

      await store.restoreList(deleted);
      catalog = await until((c) => c.definition(_plantsId) != null && c.itemsOf(_plantsId).length == 2);
      expect(catalog.definition(_plantsId)!.toJson(), _plants().toJson());

      expect(await store.deleteList('list-missing'), isNull);
    });

    test('built-in lists take name, icon, colour and AI changes through patchList', () async {
      final ListDefinition before = store.current.definition(BuiltinTemplates.groceryId)!;
      final ListPatchResult? result = await store.patchList(BuiltinTemplates.groceryId, const [
        ListPatchOp(PatchOpKind.setListInfo, {
          'name': 'Shopping',
          'icon': 'local_florist',
          'color': '#E53935',
          'aiAllowed': false,
        }),
      ]);
      expect(result?.errors, isEmpty);

      final ListCatalog catalog = await until((c) {
        final ListDefinition grocery = c.definition(BuiltinTemplates.groceryId)!;
        return grocery.name == 'Shopping' &&
            grocery.icon == 'local_florist' &&
            grocery.color == '#E53935' &&
            !grocery.aiAllowed;
      });
      final ListDefinition after = catalog.definition(BuiltinTemplates.groceryId)!;
      expect(before.icon, isNot('local_florist'));
      expect(before.aiAllowed, isTrue);
      expect(after.fields.map((f) => f.key), before.fields.map((f) => f.key));
      // The built-ins keep their place at the front.
      expect(
        catalog.definitions.map((d) => d.id).toList().indexOf(BuiltinTemplates.groceryId),
        store.current.definitions.map((d) => d.id).toList().indexOf(BuiltinTemplates.groceryId),
      );
    });

    test('add and remove a user option', () async {
      await store.createList(_plants());
      await until((c) => c.definition(_plantsId) != null);

      List<String> options(ListCatalog c) =>
          c.definition(_plantsId)!.field('kind')!.options.map((o) => o.value).toList();

      await store.addOption(_plantsId, 'kind', 'moss');
      ListCatalog catalog = await until((c) => options(c).contains('moss'));
      expect(options(catalog), ['fern', 'cactus', 'moss']);

      await store.removeOption(_plantsId, 'kind', 'moss');
      catalog = await until((c) => !options(c).contains('moss'));
      expect(options(catalog), ['fern', 'cactus']);
    });

    test('the read side emits after each write', () async {
      final List<ListCatalog> seen = [];
      final StreamSubscription<ListCatalog> subscription = store.watch().listen(seen.add);
      addTearDown(subscription.cancel);

      Future<void> expectEmit(Future<Object?> Function() write, bool Function(ListCatalog c) test) async {
        final int before = seen.length;
        await write();
        await until(test);
        await pumpEventQueue();
        expect(seen.length, greaterThan(before));
        expect(test(seen.last), isTrue);
      }

      await pumpEventQueue();
      expect(seen, isNotEmpty);

      await expectEmit(() => store.createList(_plants()), (c) => c.definition(_plantsId) != null);
      await expectEmit(
        () => store.apply(ListChanges(saved: [_plant('fern', 'fern')])),
        (c) => c.itemsOf(_plantsId).length == 1,
      );
      await expectEmit(
        () => store.apply(const ListChanges(deletedIds: ['fern'])),
        (c) => c.itemsOf(_plantsId).isEmpty,
      );
      await expectEmit(
        () => store.addOption(_plantsId, 'kind', 'moss'),
        (c) => c.definition(_plantsId)!.field('kind')!.options.length == 3,
      );
      await expectEmit(
        () => store.patchList(_plantsId, const [
          ListPatchOp(PatchOpKind.setListInfo, {'name': 'House plants'}),
        ]),
        (c) => c.definition(_plantsId)!.name == 'House plants',
      );
      await expectEmit(
        () => store.patchList(BuiltinTemplates.tasksId, const [
          ListPatchOp(PatchOpKind.setListInfo, {'name': 'To do'}),
        ]),
        (c) => c.definition(BuiltinTemplates.tasksId)!.name == 'To do',
      );
      late DeletedList deleted;
      await expectEmit(() async => deleted = (await store.deleteList(_plantsId))!, (c) => c.definition(_plantsId) == null && c.itemsOf(_plantsId).isEmpty);
      await expectEmit(() => store.restoreList(deleted), (c) => c.definition(_plantsId) != null);
    });
  });
}

const List<String> _builtinIds = [
  BuiltinTemplates.tasksId,
  BuiltinTemplates.groceryId,
  BuiltinTemplates.journalId,
  BuiltinTemplates.watchReadId,
];

const String _plantsId = 'list-plants';
final DateTime _t0 = DateTime.utc(2026, 3, 1);

Map<String, dynamic> _plantsJson() {
  return {
    'id': _plantsId,
    'name': 'Plants',
    'icon': 'local_florist',
    'color': '#43A047',
    'fields': [
      {'key': 'title', 'type': 'text', 'label': 'Plant', 'required': true, 'primary': true},
      {
        'key': 'kind',
        'type': 'category',
        'label': 'Kind',
        'options': [
          {'value': 'fern'},
          {'value': 'cactus'},
        ],
      },
    ],
    'view': {'kind': 'cards'},
    'updatedAt': _t0.toIso8601String(),
  };
}

ListDefinition _plants() => ListDefinition.fromJson(_plantsJson());

ListItem _plant(String id, String kind) {
  return ListItem(
    id: id,
    listId: _plantsId,
    values: {'title': id, 'kind': kind},
    createdAt: _t0,
    updatedAt: _t0,
  );
}

// Wraps a store and passes each change on in two steps, the lists first and
// their items one event later, as a Firestore store merging a lists
// listener with per-list item listeners may (D-12). The initial catalog is
// passed on whole. Running the contract through it checks that the tests
// wait for all of the state they assert.
class StaggeredListStore implements ListStore {
  StaggeredListStore(this.inner) {
    _subscription = inner.watch().listen((catalog) {
      _queue = _queue.then((_) => _pass(catalog));
    });
  }

  final ListStore inner;
  late final StreamSubscription<ListCatalog> _subscription;
  final StreamController<ListCatalog> _changes = StreamController<ListCatalog>.broadcast();
  Future<void> _queue = Future<void>.value();
  ListCatalog? _shown;

  Future<void> _pass(ListCatalog catalog) async {
    final ListCatalog? shown = _shown;
    if (shown != null) {
      _show(ListCatalog(definitions: catalog.definitions, items: shown.items));
      await Future<void>.delayed(Duration.zero);
    }
    _show(catalog);
  }

  void _show(ListCatalog catalog) {
    _shown = catalog;
    if (!_changes.isClosed) {
      _changes.add(catalog);
    }
  }

  Future<void> close() async {
    await _subscription.cancel();
    await _queue;
    await _changes.close();
  }

  @override
  ListCatalog get current => _shown ?? const ListCatalog(definitions: [], items: []);

  @override
  Stream<ListCatalog> watch() {
    late final StreamController<ListCatalog> controller;
    StreamSubscription<ListCatalog>? subscription;
    controller = StreamController<ListCatalog>(
      onListen: () {
        if (_shown != null) {
          controller.add(_shown!);
        }
        subscription = _changes.stream.listen(controller.add, onDone: controller.close);
      },
      onCancel: () => subscription?.cancel(),
    );
    return controller.stream;
  }

  @override
  Future<void> apply(ListChanges changes) => inner.apply(changes);

  @override
  Future<void> addOption(String listId, String fieldKey, String value) =>
      inner.addOption(listId, fieldKey, value);

  @override
  Future<void> removeOption(String listId, String fieldKey, String value) =>
      inner.removeOption(listId, fieldKey, value);

  @override
  Future<void> refresh() => inner.refresh();

  @override
  Future<List<String>> createList(ListDefinition definition, {List<ListItem> items = const []}) =>
      inner.createList(definition, items: items);

  @override
  Future<ListPatchResult?> patchList(String listId, List<ListPatchOp> ops) => inner.patchList(listId, ops);

  @override
  Future<DeletedList?> deleteList(String listId) => inner.deleteList(listId);

  @override
  Future<void> restoreList(DeletedList deleted) => inner.restoreList(deleted);
}

// A LocalListStore over in-memory storage, loaded; `close` releases it and
// its cubits.
Future<(LocalListStore, Future<void> Function())> _localStore() async {
  final AppCubit app = AppCubit(
    storage: FakeAppStorage(),
    driveSyncService: FakeDriveSyncService(),
    deviceId: 'd',
  );
  final CustomListsCubit custom = CustomListsCubit(FakeCustomListsStorage());
  await app.loadData();
  await custom.load();
  final LocalListStore store = LocalListStore(app, custom);
  return (
    store,
    () async {
      await store.close();
      await app.close();
      await custom.close();
    },
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Map<ListStore, Future<void> Function()> closers = {};
  Future<void> dispose(ListStore store) => closers.remove(store)!();

  listStoreContract(
    'LocalListStore',
    () async {
      final (LocalListStore store, Future<void> Function() close) = await _localStore();
      closers[store] = close;
      return store;
    },
    dispose: dispose,
  );

  listStoreContract(
    'LocalListStore with staggered updates',
    () async {
      final (LocalListStore local, Future<void> Function() close) = await _localStore();
      final StaggeredListStore store = StaggeredListStore(local);
      closers[store] = () async {
        await store.close();
        await close();
      };
      // The initial catalog arrives whole before the store is handed out.
      await store.watch().first;
      return store;
    },
    dispose: dispose,
  );

  group('LocalListStore', () {
    test('emits nothing until AppData and the custom-lists file are both loaded (D-12)', () async {
      final FakeCustomListsStorage files = FakeCustomListsStorage()
        ..data = CustomListsData(definitions: [_plants()], items: [_plant('fern', 'fern')]);
      final AppCubit app = AppCubit(
        storage: FakeAppStorage(),
        driveSyncService: FakeDriveSyncService(),
        deviceId: 'd',
      );
      final CustomListsCubit custom = CustomListsCubit(files);
      final LocalListStore store = LocalListStore(app, custom);
      addTearDown(() async {
        await store.close();
        await app.close();
        await custom.close();
      });
      final List<ListCatalog> seen = [];
      final StreamSubscription<ListCatalog> subscription = store.watch().listen(seen.add);
      addTearDown(subscription.cancel);

      await pumpEventQueue();
      expect(seen, isEmpty);
      expect(store.current.definitions, isEmpty);

      await app.loadData();
      await pumpEventQueue();
      expect(seen, isEmpty, reason: 'the custom lists are not loaded yet');

      await custom.load();
      await pumpEventQueue();
      expect(seen, isNotEmpty);
      for (final ListCatalog catalog in seen) {
        expect(catalog.definitions.map((d) => d.id), containsAll([..._builtinIds, _plantsId]));
        expect(catalog.itemsOf(_plantsId).single.id, 'fern');
      }
      expect(store.current.definition(_plantsId), isNotNull);
    });

    test('a built-in patch mixing info and other ops is refused whole', () async {
      final (LocalListStore store, Future<void> Function() close) = await _localStore();
      addTearDown(close);
      final ListDefinition before = store.current.definition(BuiltinTemplates.groceryId)!;

      final ListPatchResult? result = await store.patchList(BuiltinTemplates.groceryId, const [
        ListPatchOp(PatchOpKind.setListInfo, {'name': 'Shopping'}),
        ListPatchOp(PatchOpKind.addField, {
          'field': {'key': 'shop', 'type': 'text', 'label': 'Shop'},
        }),
      ]);
      expect(result, isNotNull);
      expect(result!.isValid, isFalse);
      await pumpEventQueue();

      final ListDefinition after = store.current.definition(BuiltinTemplates.groceryId)!;
      expect(after.toJson(), before.toJson());
      expect(store.custom.state.builtinInfo, isEmpty);
    });
  });
}
