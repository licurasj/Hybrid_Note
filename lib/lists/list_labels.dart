import '../l10n/generated/app_localizations.dart';
import 'list_definition.dart';
import 'list_vocabulary.dart';

// Turns the l10n keys used by built-in definitions into translated text. The
// generated AppLocalizations only has one getter per key, so the keys the
// built-ins use are listed here; a test checks none is missing.
class ListLabels {
  const ListLabels(this.loc);

  final AppLocalizations loc;

  String? lookup(String key) {
    switch (key) {
      case 'tasks':
        return loc.tasks;
      case 'grocery':
        return loc.grocery;
      case 'journal':
        return loc.journal;
      case 'watchRead':
        return loc.watchRead;
      case 'title':
        return loc.title;
      case 'description':
        return loc.description;
      case 'notes':
        return loc.notes;
      case 'entry':
        return loc.entry;
      case 'completed':
        return loc.completed;
      case 'category':
        return loc.category;
      case 'subtasks':
        return loc.subtasks;
      case 'date':
        return loc.date;
      case 'repeat':
        return loc.repeat;
      case 'section':
        return loc.section;
      case 'currentGroceryRun':
        return loc.currentGroceryRun;
      case 'nextTime':
        return loc.nextTime;
      case 'repeatsToNextTime':
        return loc.repeatsToNextTime;
      case 'type':
        return loc.type;
      case 'status':
        return loc.status;
      case 'movie':
        return loc.movie;
      case 'tvShow':
        return loc.tvShow;
      case 'book':
        return loc.book;
      case 'planned':
        return loc.planned;
      case 'inProgress':
        return loc.inProgress;
      case 'season':
        return loc.season;
      case 'episode':
        return loc.episode;
    }

    return null;
  }

  // Literal label first (user and AI lists), then the l10n key, then the
  // fallback so an unknown key still shows something readable.
  String resolve(String? label, String? labelKey, String fallback) {
    if (label != null && label.isNotEmpty) {
      return label;
    }

    if (labelKey != null) {
      return lookup(labelKey) ?? labelKey;
    }

    return fallback;
  }

  String listName(ListDefinition definition) {
    return resolve(definition.name, definition.nameKey, definition.id);
  }

  String field(FieldDefinition field) {
    return resolve(field.label, field.labelKey, field.key);
  }

  String option(FieldOption option) {
    return resolve(option.label, option.labelKey, option.value);
  }

  String recurrence(RecurrenceFrequency frequency) {
    switch (frequency) {
      case RecurrenceFrequency.none:
        return loc.doesNotRepeat;
      case RecurrenceFrequency.daily:
        return loc.daily;
      case RecurrenceFrequency.weekly:
        return loc.weekly;
      case RecurrenceFrequency.monthly:
        return loc.monthly;
      case RecurrenceFrequency.yearly:
        return loc.yearly;
      case RecurrenceFrequency.custom:
        return loc.custom;
    }
  }
}
