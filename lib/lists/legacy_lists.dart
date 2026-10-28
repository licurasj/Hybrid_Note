import '../app_data.dart';
import '../grocery_item.dart';
import '../journal_entry.dart';
import '../task_item.dart';
import '../watch_item.dart';
import 'builtin_templates.dart';
import 'list_definition.dart';
import 'list_item.dart';

// Converts today's hand-written list classes to generic items and back. The
// one-time import into the new storage uses the forward direction; the reverse
// lets the old screens keep working while lists are ported one at a time, and
// lets tests prove that no data is lost.
class LegacyLists {
  // The four built-in definitions plus every item, from a v2 AppData.
  static LegacyImport importAppData(AppData data) {
    final List<String> categories = data.categories
        .where((category) => category != AppData.defaultCategory)
        .toList();

    return LegacyImport(
      definitions: BuiltinTemplates.all(taskCategories: categories),
      items: [
        ...data.tasks.map(taskToItem),
        ...data.groceryItems.map(groceryToItem),
        ...data.journalEntries.map(journalToItem),
        ...data.watchItems.map(watchToItem),
      ],
    );
  }

  static ListItem taskToItem(TaskItem task) {
    return ListItem(
      id: task.id,
      listId: BuiltinTemplates.tasksId,
      values: {
        'title': task.title,
        'description': task.description,
        'done': task.isCompleted,
        // An empty category means "uncategorised" in the old model.
        if (task.category.isNotEmpty) 'category': task.category,
        'subtasks': task.subtasks
            .map(
              (subtask) => {
                'id': subtask.id,
                'title': subtask.title,
                'done': subtask.isCompleted,
                'createdAt': subtask.createdAt.toIso8601String(),
                'updatedAt': subtask.updatedAt.toIso8601String(),
              },
            )
            .toList(),
        if (task.reminderAt != null)
          'reminderAt': task.reminderAt!.toIso8601String(),
        'repeat': {
          'frequency': task.repeatFrequency.name,
          if (task.customRepeatDays != null)
            'customDays': task.customRepeatDays,
        },
      },
      createdAt: task.createdAt,
      updatedAt: task.updatedAt,
    );
  }

  static TaskItem itemToTask(ListItem item) {
    final Map<String, dynamic> repeat = _map(item['repeat']);

    return TaskItem(
      id: item.id,
      title: _string(item['title']),
      description: _string(item['description']),
      isCompleted: item['done'] == true,
      category: _string(item['category']),
      subtasks: _list(item['subtasks'])
          .map(
            (subtask) => SubtaskItem.fromJson({
              'id': subtask['id'],
              'title': subtask['title'],
              'isCompleted': subtask['done'],
              'createdAt': subtask['createdAt'],
              'updatedAt': subtask['updatedAt'],
            }),
          )
          .toList(),
      reminderAt: _date(item['reminderAt']),
      repeatFrequency: RepeatFrequency.values.firstWhere(
        (frequency) => frequency.name == repeat['frequency'],
        orElse: () => RepeatFrequency.none,
      ),
      customRepeatDays: repeat['customDays'] as int?,
      createdAt: item.createdAt,
      updatedAt: item.updatedAt,
    );
  }

  static ListItem groceryToItem(GroceryItem grocery) {
    return ListItem(
      id: grocery.id,
      listId: BuiltinTemplates.groceryId,
      values: {
        'title': grocery.title,
        'description': grocery.description,
        'done': grocery.isCompleted,
        'section': grocery.section.name,
        'autoAddToNext': grocery.autoAddToNext,
      },
      createdAt: grocery.createdAt,
      updatedAt: grocery.updatedAt,
    );
  }

  static GroceryItem itemToGrocery(ListItem item) {
    return GroceryItem(
      id: item.id,
      title: _string(item['title']),
      description: _string(item['description']),
      section: GrocerySection.values.firstWhere(
        (section) => section.name == item['section'],
        orElse: () => GrocerySection.current,
      ),
      isCompleted: item['done'] == true,
      autoAddToNext: item['autoAddToNext'] == true,
      createdAt: item.createdAt,
      updatedAt: item.updatedAt,
    );
  }

  static ListItem journalToItem(JournalEntry entry) {
    return ListItem(
      id: entry.id,
      listId: BuiltinTemplates.journalId,
      values: {
        'title': entry.title,
        'body': entry.body,
      },
      createdAt: entry.createdAt,
      updatedAt: entry.updatedAt,
    );
  }

  static JournalEntry itemToJournal(ListItem item) {
    return JournalEntry(
      id: item.id,
      title: _string(item['title']),
      body: _string(item['body']),
      createdAt: item.createdAt,
      updatedAt: item.updatedAt,
    );
  }

  static ListItem watchToItem(WatchItem watch) {
    return ListItem(
      id: watch.id,
      listId: BuiltinTemplates.watchReadId,
      values: {
        'title': watch.title,
        'type': watch.type.name,
        'status': watch.status.name,
        'season': watch.season,
        'episode': watch.episode,
        'notes': watch.notes,
      },
      createdAt: watch.createdAt,
      updatedAt: watch.updatedAt,
    );
  }

  static WatchItem itemToWatch(ListItem item) {
    return WatchItem(
      id: item.id,
      title: _string(item['title']),
      type: MediaType.values.firstWhere(
        (type) => type.name == item['type'],
        orElse: () => MediaType.movie,
      ),
      status: WatchStatus.values.firstWhere(
        (status) => status.name == item['status'],
        orElse: () => WatchStatus.planned,
      ),
      season: item['season'] as int? ?? 0,
      episode: item['episode'] as int? ?? 0,
      notes: _string(item['notes']),
      createdAt: item.createdAt,
      updatedAt: item.updatedAt,
    );
  }

  static String _string(Object? value) => value is String ? value : '';

  static DateTime? _date(Object? value) {
    return value is String ? DateTime.tryParse(value) : null;
  }

  static Map<String, dynamic> _map(Object? value) {
    return value is Map ? Map<String, dynamic>.from(value) : const {};
  }

  static List<Map<String, dynamic>> _list(Object? value) {
    if (value is! List) {
      return const [];
    }

    return value
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList();
  }
}

class LegacyImport {
  final List<ListDefinition> definitions;
  final List<ListItem> items;

  const LegacyImport({
    required this.definitions,
    required this.items,
  });
}
