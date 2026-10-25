import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:hybrid_note/lists/builtin_templates.dart';
import 'package:hybrid_note/lists/list_definition.dart';
import 'package:hybrid_note/lists/list_vocabulary.dart';

// schema/list_definition.schema.json is what the AI backend will validate
// against. These tests keep it in step with the Dart vocabulary and check
// that the built-in templates satisfy it.

// Checks the subset of JSON Schema the file uses: type, const, enum,
// required, properties, additionalProperties: false, items, minItems,
// minLength, pattern and local $ref. Returns one message per violation.
class _MiniSchemaValidator {
  _MiniSchemaValidator(this.root);

  final Map<String, dynamic> root;

  List<String> validate(Object? value) {
    final List<String> errors = [];
    _check(root, value, r'$', errors);
    return errors;
  }

  void _check(
    Map<String, dynamic> schema,
    Object? value,
    String path,
    List<String> errors,
  ) {
    final Object? ref = schema[r'$ref'];
    if (ref is String) {
      final String name = ref.substring(r'#/$defs/'.length);
      _check(root[r'$defs'][name] as Map<String, dynamic>, value, path, errors);
      return;
    }

    final Object? type = schema['type'];
    if (type != null) {
      final List<dynamic> types = type is List ? type : [type];
      if (!types.any((type) => _isType(value, type as String))) {
        errors.add('$path: expected $type, got ${value.runtimeType}');
        return;
      }
    }

    if (schema.containsKey('const') && value != schema['const']) {
      errors.add('$path: must be ${schema['const']}');
    }

    final Object? allowed = schema['enum'];
    if (allowed is List && !allowed.contains(value)) {
      errors.add('$path: "$value" not in enum');
    }

    if (value is String) {
      final Object? minLength = schema['minLength'];
      if (minLength is int && value.length < minLength) {
        errors.add('$path: shorter than $minLength');
      }
      final Object? pattern = schema['pattern'];
      if (pattern is String && !RegExp(pattern).hasMatch(value)) {
        errors.add('$path: does not match $pattern');
      }
    }

    if (value is List) {
      final Object? minItems = schema['minItems'];
      if (minItems is int && value.length < minItems) {
        errors.add('$path: fewer than $minItems items');
      }
      final Object? items = schema['items'];
      if (items is Map<String, dynamic>) {
        for (int i = 0; i < value.length; i++) {
          _check(items, value[i], '$path[$i]', errors);
        }
      }
    }

    if (value is Map) {
      final Map<String, dynamic> properties =
          (schema['properties'] as Map<String, dynamic>?) ?? const {};
      for (final Object? key in (schema['required'] as List?) ?? const []) {
        if (!value.containsKey(key)) {
          errors.add('$path: missing "$key"');
        }
      }
      for (final MapEntry<dynamic, dynamic> entry in value.entries) {
        final Object? propertySchema = properties[entry.key];
        if (propertySchema is Map<String, dynamic>) {
          _check(propertySchema, entry.value, '$path.${entry.key}', errors);
        } else if (schema['additionalProperties'] == false) {
          errors.add('$path: unexpected "${entry.key}"');
        }
      }
    }
  }

  bool _isType(Object? value, String type) {
    switch (type) {
      case 'object':
        return value is Map;
      case 'array':
        return value is List;
      case 'string':
        return value is String;
      case 'integer':
        return value is int;
      case 'number':
        return value is num;
      case 'boolean':
        return value is bool;
      case 'null':
        return value == null;
    }
    throw ArgumentError('unsupported schema type $type');
  }
}

void main() {
  final Map<String, dynamic> schema = jsonDecode(
    File('schema/list_definition.schema.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final Map<String, dynamic> defs = schema[r'$defs'] as Map<String, dynamic>;
  final _MiniSchemaValidator validator = _MiniSchemaValidator(schema);

  List<dynamic> schemaEnum(String name) {
    return (defs[name] as Map<String, dynamic>)['enum'] as List<dynamic>;
  }

  final Map<String, List<WireName>> vocabularies = {
    'fieldType': FieldType.values,
    'fieldRole': FieldRole.values,
    'viewKind': ViewKind.values,
    'timelineGrouping': TimelineGrouping.values,
    'behaviorKind': BehaviorKind.values,
    'recurrenceFrequency': RecurrenceFrequency.values,
  };

  vocabularies.forEach((name, values) {
    test('schema $name matches the Dart vocabulary', () {
      expect(schemaEnum(name), values.map((value) => value.wire).toList());
    });
  });

  test('schema formatVersion matches the Dart format version', () {
    final Map<String, dynamic> properties =
        schema['properties'] as Map<String, dynamic>;
    expect(
      (properties['formatVersion'] as Map<String, dynamic>)['const'],
      ListDefinition.currentFormatVersion,
    );
  });

  for (final ListDefinition definition in BuiltinTemplates.all(
    taskCategories: ['Work'],
  )) {
    test('${definition.id} satisfies the schema', () {
      final Object? json = jsonDecode(jsonEncode(definition.toJson()));
      expect(validator.validate(json), isEmpty);
    });
  }

  test('the schema rejects a field type outside the vocabulary', () {
    final Map<String, dynamic> json =
        jsonDecode(jsonEncode(BuiltinTemplates.journal().toJson()))
            as Map<String, dynamic>;
    ((json['fields'] as List<dynamic>)[1] as Map<String, dynamic>)['type'] =
        'colourPicker';

    expect(validator.validate(json), contains(contains('not in enum')));
  });

  test('the schema rejects unknown keys', () {
    final Map<String, dynamic> json =
        jsonDecode(jsonEncode(BuiltinTemplates.journal().toJson()))
            as Map<String, dynamic>;
    json['script'] = 'alert(1)';

    expect(validator.validate(json), contains(contains('unexpected "script"')));
  });
}
