import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../app_colors.dart';
import '../l10n/generated/app_localizations.dart';
import 'list_definition.dart';
import 'list_item.dart';
import 'list_labels.dart';
import 'list_vocabulary.dart';

// Shows any list from its definition: items grouped or in one column, a tile
// per item, and an add/edit dialog built from the fields. Where the items come
// from and how changes are saved is up to the caller, so the same screen can
// sit on today's AppCubit or on the future Firestore storage.
//
// Supported so far: grouped view (other views fall back to one column) and
// editors for text, longText, url, enum, counter, number, rating, checkbox and
// toggle. Fields of other types are not shown; their values are kept.
class GenericListScreen extends StatelessWidget {
  const GenericListScreen({
    super.key,
    required this.definition,
    required this.items,
    required this.emptyText,
    required this.addTooltip,
    required this.addDialogTitle,
    required this.editDialogTitle,
    required this.onSave,
    required this.onDelete,
    required this.onRefresh,
    this.title,
  });

  final ListDefinition definition;
  final List<ListItem> items;
  // App bar title; defaults to the list's name.
  final String? title;
  final String emptyText;
  final String addTooltip;
  final String addDialogTitle;
  final String editDialogTitle;
  final Future<void> Function(ListItem item, {required bool isNew}) onSave;
  final Future<void> Function(ListItem item) onDelete;
  final Future<void> Function() onRefresh;

  static const Set<FieldType> editableTypes = {
    FieldType.text,
    FieldType.longText,
    FieldType.url,
    FieldType.choice,
    FieldType.counter,
    FieldType.number,
    FieldType.rating,
    FieldType.checkbox,
    FieldType.toggle,
  };

  FieldDefinition get _primaryField {
    return definition.fields.firstWhere((field) => field.primary);
  }

  Future<void> _showItemDialog(BuildContext context, {ListItem? item}) async {
    final ListItem? result = await showDialog<ListItem>(
      context: context,
      builder: (_) {
        return GenericItemDialog(
          definition: definition,
          item: item,
          title: item == null ? addDialogTitle : editDialogTitle,
        );
      },
    );

    if (result != null) {
      await onSave(result, isNew: item == null);
    }
  }

  String _summary(ListLabels labels, ListItem item) {
    final List<String> parts = [];

    for (final FieldDefinition field in definition.fields) {
      if (field.primary || !field.isVisibleFor(item.values)) {
        continue;
      }

      final Object? value = item[field.key];
      switch (field.type) {
        case FieldType.choice:
          for (final FieldOption option in field.options) {
            if (option.value == value) {
              parts.add(labels.option(option));
            }
          }
        case FieldType.counter:
        case FieldType.number:
        case FieldType.rating:
          if (value is num && value != 0) {
            parts.add('${labels.field(field)} $value');
          }
        case FieldType.checkbox:
        case FieldType.toggle:
          if (value == true) {
            parts.add(labels.field(field));
          }
        case FieldType.text:
        case FieldType.longText:
        case FieldType.url:
        case FieldType.category:
          if (value is String && value.trim().isNotEmpty) {
            parts.add(value.trim());
          }
        case FieldType.date:
        case FieldType.dateTime:
        case FieldType.tags:
        case FieldType.checklist:
        case FieldType.recurrence:
          break;
      }
    }

    return parts.join(' | ');
  }

  // Groups in option order for an enum, first-seen order otherwise. Items
  // whose value matches no group go last, so nothing is ever hidden.
  List<MapEntry<String?, List<ListItem>>> _groups(
    ListLabels labels,
    List<ListItem> sorted,
  ) {
    final String? groupBy =
        definition.view.kind == ViewKind.grouped ? definition.view.groupBy : null;
    final FieldDefinition? groupField =
        groupBy == null ? null : definition.field(groupBy);

    if (groupField == null) {
      return [MapEntry(null, sorted)];
    }

    final List<MapEntry<String?, List<ListItem>>> groups = [];
    final Set<String> placed = {};

    void addGroup(String header, bool Function(ListItem item) matches) {
      final List<ListItem> members =
          sorted.where((item) => !placed.contains(item.id) && matches(item)).toList();
      if (members.isNotEmpty) {
        placed.addAll(members.map((item) => item.id));
        groups.add(MapEntry(header, members));
      }
    }

    for (final FieldOption option in groupField.options) {
      addGroup(labels.option(option), (item) => item[groupField.key] == option.value);
    }

    for (final ListItem item in sorted) {
      final Object? value = item[groupField.key];
      if (!placed.contains(item.id) && value is String && value.isNotEmpty) {
        addGroup(value, (other) => other[groupField.key] == value);
      }
    }

    addGroup('—', (item) => true);
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations loc = AppLocalizations.of(context);
    final ListLabels labels = ListLabels(loc);
    final List<ListItem> sorted = [...items]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final List<MapEntry<String?, List<ListItem>>> groups =
        _groups(labels, sorted);

    final List<Widget> children = [];
    for (final MapEntry<String?, List<ListItem>> group in groups) {
      if (group.key != null) {
        children.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
            child: Text(
              '${group.key} (${group.value.length})',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        );
      }

      for (final ListItem item in group.value) {
        children.add(_itemCard(context, loc, labels, item));
      }
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(title ?? labels.listName(definition)),
      ),
      floatingActionButton: FloatingActionButton(
        shape: const CircleBorder(),
        backgroundColor: AppColors.logoBlue,
        foregroundColor: Colors.white,
        onPressed: () {
          _showItemDialog(context);
        },
        tooltip: addTooltip,
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: onRefresh,
        child: items.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(12),
                children: [
                  const SizedBox(height: 260),
                  Center(
                    child: Text(emptyText),
                  ),
                ],
              )
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(12),
                children: children,
              ),
      ),
    );
  }

  Widget _itemCard(
    BuildContext context,
    AppLocalizations loc,
    ListLabels labels,
    ListItem item,
  ) {
    final String summary = _summary(labels, item);
    final Object? primary = item[_primaryField.key];

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
      ),
      child: ListTile(
        title: Text(
          primary is String ? primary : '',
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
        ),
        subtitle: summary.isEmpty
            ? null
            : Text(
                summary,
                overflow: TextOverflow.ellipsis,
                maxLines: 3,
              ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') {
              _showItemDialog(context, item: item);
            }

            if (value == 'delete') {
              onDelete(item);
            }
          },
          itemBuilder: (context) {
            return [
              PopupMenuItem(
                value: 'edit',
                child: ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: Text(loc.edit),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: Text(loc.delete),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ];
          },
        ),
      ),
    );
  }
}

