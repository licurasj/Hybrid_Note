// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Hybrid Note App';

  @override
  String get home => 'Accueil';

  @override
  String get tasks => 'Tâches';

  @override
  String get grocery => 'Courses';

  @override
  String get journal => 'Journal';

  @override
  String get watchRead => 'Voir/Lire';

  @override
  String get language => 'Langue';

  @override
  String get languageSystem => 'Par défaut du système';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageChinese => '中文';

  @override
  String get languageJapanese => '日本語';

  @override
  String get languageFrench => 'Français';

  @override
  String get languageSpanish => 'Español';

  @override
  String get languageGerman => 'Deutsch';

  @override
  String get chooseLanguage => 'Choisir la langue';

  @override
  String get languageFollowsDevice => 'Use device language';

  @override
  String get switchToDarkMode => 'Passer au mode sombre';

  @override
  String get switchToLightMode => 'Passer au mode clair';

  @override
  String get pendingTasks => 'Pending Tasks';

  @override
  String get completedTasks => 'Completed Tasks';

  @override
  String get journalEntries => 'Journal Entries';

  @override
  String get watchReadItems => 'Watch/Read Items';

  @override
  String get groceryItems => 'Grocery Items';

  @override
  String get googleDriveSync => 'Google Drive Sync';

  @override
  String get syncing => 'Synchronisation...';

  @override
  String get notSyncedYet => 'Pas encore synchronisé.';

  @override
  String lastSynced(String date) {
    return 'Last synced: $date';
  }

  @override
  String get signInWithGoogle => 'Sign in with Google';

  @override
  String get logOut => 'Log out';

  @override
  String get syncToGoogleDrive => 'Synchroniser avec Google Drive';

  @override
  String get categories => 'Categories';

  @override
  String get allMyTasks => 'All My Tasks';

  @override
  String get createCategory => 'Create Category';

  @override
  String get createCategoryTooltip => 'Create category';

  @override
  String get closeCategories => 'Close categories';

  @override
  String get deleteCategory => 'Delete category';

  @override
  String get category => 'Category';

  @override
  String get categoryName => 'Category name';

  @override
  String get create => 'Create';

  @override
  String get cancel => 'Annuler';

  @override
  String get save => 'Enregistrer';

  @override
  String get clear => 'Clear';

  @override
  String get clearTicked => 'Clear Ticked';

  @override
  String get delete => 'Supprimer';

  @override
  String get edit => 'Modifier';

  @override
  String get add => 'Ajouter';

  @override
  String get addTask => 'Add Task';

  @override
  String get addTaskTooltip => 'Add task';

  @override
  String get editTask => 'Edit Task';

  @override
  String get titleRequired => 'Title *';

  @override
  String get title => 'Title';

  @override
  String get notes => 'Notes';

  @override
  String get setReminder => 'Set reminder';

  @override
  String get date => 'Date';

  @override
  String get time => 'Time';

  @override
  String get repeat => 'Repeat';

  @override
  String get doesNotRepeat => 'Does not repeat';

  @override
  String get daily => 'Daily';

  @override
  String get weekly => 'Weekly';

  @override
  String get monthly => 'Monthly';

  @override
  String get yearly => 'Yearly';

  @override
  String get custom => 'Custom';

  @override
  String get repeatEveryHowManyDays => 'Repeat every how many days?';

  @override
  String reminderText(String date) {
    return 'Reminder: $date';
  }

  @override
  String get today => 'Today';

  @override
  String get tomorrow => 'Tomorrow';

  @override
  String get later => 'Later';

  @override
  String get noTasksHereYet => 'No tasks here yet.';

  @override
  String tickedCount(int count) {
    return '$count ticked';
  }

  @override
  String get addSubtask => 'Add Subtask';

  @override
  String get editSubtask => 'Edit Subtask';

  @override
  String get subtaskTitleRequired => 'Subtask title *';

  @override
  String get subtasks => 'Subtasks';

  @override
  String get noSubtasksYet => 'No subtasks yet.';

  @override
  String subtaskProgress(int completed, int total) {
    return 'Subtasks: $completed/$total';
  }

  @override
  String repeats(String date, String repeat) {
    return '$date • repeats $repeat';
  }

  @override
  String repeatsEveryDays(String date, int days) {
    return '$date • repeats every $days day(s)';
  }

  @override
  String get groceryList => 'Grocery List';

  @override
  String get addGroceryItem => 'Add Grocery Item';

  @override
  String get addGroceryItemTooltip => 'Add grocery item';

  @override
  String get editGroceryItem => 'Edit Grocery Item';

  @override
  String get description => 'Description';

  @override
  String get section => 'Section';

  @override
  String get currentGroceryRun => 'Current Grocery Run';

  @override
  String get nextTime => 'Next Time';

  @override
  String get addAgainNextTime => 'Add again to Next Time when completed';

  @override
  String get addAgainNextTimeDescription =>
      'The item will appear in Next Time after you clear/delete it from Current Grocery Run.';

  @override
  String get noGroceriesCurrent => 'No groceries for this run yet.';

  @override
  String get noGroceriesNext => 'No saved groceries for next time yet.';

  @override
  String get moveToCurrentRun => 'Move to current run';

  @override
  String get moveToNextTime => 'Move to next time';

  @override
  String get repeatsToNextTime => 'Repeats to Next Time after clearing';

  @override
  String get addJournalEntry => 'Add Journal Entry';

  @override
  String get addJournalEntryTooltip => 'Add journal entry';

  @override
  String get editJournalEntry => 'Edit Journal Entry';

  @override
  String get entry => 'Entry';

  @override
  String get close => 'Close';

  @override
  String get noJournalEntriesYet => 'No journal entries yet.';

  @override
  String get watchReadList => 'Watch/Read List';

  @override
  String get addWatchReadItem => 'Add Watch/Read Item';

  @override
  String get addWatchReadItemTooltip => 'Add watch/read item';

  @override
  String get editWatchReadItem => 'Edit Watch/Read Item';

  @override
  String get type => 'Type';

  @override
  String get status => 'Status';

  @override
  String get movie => 'Movie';

  @override
  String get tvShow => 'TV Show';

  @override
  String get book => 'Book';

  @override
  String get planned => 'Planned';

  @override
  String get inProgress => 'In Progress';

  @override
  String get completed => 'Completed';

  @override
  String get season => 'Season';

  @override
  String get episode => 'Episode';

  @override
  String seasonNumber(int number) {
    return 'Season $number';
  }

  @override
  String episodeNumber(int number) {
    return 'Episode $number';
  }

  @override
  String get noWatchReadItemsYet => 'No watch/read items yet.';

  @override
  String get editList => 'Modifier la liste';

  @override
  String get newList => 'Nouvelle liste';

  @override
  String get untitledList => 'Liste sans titre';

  @override
  String get listName => 'Nom de la liste';

  @override
  String get listIcon => 'Icône';

  @override
  String get listColor => 'Couleur';

  @override
  String get fields => 'Champs';

  @override
  String get addField => 'Ajouter un champ';

  @override
  String get fieldName => 'Nom du champ';

  @override
  String get fieldType => 'Type de champ';

  @override
  String get required => 'Obligatoire';

  @override
  String get options => 'Options';

  @override
  String get addOption => 'Ajouter une option';

  @override
  String get layout => 'Disposition';

  @override
  String get groupBy => 'Grouper par';

  @override
  String get sectionBy => 'Sections par';

  @override
  String get dateField => 'Champ de date';

  @override
  String get splitByDate => 'Aujourd\'hui / Demain / Plus tard selon';

  @override
  String get filterBy => 'Filtrer par';

  @override
  String get none => 'Aucun';

  @override
  String get dateCreated => 'Date de création';

  @override
  String get rules => 'Règles';

  @override
  String get ruleClearCompleted => 'Effacer les éléments terminés';

  @override
  String get ruleRecurOnClear => 'Répéter à l\'effacement';

  @override
  String get ruleCopyOnClear => 'Copier à l\'effacement';

  @override
  String get ruleMoveAll => 'Bouton tout déplacer';

  @override
  String get allowAi => 'L\'IA peut lire cette liste';

  @override
  String get deleteList => 'Supprimer la liste';

  @override
  String get listDeleted => 'Liste supprimée';

  @override
  String get undo => 'Annuler';

  @override
  String get builtinListNote =>
      'Les listes intégrées gardent leurs champs jusqu\'au passage à Firestore. Vous pouvez changer le nom, l\'icône et la couleur.';

  @override
  String get localOnlyNote =>
      'Les nouvelles listes sont enregistrées sur cet appareil uniquement jusqu\'au passage à Firestore.';

  @override
  String get typeText => 'Texte';

  @override
  String get typeLongText => 'Texte long';

  @override
  String get typeCheckbox => 'Case à cocher';

  @override
  String get typeToggle => 'Interrupteur';

  @override
  String get typeNumber => 'Nombre';

  @override
  String get typeCounter => 'Compteur';

  @override
  String get typeRating => 'Note';

  @override
  String get typeDateTime => 'Date et heure';

  @override
  String get typeChoice => 'Choix';

  @override
  String get typeTags => 'Étiquettes';

  @override
  String get typeUrl => 'Lien';

  @override
  String get typeChecklist => 'Sous-éléments';

  @override
  String get viewChecklist => 'Liste de contrôle';

  @override
  String get viewSectioned => 'Sections';

  @override
  String get viewTimeline => 'Chronologie';

  @override
  String get viewGrouped => 'Groupes';

  @override
  String get viewTable => 'Tableau';

  @override
  String get viewCards => 'Cartes';

  @override
  String get launcherHub => 'Listes';

  @override
  String get previous => 'Précédent';

  @override
  String get next => 'Suivant';

  @override
  String get launcherNoteHint =>
      'Touchez deux fois pour ouvrir, appuyez longuement pour modifier';

  @override
  String hiddenValuesWarning(int count) {
    return '$count valeurs ne correspondent pas au nouveau type et seront conservées masquées';
  }

  @override
  String itemsCount(String name, int count) {
    return '$name, $count éléments';
  }

  @override
  String get moveHub => 'Déplacer';
}
