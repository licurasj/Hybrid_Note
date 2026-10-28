// The fixed set of building blocks a list definition may use. The renderer,
// the editor and the AI all work only with these. Each value's `wire` is its
// name in JSON and in schema/list_definition.schema.json; a test keeps the two
// in step.

abstract interface class WireName {
  String get wire;
}

enum FieldType implements WireName {
  text('text'),
  longText('longText'),
  checkbox('checkbox'),
  toggle('toggle'),
  number('number'),
  counter('counter'),
  rating('rating'),
  date('date'),
  dateTime('dateTime'),
  choice('enum'),
  category('category'),
  tags('tags'),
  url('url'),
  checklist('checklist'),
  recurrence('recurrence');

  const FieldType(this.wire);

  @override
  final String wire;

  // Types whose `options` list must be present.
  bool get needsOptions => this == choice;

  // Types whose options the user can extend while adding items.
  bool get hasUserOptions => this == category || this == tags;
}

enum FieldRole implements WireName {
  completion('completion'),
  reminder('reminder'),
  status('status'),
  section('section'),
  category('category');

  const FieldRole(this.wire);

  @override
  final String wire;
}

enum ViewKind implements WireName {
  checklist('checklist'),
  sectioned('sectioned'),
  timeline('timeline'),
  grouped('grouped'),
  table('table'),
  cards('cards');

  const ViewKind(this.wire);

  @override
  final String wire;
}

enum TimelineGrouping implements WireName {
  year('year'),
  month('month');

  const TimelineGrouping(this.wire);

  @override
  final String wire;
}

enum BehaviorKind implements WireName {
  recurOnClear('recurOnClear'),
  copyOnClear('copyOnClear'),
  moveAll('moveAll'),
  clearCompleted('clearCompleted');

  const BehaviorKind(this.wire);

  @override
  final String wire;
}

enum RecurrenceFrequency implements WireName {
  none('none'),
  daily('daily'),
  weekly('weekly'),
  monthly('monthly'),
  yearly('yearly'),
  custom('custom');

  const RecurrenceFrequency(this.wire);

  @override
  final String wire;
}

// Item metadata a view may sort or group by, besides the list's own fields.
const Set<String> itemMetaFields = {'createdAt', 'updatedAt'};

T? enumFromWire<T extends WireName>(List<T> values, Object? wire) {
  for (final T value in values) {
    if (value.wire == wire) {
      return value;
    }
  }

  return null;
}
