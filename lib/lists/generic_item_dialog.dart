import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../l10n/generated/app_localizations.dart';
import 'list_definition.dart';
import 'list_item.dart';
import 'list_labels.dart';
import 'list_rules.dart';
import 'list_vocabulary.dart';

// Add/edit dialog generated from a definition's fields. Pops the edited item,
// or nothing when cancelled. Values of fields it does not show are kept.
class GenericItemDialog extends StatefulWidget {
  const GenericItemDialog({
    super.key,
    required this.definition,
    required this.title,
    this.item,
    this.initialValues = const {},
  });

  final ListDefinition definition;
  final String title;
  final ListItem? item;
  // Pre-filled values for a new item, e.g. the category filter in use.
  final Map<String, dynamic> initialValues;

  @override
  State<GenericItemDialog> createState() {
    return _GenericItemDialogState();
  }
}

class _SubItemDraft {
  _SubItemDraft({
    required this.id,
    required this.done,
    required String title,
    this.original,
  }) : controller = TextEditingController(text: title);

  final String id;
  bool done;
  final TextEditingController controller;
  final Map<String, dynamic>? original;
}

class _GenericItemDialogState extends State<GenericItemDialog> {
  late final Map<String, dynamic> _values;
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, List<_SubItemDraft>> _subItems = {};
  final Map<String, TextEditingController> _customDays = {};
  String? _error;

  static bool _isTextType(FieldType type) {
    return type == FieldType.text ||
        type == FieldType.longText ||
        type == FieldType.url;
  }

  static bool _isNumberType(FieldType type) {
    return type == FieldType.counter ||
        type == FieldType.number ||
        type == FieldType.rating;
  }

  @override
  void initState() {
    super.initState();
    _values = Map<String, dynamic>.from(widget.item?.values ?? const {});

    for (final FieldDefinition field in widget.definition.fields) {
      if (widget.item == null) {
        if (widget.initialValues.containsKey(field.key)) {
          _values[field.key] = widget.initialValues[field.key];
        } else if (field.defaultValue != null) {
          _values[field.key] = field.defaultValue;
        }
      }

      final Object? value = _values[field.key];
      if (_isTextType(field.type)) {
        _controllers[field.key] = TextEditingController(
          text: value is String ? value : '',
        );
      } else if (_isNumberType(field.type)) {
        // 0 shows as blank, as on the old screens.
        _controllers[field.key] = TextEditingController(
          text: value is num && value != 0 ? '$value' : '',
        );
      } else if (field.type == FieldType.tags) {
        _controllers[field.key] = TextEditingController(
          text: value is List ? value.join(', ') : '',
        );
      } else if (field.type == FieldType.checklist) {
        _subItems[field.key] = [
          if (value is List)
            for (final Object? entry in value)
              if (entry is Map)
                _SubItemDraft(
                  id: '${entry['id']}',
                  done: entry['done'] == true,
                  title: '${entry['title'] ?? ''}',
                  original: Map<String, dynamic>.from(entry),
                ),
        ];
      } else if (field.type == FieldType.recurrence) {
        final Object? days = value is Map ? value['customDays'] : null;
        _customDays[field.key] = TextEditingController(
          text: days is int ? '$days' : '',
        );
      }
    }
  }

