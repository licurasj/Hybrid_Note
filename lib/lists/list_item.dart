import 'list_definition.dart';
import 'list_vocabulary.dart';

// One entry in any list. `values` maps field keys to JSON values:
//   text, longText, url, category: String
//   checkbox, toggle: bool
//   number: num; counter, rating: int
//   date, dateTime: ISO-8601 String
//   enum: String, one of the field's options
//   tags: List of String
//   checklist: List of {id, title, done, createdAt, updatedAt}
//   recurrence: {frequency, customDays?}
// Keys that are not (or no longer) fields of the list are kept and hidden, so
// removing a field never destroys data.
class ListItem {
  final String id;
  final String listId;
  final Map<String, dynamic> values;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ListItem({
    required this.id,
    required this.listId,
    required this.values,
    required this.createdAt,
    required this.updatedAt,
  });

  Object? operator [](String key) => values[key];

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'listId': listId,
      'values': values,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory ListItem.fromJson(Object? json) {
    if (json is! Map) {
      throw const FormatException('list item must be a JSON object');
    }

    final Map<String, dynamic> map = Map<String, dynamic>.from(json);
    final Object? id = map['id'];
    final Object? listId = map['listId'];
    final Object? values = map['values'];
    final DateTime? createdAt = DateTime.tryParse('${map['createdAt']}');
    final DateTime? updatedAt = DateTime.tryParse('${map['updatedAt']}');

    if (id is! String || listId is! String) {
      throw const FormatException('list item: id and listId must be strings');
    }

    if (values is! Map) {
      throw const FormatException('list item: values must be a JSON object');
    }

    if (createdAt == null || updatedAt == null) {
      throw const FormatException(
        'list item: createdAt and updatedAt must be ISO dates',
      );
    }

    return ListItem(
      id: id,
      listId: listId,
      values: Map<String, dynamic>.from(values),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  // Problems with this item's values for the given list; empty when valid.
  List<String> validateAgainst(ListDefinition definition) {
    final List<String> errors = [];

    if (listId != definition.id) {
      errors.add('item belongs to list "$listId", not "${definition.id}"');
    }

    for (final FieldDefinition field in definition.fields) {
      final Object? value = values[field.key];

      if (value == null) {
        if (field.required) {
          errors.add('field "${field.key}" is required');
        }
        continue;
      }

      final String? error = _valueError(field, value);
      if (error != null) {
        errors.add('field "${field.key}": $error');
      }
    }

    return errors;
  }

  static String? _valueError(FieldDefinition field, Object value) {
    switch (field.type) {
      case FieldType.text:
      case FieldType.longText:
      case FieldType.url:
      case FieldType.category:
        if (value is! String) {
          return 'must be a string';
        }
        if (field.required && value.trim().isEmpty) {
          return 'must not be empty';
        }
        return null;
      case FieldType.checkbox:
      case FieldType.toggle:
        return value is bool ? null : 'must be true or false';
      case FieldType.number:
        return value is num ? _rangeError(field, value) : 'must be a number';
      case FieldType.counter:
      case FieldType.rating:
        return value is int ? _rangeError(field, value) : 'must be a whole number';
      case FieldType.date:
      case FieldType.dateTime:
        return value is String && DateTime.tryParse(value) != null
            ? null
            : 'must be an ISO date';
      case FieldType.choice:
        return field.hasOption(value) ? null : '"$value" is not an option';
      case FieldType.tags:
        return value is List && value.every((tag) => tag is String)
            ? null
            : 'must be a list of strings';
      case FieldType.checklist:
        return _checklistError(value);
      case FieldType.recurrence:
        return _recurrenceError(value);
    }
  }

  static String? _rangeError(FieldDefinition field, num value) {
    if (field.min != null && value < field.min!) {
      return 'must be at least ${field.min}';
    }
    if (field.max != null && value > field.max!) {
      return 'must be at most ${field.max}';
    }
    return null;
  }

  static String? _checklistError(Object value) {
    if (value is! List) {
      return 'must be a list of sub-items';
    }

    for (final Object? entry in value) {
      if (entry is! Map ||
          entry['id'] is! String ||
          entry['title'] is! String ||
          entry['done'] is! bool) {
        return 'each sub-item needs id, title and done';
      }
    }

    return null;
  }

  static String? _recurrenceError(Object value) {
    if (value is! Map) {
      return 'must be {frequency, customDays?}';
    }

    final RecurrenceFrequency? frequency = enumFromWire(
      RecurrenceFrequency.values,
      value['frequency'],
    );
    if (frequency == null) {
      return 'unknown frequency "${value['frequency']}"';
    }

    final Object? customDays = value['customDays'];
    if (frequency == RecurrenceFrequency.custom &&
        (customDays is! int || customDays <= 0)) {
      return 'custom frequency needs customDays above 0';
    }

    return null;
  }
}
