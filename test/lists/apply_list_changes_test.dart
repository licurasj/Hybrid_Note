import 'package:flutter_test/flutter_test.dart';

import 'package:hybrid_note/app_cubit.dart';
import 'package:hybrid_note/app_data.dart';
import 'package:hybrid_note/journal_entry.dart';
import 'package:hybrid_note/lists/builtin_templates.dart';
import 'package:hybrid_note/lists/legacy_lists.dart';
import 'package:hybrid_note/lists/list_item.dart';
import 'package:hybrid_note/lists/list_rules.dart';
import 'package:hybrid_note/task_item.dart';

import '../support/fakes.dart';

final DateTime _t0 = DateTime.utc(2026, 3, 1, 9);

TaskItem _task() {
  return TaskItem(
    id: 't1',
    title: 'Pay rent',
    description: '',
    isCompleted: false,
    category: '',
    subtasks: [
      SubtaskItem(id: 's1', title: 'A', isCompleted: false, createdAt: _t0, updatedAt: _t0),
      SubtaskItem(id: 's2', title: 'B', isCompleted: false, createdAt: _t0, updatedAt: _t0),
    ],
    reminderAt: null,
    repeatFrequency: RepeatFrequency.none,
    customRepeatDays: null,
    createdAt: _t0,
    updatedAt: _t0,
  );
}

void main() {
  late FakeAppStorage storage;
  late AppCubit cubit;

  setUp(() async {
    storage = FakeAppStorage()
      ..data = AppData.empty('d').copyWith(
        tasks: [_task()],
        journalEntries: [
          JournalEntry(id: 'j1', title: 'Day', body: '', createdAt: _t0, updatedAt: _t0),
        ],
      );
    cubit = AppCubit(
      storage: storage,
      driveSyncService: FakeDriveSyncService(),
      deviceId: 'd',
    );
    await cubit.loadData();
  });

  tearDown(() => cubit.close());

  test('editing a task saves it, records removed sub-items and new categories', () async {
    final ListItem item = LegacyLists.taskToItem(_task());
    final ListItem edited = ListRules.withValues(item, {
      'title': 'Pay rent today',
      'category': 'Home',
      'subtasks': [(item['subtasks'] as List).first],
    }, DateTime.now().toUtc());

    await cubit.applyListChanges(ListChanges(saved: [edited]));

    final AppData data = storage.data;
    expect(data.tasks.single.title, 'Pay rent today');
    expect(data.tasks.single.subtasks.map((s) => s.id), ['s1']);
    expect(data.subtaskTombstones.map((t) => t.id), contains('s2'));
    expect(data.categories, contains('Home'));
  });

  test('new items are added to the right list', () async {
    await cubit.applyListChanges(
      ListChanges(
        saved: [
          ListItem(
            id: 'w1',
            listId: BuiltinTemplates.watchReadId,
            values: const {'title': 'Dune', 'type': 'book', 'status': 'planned'},
            createdAt: _t0,
            updatedAt: _t0,
          ),
        ],
      ),
    );

    expect(storage.data.watchItems.single.title, 'Dune');
    expect(storage.data.tasks, hasLength(1));
  });

  test('deletions remove the item and leave a tombstone in its own list', () async {
    await cubit.applyListChanges(const ListChanges(deletedIds: ['j1']));

    expect(storage.data.journalEntries, isEmpty);
    expect(storage.data.journalTombstones.map((t) => t.id), ['j1']);
    expect(storage.data.taskTombstones, isEmpty);
  });
}
