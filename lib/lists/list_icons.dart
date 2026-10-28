import 'package:flutter/material.dart';

// Icon names a list definition may use. Flutter cannot look icons up by
// name at runtime, so the supported names are listed; others fall back.
const Map<String, IconData> listIcons = {
  'pending_actions': Icons.pending_actions,
  'checklist': Icons.checklist,
  'shopping_cart': Icons.shopping_cart,
  'book': Icons.book,
  'movie': Icons.movie,
  'local_florist': Icons.local_florist,
  'list': Icons.list_alt,
};

IconData listIcon(String name) => listIcons[name] ?? Icons.list_alt;

// Colours offered in the list editor (plain until the design pass, D-3).
const List<String> listColorChoices = [
  '#1E88E5',
  '#43A047',
  '#8E24AA',
  '#FB8C00',
  '#E53935',
  '#00897B',
  '#6D4C41',
  '#546E7A',
];

// #RRGGBB to a Color; grey when the value is not a colour.
Color listColor(String hex) {
  final int? value = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
  return value == null || hex.length != 7 ? Colors.blueGrey : Color(0xFF000000 | value);
}
