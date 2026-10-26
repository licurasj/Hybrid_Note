import 'package:flutter_test/flutter_test.dart';

import 'package:hybrid_note/lists/list_definition.dart';
import 'package:hybrid_note/lists/list_item.dart';
import 'package:hybrid_note/lists/list_patch.dart';

final DateTime _t0 = DateTime.utc(2026, 3, 1);
final DateTime _t1 = DateTime.utc(2026, 3, 2);

ListDefinition _books() {
  return ListDefinition.fromJson({
    'id': 'books',
    'name': 'Books',
    'icon': 'book',
    'color': '#123456',
    'fields': [
      {'key': 'title', 'type': 'text', 'label': 'Title', 'required': true, 'primary': true},
      {'key': 'price', 'type': 'text', 'label': 'Price'},
      {'key': 'shop', 'type': 'text', 'label': 'Shop'},
    ],
    'view': {'kind': 'cards'},
    'updatedAt': _t0.toIso8601String(),
  });
}

ListItem _item(String id, Map<String, dynamic> values) {
  return ListItem(id: id, listId: 'books', values: {'title': id, ...values}, createdAt: _t0, updatedAt: _t0);
}

void main() {
  final List<ListItem> items = [
    _item('a', {'price': '4', 'shop': 'Corner'}),
    _item('b', {'price': r'$3', 'shop': 'corner'}),
    _item('c', {'price': 'about 5', 'shop': 'Market'}),
    _item('d', {'price': ''}),
  ];

  test('changing text to number converts what it can and hides the rest', () {
    final ListPatchResult result = ListPatch.apply(_books(), items, const [
      ListPatchOp(PatchOpKind.changeFieldType, {'key': 'price', 'type': 'number'}),
    ], _t1);

    expect(result.isValid, isTrue);
    expect(result.items[0]['price'], 4);
    expect(result.items[1]['price'], isNull);
    expect(result.items[1]['_legacy'], {'price': r'$3'});
    expect(result.items[2]['_legacy'], {'price': 'about 5'});
    expect(result.items[3].values.containsKey('price'), isFalse);
    expect(result.hiddenValues, 2);
    expect(result.changedItemIds, {'a', 'b', 'c', 'd'});
    expect(result.items[0].updatedAt, _t1);
    expect(result.definition.schemaRevision, 2);
    for (final ListItem item in result.items) {
      expect(item.validateAgainst(result.definition), isEmpty);
    }
  });

  test('changing text to a choice offers the values already used', () {
    final ListPatchResult result = ListPatch.apply(_books(), items, const [
      ListPatchOp(PatchOpKind.changeFieldType, {'key': 'shop', 'type': 'enum'}),
    ], _t1);

    expect(result.definition.field('shop')!.options.map((o) => o.value), ['Corner', 'Market']);
    // "corner" matches "Corner" regardless of case.
    expect(result.items[1]['shop'], 'Corner');
    expect(result.hiddenValues, 0);
  });

  test('removing a field keeps its values on the items', () {
    final ListPatchResult result = ListPatch.apply(_books(), items, const [
      ListPatchOp(PatchOpKind.removeField, {'key': 'shop'}),
    ], _t1);

    expect(result.definition.field('shop'), isNull);
    expect(result.items[0]['shop'], 'Corner');
    expect(result.items[0].validateAgainst(result.definition), isEmpty);
  });

  test('add, rename, move and set view build a valid definition', () {
    final ListPatchResult result = ListPatch.apply(_books(), items, const [
      ListPatchOp(PatchOpKind.setListInfo, {'name': 'Reading', 'color': '#654321'}),
      ListPatchOp(PatchOpKind.addField, {
        'field': {
          'key': 'status',
          'type': 'enum',
          'label': 'Status',
          'options': [
            {'value': 'toRead', 'label': 'To read'},
            {'value': 'done', 'label': 'Done'},
          ],
        },
      }),
      ListPatchOp(PatchOpKind.renameField, {'key': 'price', 'label': 'Cost'}),
      ListPatchOp(PatchOpKind.moveField, {'key': 'status', 'index': 1}),
      ListPatchOp(PatchOpKind.setView, {'view': {'kind': 'grouped', 'groupBy': 'status'}}),
    ], _t1);

    expect(result.errors, isEmpty);
    expect(result.definition.name, 'Reading');
    expect(result.definition.fields.map((f) => f.key), ['title', 'status', 'price', 'shop']);
    expect(result.definition.field('price')!.label, 'Cost');
    expect(result.definition.view.groupBy, 'status');
  });

  test('narrowing a choice hides values that no longer exist', () {
    final ListPatchResult withChoice = ListPatch.apply(_books(), items, const [
      ListPatchOp(PatchOpKind.changeFieldType, {'key': 'shop', 'type': 'enum'}),
    ], _t1);
    final ListPatchResult narrowed = ListPatch.apply(withChoice.definition, withChoice.items, const [
      ListPatchOp(PatchOpKind.setOptions, {
        'key': 'shop',
        'options': [
          {'value': 'Corner', 'label': 'Corner'},
        ],
      }),
    ], _t1);

    expect(narrowed.items[2]['_legacy'], {'shop': 'Market'});
    expect(narrowed.hiddenValues, 1);
  });

  test('invalid results are reported, not applied silently', () {
    final ListPatchResult result = ListPatch.apply(_books(), items, const [
      ListPatchOp(PatchOpKind.removeField, {'key': 'nope'}),
      ListPatchOp(PatchOpKind.setView, {'view': {'kind': 'grouped', 'groupBy': 'price'}}),
    ], _t1);

    expect(result.isValid, isFalse);
    expect(result.errors, contains('removeField: no field "nope"'));
    expect(result.errors, contains(contains('groupBy "price" must be')));
  });

  test('ops round-trip through JSON, as the AI will send them', () {
    const ListPatchOp op = ListPatchOp(PatchOpKind.changeFieldType, {'key': 'price', 'type': 'number'});
    expect(ListPatchOp.fromJson(op.toJson()).toJson(), op.toJson());
    expect(() => ListPatchOp.fromJson({'op': 'dropTable'}), throwsFormatException);
  });
}
