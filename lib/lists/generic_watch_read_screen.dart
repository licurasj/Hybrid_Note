import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../app_cubit.dart';
import '../app_state.dart';
import '../l10n/generated/app_localizations.dart';
import '../watch_item.dart';
import 'builtin_templates.dart';
import 'generic_list_screen.dart';
import 'legacy_lists.dart';
import 'list_definition.dart';
import 'list_item.dart';

// Whether the bottom bar shows the generic Watch/Read screen instead of the
// old one. Off by default; turn on with --dart-define=GENERIC_LISTS=true.
const bool useGenericLists = bool.fromEnvironment('GENERIC_LISTS');

// Watch/Read on the generic screen, reading and writing through today's
// AppCubit so storage, validation, tombstones and Drive sync are unchanged.
class GenericWatchReadScreen extends StatelessWidget {
  const GenericWatchReadScreen({super.key});

  static final ListDefinition definition = BuiltinTemplates.watchRead();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations loc = AppLocalizations.of(context);
    final AppCubit cubit = context.read<AppCubit>();

    return BlocBuilder<AppCubit, AppState>(
      builder: (context, state) {
        return GenericListScreen(
          definition: definition,
          title: loc.watchReadList,
          items: state.data.watchItems.map(LegacyLists.watchToItem).toList(),
          emptyText: loc.noWatchReadItemsYet,
          addTooltip: loc.addWatchReadItemTooltip,
          addDialogTitle: loc.addWatchReadItem,
          editDialogTitle: loc.editWatchReadItem,
          onSave: (ListItem item, {required bool isNew}) {
            final WatchItem watch = LegacyLists.itemToWatch(item);

            if (isNew) {
              return cubit.addWatchItem(
                title: watch.title,
                type: watch.type,
                status: watch.status,
                season: watch.season,
                episode: watch.episode,
                notes: watch.notes,
              );
            }

            return cubit.editWatchItem(
              itemId: item.id,
              title: watch.title,
              type: watch.type,
              status: watch.status,
              season: watch.season,
              episode: watch.episode,
              notes: watch.notes,
            );
          },
          onDelete: (item) => cubit.deleteWatchItem(item.id),
          onRefresh: cubit.syncWithDrive,
        );
      },
    );
  }
}
