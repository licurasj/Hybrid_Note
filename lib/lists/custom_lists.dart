import 'dart:convert';
import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';

import 'builtin_templates.dart';
import 'list_definition.dart';
import 'list_item.dart';
import 'list_patch.dart';
import 'list_rules.dart';
import 'list_store.dart';

export 'list_store.dart' show DeletedList;

// Lists the user creates, plus name/icon/colour changes to the built-in ones.
// Screens reach it only through LocalListStore.
// Kept in a local file of their own: the Drive sync only knows the four
// built-in lists and would drop anything else. Until the move to Firestore
// these lists therefore stay on this device.
class CustomListsData {
  const CustomListsData({
    this.definitions = const [],
    this.items = const [],
    this.builtinInfo = const {},
  });

  final List<ListDefinition> definitions;
  final List<ListItem> items;
  // setListInfo arguments per built-in list id.
  final Map<String, Map<String, dynamic>> builtinInfo;

  CustomListsData copyWith({
    List<ListDefinition>? definitions,
    List<ListItem>? items,
    Map<String, Map<String, dynamic>>? builtinInfo,
  }) {
    return CustomListsData(
      definitions: definitions ?? this.definitions,
      items: items ?? this.items,
      builtinInfo: builtinInfo ?? this.builtinInfo,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'formatVersion': 1,
      'definitions': definitions
          .map((definition) => definition.toJson())
          .toList(),
      'items': items.map((item) => item.toJson()).toList(),
      'builtinInfo': builtinInfo,
    };
  }

  factory CustomListsData.fromJson(Map<String, dynamic> json) {
    return CustomListsData(
      definitions: (json['definitions'] as List? ?? const [])
          .map(ListDefinition.fromJson)
          .toList(),
      items: (json['items'] as List? ?? const [])
          .map(ListItem.fromJson)
          .toList(),
      builtinInfo: {
        for (final MapEntry<String, dynamic> entry
            in (json['builtinInfo'] as Map? ?? const {})
                .cast<String, dynamic>()
                .entries)
          entry.key: Map<String, dynamic>.from(entry.value as Map),
      },
    );
  }
}

class CustomListsStorage {
  CustomListsStorage({Future<Directory> Function()? getDirectory})
    : _getDirectory = getDirectory ?? getApplicationDocumentsDirectory;

  static const String _fileName = 'hybrid_note_custom_lists.json';

  final Future<Directory> Function() _getDirectory;

  Future<File> _file() async {
    final Directory directory = await _getDirectory();
    return File('${directory.path}/$_fileName');
  }

  Future<CustomListsData> load() async {
    final File file = await _file();
    if (!await file.exists()) {
      return const CustomListsData();
    }

    try {
      return CustomListsData.fromJson(
        jsonDecode(await file.readAsString()) as Map<String, dynamic>,
      );
    } catch (_) {
      // Same rule as AppStorage: never overwrite what could not be read.
      final String stamp = DateTime.now().toUtc().toIso8601String().replaceAll(
        ':',
        '-',
      );
      await file.rename('${file.path}.unreadable-$stamp');
      return const CustomListsData();
    }
  }

  // Saves run one at a time, in call order, for the same reason as in
  // AppStorage: one shared temporary file, and callers emit before awaiting.
  Future<void> _saveQueue = Future<void>.value();

  Future<void> save(CustomListsData data) {
    final Future<void> save = _saveQueue.then((_) => _write(data));
    // A failed save must not block the ones after it.
    _saveQueue = save.catchError((Object _) {});
    return save;
  }

  Future<void> _write(CustomListsData data) async {
    final File file = await _file();
    final File temp = File('${file.path}.tmp');
    await temp.writeAsString(jsonEncode(data.toJson()), flush: true);
    await temp.rename(file.path);
  }
}

class CustomListsCubit extends Cubit<CustomListsData> {
  CustomListsCubit(this.storage) : super(const CustomListsData());

  final CustomListsStorage storage;

  Future<void> load() async {
    emit(await storage.load());
  }

  Future<void> _save(CustomListsData data) async {
    emit(data);
    await storage.save(data);
  }

  bool isCustom(String listId) {
    return state.definitions.any((definition) => definition.id == listId);
  }

  Future<void> createList(
    ListDefinition definition, {
    List<ListItem> items = const [],
  }) {
    return _save(
      state.copyWith(
        definitions: [...state.definitions, definition],
        items: [...state.items, ...items],
      ),
    );
  }

  // Applies a patch that was already checked with ListPatch.apply.
  Future<void> savePatched(
    ListPatchResult result,
    List<ListPatchOp> ops,
  ) async {
    final String listId = result.definition.id;

    if (BuiltinTemplates.isBuiltin(listId)) {
      // Built-in lists live in the synced AppData; only their name, icon,
      // colour and AI switch can change before the move to Firestore.
      final Map<String, dynamic> info = {...?state.builtinInfo[listId]};
      for (final ListPatchOp op in ops) {
        if (op.kind == PatchOpKind.setListInfo) {
          info.addAll(op.args);
        }
      }
      await _save(
        state.copyWith(builtinInfo: {...state.builtinInfo, listId: info}),
      );
      return;
    }

    final Map<String, ListItem> changed = {
      for (final ListItem item in result.items)
        if (result.changedItemIds.contains(item.id)) item.id: item,
    };
    await _save(
      state.copyWith(
        definitions: [
          for (final ListDefinition definition in state.definitions)
            definition.id == listId ? result.definition : definition,
        ],
        items: [
          for (final ListItem item in state.items) changed[item.id] ?? item,
        ],
      ),
    );
  }

  Future<DeletedList?> deleteList(String listId) async {
    final ListDefinition? definition = state.definitions
        .where((definition) => definition.id == listId)
        .firstOrNull;
    if (definition == null) {
      return null;
    }

    final DeletedList deleted = DeletedList(
      definition: definition,
      items: state.items.where((item) => item.listId == listId).toList(),
    );
    await _save(
      state.copyWith(
        definitions: state.definitions.where((d) => d.id != listId).toList(),
        items: state.items.where((item) => item.listId != listId).toList(),
      ),
    );
    return deleted;
  }

  Future<void> restoreList(DeletedList deleted) {
    if (isCustom(deleted.definition.id)) {
      return Future.value();
    }
    return createList(deleted.definition, items: deleted.items);
  }

  Future<void> apply(ListChanges changes) {
    final Map<String, ListItem> saved = {
      for (final ListItem item in changes.saved) item.id: item,
    };
    final Set<String> deleted = changes.deletedIds.toSet();
    final List<ListItem> items = [];

    for (final ListItem item in state.items) {
      if (deleted.contains(item.id)) {
        continue;
      }
      items.add(saved.remove(item.id) ?? item);
    }
    items.addAll(saved.values);

    return _save(state.copyWith(items: items));
  }
}
