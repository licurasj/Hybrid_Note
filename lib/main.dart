import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'app_cubit.dart';
import 'app_state.dart';
import 'app_storage.dart';
import 'drive_sync_service.dart';
import 'home_screen.dart';
import 'app_colors.dart';
import 'l10n/generated/app_localizations.dart';
import 'launcher/radial_launcher.dart';
import 'lists/builtin_templates.dart';
import 'lists/generic_list_host.dart';
import 'lists/legacy_lists.dart';
import 'lists/list_definition.dart';
import 'lists/list_icons.dart';
import 'lists/list_labels.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final AppStorage storage = AppStorage();
  final String deviceId = await storage.getOrCreateDeviceId();

  runApp(
    BlocProvider(
      create: (_) => AppCubit(
        storage: storage,
        driveSyncService: DriveSyncService(),
        deviceId: deviceId,
      )..loadData(),
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

  List<LauncherNote> _notes(AppLocalizations loc, AppState state) {
    final LegacyImport lists = LegacyLists.importAppData(state.data);
    final ListLabels labels = ListLabels(loc);
    final List<ListDefinition> ordered = [...lists.definitions]
      ..sort((a, b) {
        int rank(ListDefinition definition) {
          final int index = _recent.indexOf(definition.id);
          return index < 0 ? _recent.length + lists.definitions.indexOf(definition) : index;
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
          semanticsLabel:
              '${labels.listName(definition)}, ${lists.items.where((item) => item.listId == definition.id).length}',
        ),
    ];
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
        body: BlocBuilder<AppCubit, AppState>(
          builder: (context, state) {
            final AppLocalizations loc = AppLocalizations.of(context);
            return Stack(
              children: [
                // Room below the dashboard so the hub never covers it.
                Padding(
                  padding: const EdgeInsets.only(bottom: 88),
                  child: HomeScreen(onNavigate: _openFromHome),
                ),
                Positioned.fill(
                  child: RadialLauncher(
                    notes: _notes(loc, state),
                    onOpen: (note) => _openList(note.id),
                    // The list editor is Phase 4; until then Edit opens the list.
                    onEdit: (note) => _openList(note.id),
                    editLabel: loc.edit,
                    addLabel: loc.add,
                    hubPosition: state.hubPosition,
                    onHubMoved: context.read<AppCubit>().setHubPosition,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