// Add/edit dialog generated from the definition's fields. Pops the edited
// item, or nothing when cancelled.
class GenericItemDialog extends StatefulWidget {
  const GenericItemDialog({
    super.key,
    required this.definition,
    required this.title,
    this.item,
  });

  final ListDefinition definition;
  final String title;
  final ListItem? item;

  @override
  State<GenericItemDialog> createState() {
    return _GenericItemDialogState();
  }
}

class _GenericItemDialogState extends State<GenericItemDialog> {
  late final Map<String, dynamic> _values;
  final Map<String, TextEditingController> _controllers = {};
  String? _error;

  bool _isTextType(FieldType type) {
    return type == FieldType.text ||
        type == FieldType.longText ||
        type == FieldType.url;
  }

  bool _isNumberType(FieldType type) {
    return type == FieldType.counter ||
        type == FieldType.number ||
        type == FieldType.rating;
  }

  @override
  void initState() {
    super.initState();
    _values = Map<String, dynamic>.from(widget.item?.values ?? const {});

    for (final FieldDefinition field in widget.definition.fields) {
      if (widget.item == null && field.defaultValue != null) {
        _values[field.key] = field.defaultValue;
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
      }
    }
  }

  @override
  void dispose() {
    for (final TextEditingController controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  bool get _requiredFieldsFilled {
    for (final FieldDefinition field in widget.definition.fields) {
      final TextEditingController? controller = _controllers[field.key];
      if (field.required &&
          controller != null &&
          controller.text.trim().isEmpty) {
        return false;
      }
    }
    return true;
  }

  void _save() {
    final Map<String, dynamic> values = Map<String, dynamic>.from(_values);

    for (final FieldDefinition field in widget.definition.fields) {
      final TextEditingController? controller = _controllers[field.key];
      if (controller == null) {
        continue;
      }

      final String text = controller.text.trim();
      if (_isTextType(field.type)) {
        values[field.key] = text;
      } else if (field.type == FieldType.number) {
        final num? parsed = num.tryParse(text);
        if (parsed == null) {
          values.remove(field.key);
        } else {
          values[field.key] = parsed;
        }
      } else {
        values[field.key] = int.tryParse(text) ?? 0;
      }
    }

    for (final FieldDefinition field in widget.definition.fields) {
      if (!field.isVisibleFor(values)) {
        values.remove(field.key);
      }
    }

    final DateTime now = DateTime.now().toUtc();
    final ListItem result = ListItem(
      id: widget.item?.id ?? const Uuid().v4(),
      listId: widget.definition.id,
      values: values,
      createdAt: widget.item?.createdAt ?? now,
      updatedAt: now,
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

  Widget? _editor(ListLabels labels, FieldDefinition field) {
    final String label = labels.field(field) + (field.required ? ' *' : '');
    final TextEditingController? controller = _controllers[field.key];

    switch (field.type) {
      case FieldType.text:
      case FieldType.longText:
      case FieldType.url:
        return TextField(
          key: ValueKey('field-${field.key}'),
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
          key: ValueKey('field-${field.key}'),
          controller: controller,
          keyboardType: TextInputType.numberWithOptions(
            decimal: field.type == FieldType.number,
          ),
          decoration: InputDecoration(labelText: label),
        );
      case FieldType.choice:
        final Object? current = _values[field.key];
        return DropdownButtonFormField<String>(
          key: ValueKey('field-${field.key}'),
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
      case FieldType.checkbox:
        return CheckboxListTile(
          key: ValueKey('field-${field.key}'),
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
          key: ValueKey('field-${field.key}'),
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
      case FieldType.category:
      case FieldType.tags:
      case FieldType.checklist:
      case FieldType.recurrence:
        return null;
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
