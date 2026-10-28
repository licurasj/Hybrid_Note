import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:hybrid_note/app_cubit.dart';
import 'package:hybrid_note/lists/builtin_templates.dart';
import 'package:hybrid_note/lists/custom_lists.dart';
import 'package:hybrid_note/lists/list_catalog.dart';
import 'package:hybrid_note/lists/list_definition.dart';
import 'package:hybrid_note/lists/list_item.dart';
import 'package:hybrid_note/lists/local_list_store.dart';

import '../support/fakes.dart';

// LocalListStore no longer runs the shared contract, which now describes
// the template lists of Q-22 D. Its load order stays tested until T-17
// unit 3 deletes it with this file.
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
  });
}
