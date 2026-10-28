import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'app_cubit.dart';
import 'app_state.dart';
import 'app_storage.dart';
import 'drive_sync_service.dart';
import 'firebase_options.dart';
import 'home_screen.dart';
import 'app_colors.dart';
import 'l10n/generated/app_localizations.dart';
import 'launcher/radial_launcher.dart';
import 'lists/builtin_templates.dart';
import 'lists/generic_list_host.dart';
import 'lists/custom_lists.dart';
import 'lists/list_catalog.dart';
import 'lists/list_definition.dart';
import 'lists/list_editor_screen.dart';
import 'lists/list_icons.dart';
import 'lists/list_labels.dart';
import 'lists/list_patch.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final AppStorage storage = AppStorage();
  final String deviceId = await storage.getOrCreateDeviceId();

  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => AppCubit(
            storage: storage,
            driveSyncService: DriveSyncService(),
            deviceId: deviceId,
          )..loadData(),
        ),
        BlocProvider(
          create: (_) => CustomListsCubit(CustomListsStorage())..load(),
        ),
      ],
      child: const HybridNoteApp(),
    ),
  );
}

class HybridNoteApp extends StatelessWidget {
  const HybridNoteApp({super.key});

  ThemeData _buildLightTheme() {
    return ThemeData(
      fontFamily: 'Segoe UI',
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.logoBlue,
        brightness: Brightness.light,
        primary: AppColors.actionBlue,
        onPrimary: Colors.white,
        primaryContainer: AppColors.selectedBlue,
        onPrimaryContainer: AppColors.darkBlue,
        surface: Colors.white,
        onSurface: AppColors.darkBlue,
      ),
      scaffoldBackgroundColor: AppColors.softBackground,
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: AppColors.darkBlue),
        bodyMedium: TextStyle(color: AppColors.darkBlue),
        bodySmall: TextStyle(color: AppColors.mutedText),
        titleLarge: TextStyle(color: AppColors.darkBlue),
        titleMedium: TextStyle(color: AppColors.darkBlue),
        titleSmall: TextStyle(color: AppColors.darkBlue),
        labelLarge: TextStyle(color: AppColors.darkBlue),
        labelMedium: TextStyle(color: AppColors.darkBlue),
        labelSmall: TextStyle(color: AppColors.mutedText),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.darkBlue,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.darkBlue,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          fontFamily: 'Segoe UI',
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.actionBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.actionBlue,
          side: const BorderSide(
            color: AppColors.actionBlue,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(
            color: AppColors.actionBlue,
            width: 2,
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: AppColors.selectedBlue,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(
            color: AppColors.darkBlue,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderBlue,
      ),
      useMaterial3: true,
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData(
      fontFamily: 'Segoe UI',
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.logoBlue,
        brightness: Brightness.dark,
        primary: AppColors.logoBlue,
        onPrimary: AppColors.darkBackground,
        primaryContainer: AppColors.darkSelectedBlue,
        onPrimaryContainer: AppColors.darkText,
        surface: AppColors.darkSurface,
        onSurface: AppColors.darkText,
      ),
      scaffoldBackgroundColor: AppColors.darkBackground,
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: AppColors.darkText),
        bodyMedium: TextStyle(color: AppColors.darkText),
        bodySmall: TextStyle(color: AppColors.darkMutedText),
        titleLarge: TextStyle(color: AppColors.darkText),
        titleMedium: TextStyle(color: AppColors.darkText),
        titleSmall: TextStyle(color: AppColors.darkText),
        labelLarge: TextStyle(color: AppColors.darkText),
        labelMedium: TextStyle(color: AppColors.darkText),
        labelSmall: TextStyle(color: AppColors.darkMutedText),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkSurface,
        foregroundColor: AppColors.darkText,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.darkText,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          fontFamily: 'Segoe UI',
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkSurface,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.logoBlue,
          foregroundColor: AppColors.darkBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.logoBlue,
          side: const BorderSide(
            color: AppColors.logoBlue,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurfaceSoft,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(
            color: AppColors.logoBlue,
            width: 2,
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.darkSurface,
        indicatorColor: AppColors.darkSelectedBlue,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(
            color: AppColors.darkText,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.darkBorderBlue,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.darkSurface,
      ),
      useMaterial3: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppCubit, AppState>(
      builder: (context, state) {
        return MaterialApp(
          onGenerateTitle: (context) {
            return AppLocalizations.of(context).appTitle;
          },
          debugShowCheckedModeBanner: false,
          locale: state.selectedLocaleCode == null
              ? null
              : Locale(state.selectedLocaleCode!),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: _buildLightTheme(),
          darkTheme: _buildDarkTheme(),
          themeMode: state.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          home: const MainShell(),
        );
      },
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() {
    return _MainShellState();
  }
}

class _MainShellState extends State<MainShell> {
  // Lists in the order they were last opened, newest first, so the common
  // case never needs scrolling (plan 5.3). Kept in memory for now.
  final List<String> _recent = [];

  static const List<String> _homeTargets = [
    BuiltinTemplates.tasksId,
    BuiltinTemplates.groceryId,
    BuiltinTemplates.journalId,
    BuiltinTemplates.watchReadId,
  ];

  void _openList(String listId) {
    setState(() {
      _recent
        ..remove(listId)
        ..insert(0, listId);
    });
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GenericListHost(listId: listId),
      ),
    );
  }

  // Home dashboard cards use the old tab numbers: 1 tasks, 2 grocery,
  // 3 journal, 4 watch/read.
  void _openFromHome(int index) {
    if (index >= 1 && index <= _homeTargets.length) {
      _openList(_homeTargets[index - 1]);
    }
  }

  List<LauncherNote> _notes(AppLocalizations loc, ListCatalog catalog) {
    final ListLabels labels = ListLabels(loc);
    final List<ListDefinition> ordered = [...catalog.definitions]
      ..sort((a, b) {
        int rank(ListDefinition definition) {
          final int index = _recent.indexOf(definition.id);
          return index < 0
              ? _recent.length + catalog.definitions.indexOf(definition)
              : index;
        }

        return rank(a).compareTo(rank(b));
      });

    return [
      for (final ListDefinition definition in ordered)
        LauncherNote(
          id: definition.id,
          label: labels.listName(definition),
          icon: listIcon(definition.icon),
          color: listColor(definition.color),
          semanticsLabel: loc.itemsCount(
            labels.listName(definition),
            catalog.itemsOf(definition.id).length,
          ),
        ),
    ];
  }

  ListCatalog _catalog() {
    return ListCatalog.from(
      context.read<AppCubit>().state,
      context.read<CustomListsCubit>().state,
    );
  }

  Future<void> _newList() async {
    final AppLocalizations loc = AppLocalizations.of(context);
    final ListEditorOutcome? outcome = await Navigator.of(context).push(
      MaterialPageRoute<ListEditorOutcome>(
        builder: (_) => ListEditorScreen(
          definition: blankListDefinition(loc),
          isNew: true,
        ),
      ),
    );
    final ListPatchResult? result = outcome?.result;
    if (!mounted || result == null || !result.isValid) {
      return;
    }

    await context.read<CustomListsCubit>().createList(result.definition);
    if (mounted) {
      _openList(result.definition.id);
    }
  }

  Future<void> _editList(String listId) async {
    final ListCatalog catalog = _catalog();
    final ListDefinition? definition = catalog.definition(listId);
    if (definition == null) {
      return;
    }

    final ListEditorOutcome? outcome = await Navigator.of(context).push(
      MaterialPageRoute<ListEditorOutcome>(
        builder: (_) => ListEditorScreen(
          definition: definition,
          items: catalog.itemsOf(listId),
        ),
      ),
    );
    if (!mounted || outcome == null) {
      return;
    }

    final CustomListsCubit custom = context.read<CustomListsCubit>();
    if (outcome.deleted) {
      await _deleteList(listId);
      return;
    }

    // Re-apply the ops to the current items, in case they changed meanwhile.
    final ListCatalog fresh = _catalog();
    final ListDefinition? current = fresh.definition(listId);
    if (current == null) {
      return;
    }
    final ListPatchResult result = ListPatch.apply(
      current,
      fresh.itemsOf(listId),
      outcome.ops,
      DateTime.now().toUtc(),
    );
    if (result.isValid) {
      await custom.savePatched(result, outcome.ops);
    }
  }

  // Deleting is immediate, with Undo in a snackbar and no trash bin (D-5).
  Future<void> _deleteList(String listId) async {
    final AppLocalizations loc = AppLocalizations.of(context);
    final CustomListsCubit custom = context.read<CustomListsCubit>();
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final DeletedList? deleted = await custom.deleteList(listId);
    if (deleted == null) {
      return;
    }

    setState(() => _recent.remove(listId));
    messenger.showSnackBar(
      SnackBar(
        content: Text(loc.listDeleted),
        // A snackbar with an action stays until dismissed unless told
        // otherwise; Undo is only offered for a short while.
        persist: false,
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: loc.undo,
          onPressed: () => custom.restoreList(deleted),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AppCubit, AppState>(
      listenWhen: (oldState, newState) {
        return oldState.errorMessage != newState.errorMessage ||
            oldState.syncMessage != newState.syncMessage;
      },
      listener: (context, state) {
        final String? message = state.errorMessage ?? state.syncMessage;

        if (message != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        }
      },
      child: Scaffold(
        body: BlocBuilder<CustomListsCubit, CustomListsData>(
          builder: (context, custom) => BlocBuilder<AppCubit, AppState>(
          builder: (context, state) {
            final AppLocalizations loc = AppLocalizations.of(context);
            final ListCatalog catalog = ListCatalog.from(state, custom);
            return Stack(
              children: [
                // Room below the dashboard so the hub never covers it.
                Padding(
                  padding: const EdgeInsets.only(bottom: 88),
                  child: HomeScreen(onNavigate: _openFromHome),
                ),
                Positioned.fill(
                  child: RadialLauncher(
                    notes: _notes(loc, catalog),
                    onOpen: (note) => _openList(note.id),
                    onEdit: (note) => _editList(note.id),
                    onNew: _newList,
                    hubTooltip: loc.launcherHub,
                    editLabel: loc.edit,
                    moveLabel: loc.moveHub,
                    addLabel: loc.newList,
                    previousLabel: loc.previous,
                    nextLabel: loc.next,
                    noteHint: loc.launcherNoteHint,
                    hubPosition: state.hubPosition,
                    onHubMoved: context.read<AppCubit>().setHubPosition,
                  ),
                ),
              ],
            );
          },
          ),
        ),
      ),
    );
  }
}