  @override
  void dispose() {
    for (final TextEditingController controller in [
      ..._controllers.values,
      ..._customDays.values,
      for (final List<_SubItemDraft> drafts in _subItems.values)
        for (final _SubItemDraft draft in drafts) draft.controller,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  bool get _requiredFieldsFilled {
    for (final FieldDefinition field in widget.definition.fields) {
      final TextEditingController? controller = _controllers[field.key];
      if (field.required &&
          _isTextType(field.type) &&
          controller != null &&
          controller.text.trim().isEmpty) {
        return false;
      }
    }
    return true;
  }

  Map<String, dynamic> _collectValues(DateTime now) {
    final Map<String, dynamic> values = Map<String, dynamic>.from(_values);

    for (final FieldDefinition field in widget.definition.fields) {
      final TextEditingController? controller = _controllers[field.key];
      final String text = controller?.text.trim() ?? '';

      if (_isTextType(field.type)) {
        values[field.key] = text;
      } else if (field.type == FieldType.number) {
        final num? parsed = num.tryParse(text);
        if (parsed == null) {
          values.remove(field.key);
        } else {
          values[field.key] = parsed;
        }
      } else if (_isNumberType(field.type)) {
        values[field.key] = int.tryParse(text) ?? 0;
      } else if (field.type == FieldType.tags) {
        values[field.key] = text
            .split(',')
            .map((tag) => tag.trim())
            .where((tag) => tag.isNotEmpty)
            .toSet()
            .toList();
      } else if (field.type == FieldType.checklist) {
        values[field.key] = [
          for (final _SubItemDraft draft in _subItems[field.key]!)
            if (draft.controller.text.trim().isNotEmpty)
              _subItemJson(draft, now),
        ];
      } else if (field.type == FieldType.recurrence) {
        final Object? current = values[field.key];
        final String frequency = current is Map
            ? '${current['frequency']}'
            : RecurrenceFrequency.none.wire;
        values[field.key] = {
          'frequency': frequency,
          if (frequency == RecurrenceFrequency.custom.wire)
            'customDays': int.tryParse(_customDays[field.key]!.text.trim()),
        };
      }
    }

    for (final FieldDefinition field in widget.definition.fields) {
      if (!field.isVisibleFor(values)) {
        values.remove(field.key);
      }
    }

    return values;
  }

  Map<String, dynamic> _subItemJson(_SubItemDraft draft, DateTime now) {
    final String title = draft.controller.text.trim();
    final Map<String, dynamic>? original = draft.original;
    final bool changed = original == null ||
        original['title'] != title ||
        original['done'] != draft.done;

    return {
      'id': draft.id,
      'title': title,
      'done': draft.done,
      'createdAt': original?['createdAt'] ?? now.toIso8601String(),
      'updatedAt': changed ? now.toIso8601String() : original['updatedAt'],
    };
  }

  void _save() {
    final DateTime now = DateTime.now().toUtc();
    final ListItem result = ListRules.normalize(
      widget.definition,
      ListItem(
        id: widget.item?.id ?? const Uuid().v4(),
        listId: widget.definition.id,
        values: _collectValues(now),
        createdAt: widget.item?.createdAt ?? now,
        updatedAt: now,
      ),
    );

    final List<String> errors = result.validateAgainst(widget.definition);
    if (errors.isNotEmpty) {
      setState(() {
        _error = errors.first;
      });
      return;
    }

    Navigator.of(context).pop(result);
  }

  Future<void> _pickDate(FieldDefinition field) async {
    final Object? raw = _values[field.key];
    final DateTime current = (raw is String ? DateTime.tryParse(raw) : null)
            ?.toLocal() ??
        DateTime.now();

    final DateTime? day = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (day == null || !mounted) {
      return;
    }

    TimeOfDay time = TimeOfDay.fromDateTime(current);
    if (field.type == FieldType.dateTime) {
      final TimeOfDay? picked = await showTimePicker(
        context: context,
        initialTime: time,
      );
      if (picked == null || !mounted) {
        return;
      }
      time = picked;
    }

    final DateTime local = field.type == FieldType.dateTime
        ? DateTime(day.year, day.month, day.day, time.hour, time.minute)
        : DateTime(day.year, day.month, day.day);

    setState(() {
      _values[field.key] = local.toUtc().toIso8601String();
    });
  }

  Future<void> _newCategory(FieldDefinition field, ListLabels labels) async {
    final TextEditingController controller = TextEditingController();
    final String? name = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(labels.loc.createCategory),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(labelText: labels.loc.categoryName),
            onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(labels.loc.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(controller.text),
              child: Text(labels.loc.create),
            ),
          ],
        );
      },
    );

