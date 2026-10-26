import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../app_cubit.dart';
import '../app_state.dart';
import '../l10n/generated/app_localizations.dart';
import 'app_cubit_list_store.dart';
import 'builtin_templates.dart';
import 'generic_list_screen.dart';
import 'legacy_lists.dart';
import 'list_definition.dart';
import 'list_labels.dart';

// One built-in list on the generic screen, fed from today's AppCubit state.
class GenericListHost extends StatelessWidget {
  const GenericListHost({super.key, required this.listId});

  final String listId;

  static GenericListTexts textsFor(
    String listId,
    AppLocalizations loc,
    ListDefinition definition,
  ) {
    switch (listId) {
      case BuiltinTemplates.tasksId:
        return GenericListTexts(
          title: loc.tasks,
          emptyText: loc.noTasksHereYet,
          addTooltip: loc.addTaskTooltip,
          addDialogTitle: loc.addTask,
          editDialogTitle: loc.editTask,
        );
      case BuiltinTemplates.groceryId:
        return GenericListTexts(
          title: loc.groceryList,
          emptyText: loc.noGroceriesCurrent,
          addTooltip: loc.addGroceryItemTooltip,
          addDialogTitle: loc.addGroceryItem,
          editDialogTitle: loc.editGroceryItem,
        );
      case BuiltinTemplates.journalId:
        return GenericListTexts(
          title: loc.journal,
          emptyText: loc.noJournalEntriesYet,
          addTooltip: loc.addJournalEntryTooltip,
          addDialogTitle: loc.addJournalEntry,
          editDialogTitle: loc.editJournalEntry,
        );
      case BuiltinTemplates.watchReadId:
        return GenericListTexts(
          title: loc.watchReadList,
          emptyText: loc.noWatchReadItemsYet,
          addTooltip: loc.addWatchReadItemTooltip,
          addDialogTitle: loc.addWatchReadItem,
          editDialogTitle: loc.editWatchReadItem,
        );
    }

    final String name = ListLabels(loc).listName(definition);
    return GenericListTexts(
      title: name,
      emptyText: '—',
      addTooltip: loc.add,
      addDialogTitle: loc.add,
      editDialogTitle: loc.edit,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations loc = AppLocalizations.of(context);
    final AppCubitListStore store = AppCubitListStore(context.read<AppCubit>());

    return BlocBuilder<AppCubit, AppState>(
      builder: (context, state) {
        final LegacyImport lists = LegacyLists.importAppData(state.data);
        final ListDefinition definition =
            lists.definitions.firstWhere((definition) => definition.id == listId);

        return GenericListScreen(
          definition: definition,
          items: lists.items.where((item) => item.listId == listId).toList(),
          store: store,
          texts: textsFor(listId, loc, definition),
        );
      },
    );
  }
}
