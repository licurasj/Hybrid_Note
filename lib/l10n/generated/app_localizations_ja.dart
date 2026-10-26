// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'Hybrid Note App';

  @override
  String get home => 'ホーム';

  @override
  String get tasks => 'タスク';

  @override
  String get grocery => '買い物';

  @override
  String get journal => '日記';

  @override
  String get watchRead => '視聴/読書';

  @override
  String get language => '言語';

  @override
  String get languageSystem => 'システム既定';

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
  String get chooseLanguage => '言語を選択';

  @override
  String get languageFollowsDevice => 'Use device language';

  @override
  String get switchToDarkMode => 'ダークモードに切り替え';

  @override
  String get switchToLightMode => 'ライトモードに切り替え';

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
  String get syncing => '同期中...';

  @override
  String get notSyncedYet => 'まだ同期されていません。';

  @override
  String lastSynced(String date) {
    return 'Last synced: $date';
  }

  @override
  String get signInWithGoogle => 'Sign in with Google';

  @override
  String get logOut => 'Log out';

  @override
  String get syncToGoogleDrive => 'Google Drive に同期';

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
  String get cancel => 'キャンセル';

  @override
  String get save => '保存';

  @override
  String get clear => 'Clear';

  @override
  String get clearTicked => 'Clear Ticked';

  @override
  String get delete => '削除';

  @override
  String get edit => '編集';

  @override
  String get add => '追加';

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
  String get editList => 'リストを編集';

  @override
  String get newList => '新しいリスト';

  @override
  String get untitledList => '無題のリスト';

  @override
  String get listName => 'リスト名';

  @override
  String get listIcon => 'アイコン';

  @override
  String get listColor => '色';

  @override
  String get fields => '項目';

  @override
  String get addField => '項目を追加';

  @override
  String get fieldName => '項目名';

  @override
  String get fieldType => '項目の種類';

  @override
  String get required => '必須';

  @override
  String get options => '選択肢';

  @override
  String get addOption => '選択肢を追加';

  @override
  String get layout => 'レイアウト';

  @override
  String get groupBy => 'グループ化';

  @override
  String get sectionBy => 'セクション';

  @override
  String get dateField => '日付の項目';

  @override
  String get splitByDate => '今日 / 明日 / 後で の基準';

  @override
  String get filterBy => '絞り込み';

  @override
  String get none => 'なし';

  @override
  String get dateCreated => '作成日';

  @override
  String get rules => 'ルール';

  @override
  String get ruleClearCompleted => '完了した項目を消去';

  @override
  String get ruleRecurOnClear => '消去時に繰り返す';

  @override
  String get ruleCopyOnClear => '消去時にコピー';

  @override
  String get ruleMoveAll => 'すべて移動ボタン';

  @override
  String get allowAi => 'AIがこのリストを読むことを許可';

  @override
  String get deleteList => 'リストを削除';

  @override
  String get listDeleted => 'リストを削除しました';

  @override
  String get undo => '元に戻す';

  @override
  String get builtinListNote =>
      '組み込みリストの項目は Firestore への移行まで変更できません。名前・アイコン・色は変更できます。';

  @override
  String get localOnlyNote => '新しいリストは Firestore への移行まで、この端末にのみ保存されます。';

  @override
  String get typeText => 'テキスト';

  @override
  String get typeLongText => '長いテキスト';

  @override
  String get typeCheckbox => 'チェックボックス';

  @override
  String get typeToggle => 'スイッチ';

  @override
  String get typeNumber => '数値';

  @override
  String get typeCounter => 'カウンター';

  @override
  String get typeRating => '評価';

  @override
  String get typeDateTime => '日時';

  @override
  String get typeChoice => '選択';

  @override
  String get typeTags => 'タグ';

  @override
  String get typeUrl => 'リンク';

  @override
  String get typeChecklist => 'サブ項目';

  @override
  String get viewChecklist => 'チェックリスト';

  @override
  String get viewSectioned => 'セクション';

  @override
  String get viewTimeline => 'タイムライン';

  @override
  String get viewGrouped => 'グループ';

  @override
  String get viewTable => '表';

  @override
  String get viewCards => 'カード';

  @override
  String get launcherHub => 'リスト';

  @override
  String get previous => '前へ';

  @override
  String get next => '次へ';

  @override
  String get launcherNoteHint => 'ダブルタップで開く、長押しで編集';

  @override
  String hiddenValuesWarning(int count) {
    return '$count 件の値は新しい種類に合わないため、非表示で保持されます';
  }

  @override
  String itemsCount(String name, int count) {
    return '$name、$count 件';
  }
}