    final String cleaned = name?.trim() ?? '';
    if (cleaned.isNotEmpty && mounted) {
      setState(() {
        _values[field.key] = cleaned;
      });
    }
  }

  Widget? _editor(ListLabels labels, FieldDefinition field) {
    final String label = labels.field(field) + (field.required ? ' *' : '');
    final TextEditingController? controller = _controllers[field.key];
    final Key key = ValueKey('field-${field.key}');

    switch (field.type) {
      case FieldType.text:
      case FieldType.longText:
      case FieldType.url:
        return TextField(
          key: key,
          controller: controller,
          maxLines: field.type == FieldType.longText ? 3 : 1,
          keyboardType:
              field.type == FieldType.url ? TextInputType.url : TextInputType.text,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(labelText: label),
        );
      case FieldType.counter:
      case FieldType.number:
      case FieldType.rating:
        return TextField(
          key: key,
          controller: controller,
          keyboardType: TextInputType.numberWithOptions(
            decimal: field.type == FieldType.number,
          ),
          decoration: InputDecoration(labelText: label),
        );
      case FieldType.tags:
        return TextField(
          key: key,
          controller: controller,
          decoration: InputDecoration(labelText: label, hintText: 'a, b, c'),
        );
      case FieldType.choice:
        final Object? current = _values[field.key];
        return DropdownButtonFormField<String>(
          key: key,
          initialValue: field.hasOption(current) ? current as String : null,
          isExpanded: true,
          decoration: InputDecoration(labelText: label),
          items: [
            for (final FieldOption option in field.options)
              DropdownMenuItem(
                value: option.value,
                child: Text(labels.option(option)),
              ),
          ],
          onChanged: (value) {
            setState(() {
              _values[field.key] = value;
            });
          },
        );
      case FieldType.category:
        final Object? current = _values[field.key];
        final List<String> choices = [
          for (final FieldOption option in field.options) option.value,
          if (current is String && current.isNotEmpty && !field.hasOption(current))
            current,
        ];
        return Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                // Rebuild when a new category is typed in.
                key: ValueKey('field-${field.key}-$current'),
                initialValue: current is String && current.isNotEmpty ? current : '',
                isExpanded: true,
                decoration: InputDecoration(labelText: label),
                items: [
                  const DropdownMenuItem(value: '', child: Text('—')),
                  for (final String choice in choices)
                    DropdownMenuItem(value: choice, child: Text(choice)),
                ],
                onChanged: (value) {
                  setState(() {
                    if (value == null || value.isEmpty) {
                      _values.remove(field.key);
                    } else {
                      _values[field.key] = value;
                    }
                  });
                },
              ),
            ),
            IconButton(
              tooltip: labels.loc.createCategory,
              icon: const Icon(Icons.add),
              onPressed: () => _newCategory(field, labels),
            ),
          ],
        );
      case FieldType.checkbox:
        return CheckboxListTile(
          key: key,
          contentPadding: EdgeInsets.zero,
          title: Text(label),
          value: _values[field.key] == true,
          onChanged: (value) {
            setState(() {
              _values[field.key] = value ?? false;
            });
          },
        );
      case FieldType.toggle:
        return SwitchListTile(
          key: key,
          contentPadding: EdgeInsets.zero,
          title: Text(label),
          value: _values[field.key] == true,
          onChanged: (value) {
            setState(() {
              _values[field.key] = value;
            });
          },
        );
      case FieldType.date:
      case FieldType.dateTime:
        final Object? raw = _values[field.key];
        final DateTime? date =
            raw is String ? DateTime.tryParse(raw)?.toLocal() : null;
        final String locale = Localizations.localeOf(context).toLanguageTag();
        final DateFormat format = field.type == FieldType.dateTime
            ? DateFormat.yMMMd(locale).add_jm()
            : DateFormat.yMMMd(locale);
        return InputDecorator(
          key: key,
          decoration: InputDecoration(labelText: label),
          child: Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  style: TextButton.styleFrom(alignment: Alignment.centerLeft),
                  icon: const Icon(Icons.event),
                  label: Text(date == null ? labels.loc.setReminder : format.format(date)),
                  onPressed: () => _pickDate(field),
                ),
              ),
              if (date != null)
                IconButton(
                  tooltip: labels.loc.clear,
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      _values.remove(field.key);
                    });
                  },
                ),
            ],
          ),
        );
      case FieldType.recurrence:
        final Object? current = _values[field.key];
        final RecurrenceFrequency frequency = enumFromWire(
              RecurrenceFrequency.values,
              current is Map ? current['frequency'] : null,
            ) ??
            RecurrenceFrequency.none;
        return Column(
          key: key,
          children: [
            DropdownButtonFormField<RecurrenceFrequency>(
              initialValue: frequency,
              isExpanded: true,
              decoration: InputDecoration(labelText: label),
              items: [
                for (final RecurrenceFrequency value in RecurrenceFrequency.values)
                  DropdownMenuItem(
                    value: value,
                    child: Text(labels.recurrence(value)),
                  ),
              ],
              onChanged: (value) {
                setState(() {
                  _values[field.key] = {
                    'frequency': (value ?? RecurrenceFrequency.none).wire,
                  };
                });
              },
            ),
            if (frequency == RecurrenceFrequency.custom) ...[
              const SizedBox(height: 12),
              TextField(
                key: ValueKey('field-${field.key}-days'),
                controller: _customDays[field.key],
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: labels.loc.repeatEveryHowManyDays,
                ),
              ),
            ],
          ],
        );
      case FieldType.checklist:
        final List<_SubItemDraft> drafts = _subItems[field.key]!;
        return Column(
          key: key,
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: double.infinity,
              child: Text(label, style: Theme.of(context).textTheme.labelLarge),
            ),
            for (final _SubItemDraft draft in drafts)
              Row(
                key: ValueKey('sub-${draft.id}'),
                children: [
                  Checkbox(
                    value: draft.done,
                    onChanged: (value) {
                      setState(() {
                        draft.done = value ?? false;
                      });
                    },
                  ),
                  Expanded(
                    child: TextField(controller: draft.controller),
                  ),
                  IconButton(
                    tooltip: labels.loc.delete,
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () {
                      setState(() {
                        drafts.remove(draft);
                      });
                    },
                  ),
                ],
              ),
            TextButton.icon(
              key: ValueKey('field-${field.key}-add'),
              icon: const Icon(Icons.add),
              label: Text(labels.loc.addSubtask),
              onPressed: () {
                setState(() {
                  drafts.add(
                    _SubItemDraft(id: const Uuid().v4(), done: false, title: ''),
                  );
                });
              },
            ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations loc = AppLocalizations.of(context);
    final ListLabels labels = ListLabels(loc);
    final List<Widget> editors = [];

    for (final FieldDefinition field in widget.definition.fields) {
      if (!field.isVisibleFor(_values)) {
        continue;
      }

      final Widget? editor = _editor(labels, field);
      if (editor != null) {
        if (editors.isNotEmpty) {
          editors.add(const SizedBox(height: 12));
        }
        editors.add(editor);
      }
    }

    if (_error != null) {
      editors.add(
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      );
    }

    return AlertDialog(
      title: Text(
        widget.title,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: editors,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text(loc.cancel),
        ),
        FilledButton(
          onPressed: _requiredFieldsFilled ? _save : null,
          child: Text(loc.save),
        ),
      ],
    );
  }
}
