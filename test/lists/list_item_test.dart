import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:hybrid_note/app_data.dart';
import 'package:hybrid_note/grocery_item.dart';
import 'package:hybrid_note/journal_entry.dart';
import 'package:hybrid_note/lists/builtin_templates.dart';
import 'package:hybrid_note/lists/legacy_lists.dart';
import 'package:hybrid_note/lists/list_definition.dart';
import 'package:hybrid_note/lists/list_item.dart';
import 'package:hybrid_note/task_item.dart';
import 'package:hybrid_note/watch_item.dart';

final DateTime _created = DateTime.utc(2026, 3, 1, 9, 30);
final DateTime _updated = DateTime.utc(2026, 3, 2, 18, 5);

// Saves an item as JSON text and loads it again, as storage will.
ListItem _reload(ListItem item) {
  return ListItem.fromJson(jsonDecode(jsonEncode(item.toJson())));
}

TaskItem _task({
  String category = 'Work',
  DateTime? reminderAt,
  RepeatFrequency repeat = RepeatFrequency.none,
  int? customDays,
}) {
  return TaskItem(
    id: 'task-1',
    title: 'Pay rent',
    description: 'Before the 5th',
    isCompleted: true,
    category: category,
    subtasks: [
      SubtaskItem(
        id: 'sub-1',
        title: 'Check balance',
        isCompleted: true,
        createdAt: _created,
        updatedAt: _updated,
      ),
      SubtaskItem(
        id: 'sub-2',
        title: 'Transfer',
        isCompleted: false,
        createdAt: _created,
        updatedAt: _created,
      ),
    ],
    reminderAt: reminderAt,
    repeatFrequency: repeat,
    customRepeatDays: customDays,
    createdAt: _created,
    updatedAt: _updated,
  );
}

void main() {
  group('legacy lists round trip without loss', () {
    final Map<String, ListDefinition> definitions = {
      for (final ListDefinition definition
          in BuiltinTemplates.all(taskCategories: ['Work']))
        definition.id: definition,
    };

    void expectValid(ListItem item) {
      expect(item.validateAgainst(definitions[item.listId]!), isEmpty);
    }

    final Map<String, TaskItem> tasks = {
      'with reminder and custom repeat': _task(
        reminderAt: DateTime.utc(2026, 3, 5, 8),
        repeat: RepeatFrequency.custom,
        customDays: 10,
      ),
      'monthly repeat': _task(
        reminderAt: DateTime.utc(2026, 3, 31, 8),
        repeat: RepeatFrequency.monthly,
      ),
      'no reminder, uncategorised': _task(category: ''),
    };

    tasks.forEach((name, task) {
      test('task: $name', () {
        final ListItem item = _reload(LegacyLists.taskToItem(task));

        expectValid(item);
        expect(LegacyLists.itemToTask(item).toJson(), task.toJson());
      });
    });

    for (final GrocerySection section in GrocerySection.values) {
      test('grocery item in ${section.name}', () {
        final GroceryItem grocery = GroceryItem(
          id: 'g-${section.name}',
          title: 'Milk',
          description: '2 litres',
          section: section,
          isCompleted: section == GrocerySection.current,
          autoAddToNext: true,
          createdAt: _created,
          updatedAt: _updated,
        );
        final ListItem item = _reload(LegacyLists.groceryToItem(grocery));

        expectValid(item);
        expect(LegacyLists.itemToGrocery(item).toJson(), grocery.toJson());
      });
    }

    test('journal entry', () {
      final JournalEntry entry = JournalEntry(
        id: 'j-1',
        title: 'A good day',
        body: 'Line one\nLine two',
        createdAt: _created,
        updatedAt: _updated,
      );
      final ListItem item = _reload(LegacyLists.journalToItem(entry));

      expectValid(item);
      expect(LegacyLists.itemToJournal(item).toJson(), entry.toJson());
    });

    for (final MediaType type in MediaType.values) {
      for (final WatchStatus status in WatchStatus.values) {
        test('watch item ${type.name} / ${status.name}', () {
          final WatchItem watch = WatchItem(
            id: 'w-${type.name}-${status.name}',
            title: 'Dune',
            type: type,
            status: status,
            season: 2,
            episode: 7,
            notes: 'Rewatch',
            createdAt: _created,
            updatedAt: _updated,
          );
          final ListItem item = _reload(LegacyLists.watchToItem(watch));

          expectValid(item);
          expect(LegacyLists.itemToWatch(item).toJson(), watch.toJson());
        });
      }
    }
  });

  test('importing AppData yields the four lists and every item', () {
    final AppData data = AppData.empty('device-1').copyWith(
      categories: [AppData.defaultCategory, 'Home', 'Work'],
      tasks: [_task()],
      journalEntries: [
        JournalEntry(
          id: 'j-1',
          title: 'Entry',
          body: '',
          createdAt: _created,
          updatedAt: _created,
        ),
      ],
    );

    final LegacyImport imported = LegacyLists.importAppData(data);

    expect(
      imported.definitions.map((definition) => definition.id),
      [
        BuiltinTemplates.tasksId,
        BuiltinTemplates.groceryId,
        BuiltinTemplates.journalId,
        BuiltinTemplates.watchReadId,
      ],
    );
    // "All My Tasks" is the show-everything filter, not a category.
    expect(
      imported.definitions.first.field('category')!.options.map((o) => o.value),
      ['Home', 'Work'],
    );
    expect(imported.items.map((item) => item.id), ['task-1', 'j-1']);
  });

  group('value validation', () {
    final ListDefinition watch = BuiltinTemplates.watchRead();

    ListItem watchItem(Map<String, dynamic> values) {
      return ListItem(
        id: 'w',
        listId: watch.id,
        values: {'title': 'Dune', ...values},
        createdAt: _created,
        updatedAt: _created,
      );
    }

    test('an option that does not exist', () {
      expect(
        watchItem({'status': 'abandoned'}).validateAgainst(watch),
        contains(contains('"abandoned" is not an option')),
      );
    });

    test('a counter below its minimum', () {
      expect(
        watchItem({'season': -1}).validateAgainst(watch),
        contains(contains('must be at least 0')),
      );
    });

    test('a missing required field', () {
      final ListItem item = ListItem(
        id: 'w',
        listId: watch.id,
        values: const {},
        createdAt: _created,
        updatedAt: _created,
      );

      expect(
        item.validateAgainst(watch),
        contains('field "title" is required'),
      );
    });

    test('values of removed fields are kept and ignored', () {
      final ListItem item = _reload(watchItem({'_legacy': {'price': r'$3'}}));

      expect(item.validateAgainst(watch), isEmpty);
      expect(item['_legacy'], {'price': r'$3'});
    });

    test('custom repeat without a day count', () {
      final ListDefinition tasks = BuiltinTemplates.tasks();
      final ListItem item = LegacyLists.taskToItem(
        _task(
          category: '',
          reminderAt: _created,
          repeat: RepeatFrequency.custom,
        ),
      );

      expect(
        item.validateAgainst(tasks),
        contains(contains('custom frequency needs customDays')),
      );
    });
  });
}
