import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'list_catalog.dart';
import 'list_store.dart';

// Rebuilds with every snapshot of the ListStore above it.
class ListCatalogBuilder extends StatefulWidget {
  const ListCatalogBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, ListCatalog catalog) builder;

  @override
  State<ListCatalogBuilder> createState() => _ListCatalogBuilderState();
}

class _ListCatalogBuilderState extends State<ListCatalogBuilder> {
  late final ListStore _store = context.read<ListStore>();
  // One subscription for the widget's lifetime, not one per rebuild.
  late final Stream<ListCatalog> _catalogs = _store.watch();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ListCatalog>(
      stream: _catalogs,
      initialData: _store.current,
      builder: (context, snapshot) {
        return widget.builder(context, snapshot.data ?? _store.current);
      },
    );
  }
}
