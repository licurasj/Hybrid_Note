import 'list_definition.dart';
import 'list_item.dart';

// Every list the app shows, in launcher order, with all their items: the
// snapshot a ListStore reads out.
class ListCatalog {
  const ListCatalog({required this.definitions, required this.items});

  final List<ListDefinition> definitions;
  final List<ListItem> items;

  ListDefinition? definition(String listId) {
    return definitions
        .where((definition) => definition.id == listId)
        .firstOrNull;
  }

  List<ListItem> itemsOf(String listId) {
    return items.where((item) => item.listId == listId).toList();
  }
}
