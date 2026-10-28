import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:hybrid_note/app_data.dart';
import 'package:hybrid_note/app_state.dart';
import 'package:hybrid_note/lists/builtin_templates.dart';
import 'package:hybrid_note/lists/custom_lists.dart';
import 'package:hybrid_note/lists/list_catalog.dart';
import 'package:hybrid_note/lists/list_definition.dart';
import 'package:hybrid_note/lists/list_item.dart';
import 'package:hybrid_note/lists/list_patch.dart';
import 'package:hybrid_note/lists/list_rules.dart';

import '../support/fakes.dart';

final DateTime _t0 = DateTime.utc(2026, 3, 1);

ListDefinition _plants() {
  return ListDefinition.fromJson({
    'id': 'list-plants',
    'name': 'Plants',
    'icon': 'local_florist',
    'color': '#43A047',
    'fields': [
      {'key': 'title', 'type': 'text', 'label': 'Plant', 'required': true, 'primary': true},
      {'key': 'water', 'type': 'text', 'label': 'Water every'},
    ],
    'view': {'kind': 'cards'},
    'updatedAt': _t0.toIso8601String(),
  });
}

ListItem _plant(String id, String water) {
  return ListItem(
    id: id,
    listId: 'list-plants',
    values: {'title': id, 'water': water},
    createdAt: _t0,
    updatedAt: _t0,
  );
}

void main() {
  late FakeCustomListsStorage storage;
  late CustomListsCubit cubit;

  setUp(() {
    storage = FakeCustomListsStorage();
    cubit = CustomListsCubit(storage);
  });

  tearDown(() => cubit.close());

  test('create, add items, patch with migration, all saved', () async {
    await cubit.createList(_plants());
    await cubit.apply(ListChanges(saved: [_plant('fern', '3'), _plant('cactus', 'rarely')]));

    final List<ListPatchOp> ops = const [
      ListPatchOp(PatchOpKind.changeFieldType, {'key': 'water', 'type': 'counter'}),
    ];
    final ListPatchResult result = ListPatch.apply(cubit.state.definitions.single, cubit.state.items, ops, _t0);
    await cubit.savePatched(result, ops);

    expect(storage.data.definitions.single.field('water')!.type.wire, 'counter');
    final Map<String, ListItem> items = {for (final ListItem item in storage.data.items) item.id: item};
    expect(items['fern']!['water'], 3);
    expect(items['cactus']!['_legacy'], {'water': 'rarely'});
  });

  test('delete removes the list and its items; undo brings both back', () async {
    await cubit.createList(_plants());
    await cubit.apply(ListChanges(saved: [_plant('fern', '3')]));

    final DeletedList? deleted = await cubit.deleteList('list-plants');
    expect(storage.data.definitions, isEmpty);
    expect(storage.data.items, isEmpty);

    await cubit.restoreList(deleted!);
    expect(storage.data.definitions.single.id, 'list-plants');
    expect(storage.data.items.single.id, 'fern');
  });

  test('built-in lists only take name, icon, colour and AI changes', () async {
    final ListDefinition tasks = BuiltinTemplates.tasks();
    final List<ListPatchOp> ops = const [
      ListPatchOp(PatchOpKind.setListInfo, {'name': 'To do', 'color': '#E53935'}),
    ];
    await cubit.savePatched(ListPatch.apply(tasks, const [], ops, _t0), ops);

    final ListCatalog catalog = ListCatalog.from(AppState.initial('d'), cubit.state);
    final ListDefinition shown = catalog.definition(BuiltinTemplates.tasksId)!;
    expect(shown.name, 'To do');
    expect(shown.color, '#E53935');
    expect(shown.fields.length, tasks.fields.length);
    expect(cubit.state.definitions, isEmpty);
  });

  test('the catalog lists built-ins first, then the user lists', () async {
    await cubit.createList(_plants());
    final ListCatalog catalog = ListCatalog.from(
      AppState.initial('d').copyWith(data: AppData.empty('d')),
      cubit.state,
    );

    expect(catalog.definitions.map((d) => d.id), [
      BuiltinTemplates.tasksId,
      BuiltinTemplates.groceryId,
      BuiltinTemplates.journalId,
      BuiltinTemplates.watchReadId,
      'list-plants',
    ]);
  });

  test('the file storage round-trips and never overwrites an unreadable file', () async {
    final Directory directory = await Directory.systemTemp.createTemp('hybrid_note_lists_');
    addTearDown(() => directory.delete(recursive: true));
    final CustomListsStorage files = CustomListsStorage(getDirectory: () async => directory);

    await files.save(CustomListsData(definitions: [_plants()], items: [_plant('fern', '3')]));
    final CustomListsData loaded = await files.load();
    expect(loaded.definitions.single.toJson(), _plants().toJson());
    expect(loaded.items.single.toJson(), _plant('fern', '3').toJson());

    final File file = File('${directory.path}/hybrid_note_custom_lists.json');
    await file.writeAsString('{broken');
    expect((await files.load()).definitions, isEmpty);
    expect(
      directory.listSync().whereType<File>().where((f) => f.path.contains('.unreadable-')),
      hasLength(1),
    );
  });

  test('overlapping file saves finish in call order; a failure does not block later saves', () async {
    final Directory directory = await Directory.systemTemp.createTemp('hybrid_note_lists_');
    addTearDown(() => directory.delete(recursive: true));
    bool fail = true;
    final CustomListsStorage files = CustomListsStorage(
      getDirectory: () async {
        if (fail) {
          fail = false;
          throw const FileSystemException('no folder');
        }
        return directory;
      },
    );

    final Future<void> failed = files.save(const CustomListsData());
    final List<Future<void>> saves = [
      for (int i = 0; i < 20; i++)
        files.save(CustomListsData(definitions: [_plants()], items: [_plant('fern', '$i')])),
    ];
    await expectLater(failed, throwsA(isA<FileSystemException>()));
    await Future.wait(saves);

    expect((await files.load()).items.single.toJson(), _plant('fern', '19').toJson());
    expect(File('${directory.path}/hybrid_note_custom_lists.json.tmp').existsSync(), isFalse);
  });
}
