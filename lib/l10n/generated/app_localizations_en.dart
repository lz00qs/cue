// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Cue — Move what’s next';

  @override
  String get tagline => 'Move what’s next';

  @override
  String get language => 'Language';

  @override
  String get systemDefault => 'System default';

  @override
  String get chinese => '中文';

  @override
  String get english => 'English';

  @override
  String get back => 'Back';

  @override
  String get change => 'Change';

  @override
  String get save => 'Save';

  @override
  String get moreOptions => 'More options';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get enterValidEmail => 'Enter a valid email';

  @override
  String get passwordMinLength => 'Password must be at least 8 characters';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get signIn => 'Sign in';

  @override
  String get singleAdministrator =>
      'This workspace has one administrator account.';

  @override
  String get connectToCue => 'Connect to Cue';

  @override
  String get enterServerAddress => 'Enter the address of your Cue server';

  @override
  String get serverUrl => 'Server URL';

  @override
  String get serverUrlRequired => 'Enter a server URL';

  @override
  String get serverUrlSchemeRequired => 'Start with http:// or https://';

  @override
  String get serverUrlInvalid => 'Enter a valid server URL';

  @override
  String get serverUnreachable => 'Can\'t reach the server. Check the URL.';

  @override
  String get serverIncompatible => 'This is not a Cue server.';

  @override
  String get serverVerificationFailed =>
      'Could not verify the server. Try again.';

  @override
  String get serverUrlHelp =>
      'Start with http:// or https://; /api is optional.';

  @override
  String get connect => 'Connect';

  @override
  String get serverVerificationHelp =>
      'The server is verified before sign in. You can change it later in Settings.';

  @override
  String get inbox => 'Inbox';

  @override
  String get today => 'Today';

  @override
  String get tomorrow => 'Tomorrow';

  @override
  String get later => 'Later';

  @override
  String get upcoming => 'Upcoming';

  @override
  String get list => 'List';

  @override
  String get allTasks => 'All tasks';

  @override
  String get board => 'Board';

  @override
  String get calendar => 'Calendar';

  @override
  String get quadrants => 'Quadrants';

  @override
  String get settings => 'Settings';

  @override
  String get addTask => 'Add task';

  @override
  String openTaskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count open tasks',
      one: '1 open task',
      zero: 'No open tasks',
    );
    return '$_temp0';
  }

  @override
  String taskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tasks',
      one: '1 task',
      zero: 'No tasks',
    );
    return '$_temp0';
  }

  @override
  String get planWhatComesNext => 'Plan what comes next';

  @override
  String get oneTaskModel => 'One task model, every active item';

  @override
  String get monthViewDueOnly => 'Month view · Due dates only';

  @override
  String get importanceUrgencyTwoDays =>
      'Priority quadrants · one priority per quadrant';

  @override
  String get taskAddedToday => 'Task added to Today';

  @override
  String get newTask => 'New task';

  @override
  String get taskTitle => 'Task title';

  @override
  String get taskTitleHint => 'What needs to move next?';

  @override
  String get note => 'Note';

  @override
  String get notes => 'Notes';

  @override
  String get priority => 'Priority';

  @override
  String get status => 'Status';

  @override
  String get due => 'Due';

  @override
  String get dueDate => 'Due date';

  @override
  String get important => 'Important';

  @override
  String get quadrantUsage => 'Used by the quadrant view';

  @override
  String get quadrantControl => 'Controls the quadrant projection';

  @override
  String get showInPriorityQuadrants => 'Show in priority quadrants';

  @override
  String get cancel => 'Cancel';

  @override
  String get close => 'Close';

  @override
  String get defaultTaskNote => 'A focused next action in your Cue workspace.';

  @override
  String get deleteTask => 'Delete task';

  @override
  String get deleteTaskQuestion => 'Delete task?';

  @override
  String deleteTaskExplanation(String title) {
    return '“$title” will be removed from every view. The server keeps a sync tombstone so other sessions can apply the deletion.';
  }

  @override
  String get delete => 'Delete';

  @override
  String get noDueDate => 'No due date';

  @override
  String get noTime => 'No time';

  @override
  String get dueToday => 'Due today';

  @override
  String get dueTomorrow => 'Due tomorrow';

  @override
  String dueOn(String date) {
    return 'Due $date';
  }

  @override
  String completedAt(String time) {
    return 'Completed $time';
  }

  @override
  String get hardware => 'Hardware';

  @override
  String get simulation => 'Simulation';

  @override
  String get writing => 'Writing';

  @override
  String get operations => 'Operations';

  @override
  String get product => 'Product';

  @override
  String get personal => 'Personal';

  @override
  String get synced => 'Synced';

  @override
  String userSynced(String email) {
    return '$email · Synced';
  }

  @override
  String get signOut => 'Sign out';

  @override
  String get focusForToday => 'Focus for today';

  @override
  String openTasksLabel(int count) {
    return 'Open tasks · $count';
  }

  @override
  String comingUpLabel(int count) {
    return 'Coming up · $count';
  }

  @override
  String allTasksLabel(int count) {
    return 'All tasks · $count';
  }

  @override
  String tasksLabel(int count) {
    return 'Tasks · $count';
  }

  @override
  String get completed => 'Completed';

  @override
  String get quickAddHint => 'Add a task…  try “PCB review tomorrow 10:30”';

  @override
  String get add => 'Add';

  @override
  String get emptyList => 'Nothing here — enjoy the space.';

  @override
  String get groupPriority => 'Priority';

  @override
  String get groupDueDate => 'Due date';

  @override
  String get dragCards => 'Drag cards between groups';

  @override
  String get groupingPreview => 'Grouped tasks';

  @override
  String get month => 'Month';

  @override
  String get dueOnly => 'Due only';

  @override
  String scheduledSummary(int scheduled, int due) {
    return '$scheduled scheduled · $due due this week';
  }

  @override
  String get allTasksFilter => 'All tasks';

  @override
  String get importantFilter => 'Important';

  @override
  String get dueSoon => 'Due soon';

  @override
  String get urgentDefinition => 'Only P0 is important';

  @override
  String get doNow => 'Do now';

  @override
  String get doNowRule => 'P0 · Important';

  @override
  String get schedule => 'Schedule';

  @override
  String get scheduleRule => 'P1';

  @override
  String get batch => 'Batch';

  @override
  String get batchRule => 'P2';

  @override
  String get reconsider => 'Reconsider';

  @override
  String get reconsiderRule => 'P3';

  @override
  String get noMatchingTasks => 'No matching tasks';

  @override
  String get closeTaskDetails => 'Close task details';

  @override
  String get morning => 'MORNING';

  @override
  String get laterUpper => 'LATER';

  @override
  String get upcomingUpper => 'UPCOMING';

  @override
  String get priorityUpper => 'PRIORITY';

  @override
  String get allClear => 'All clear';

  @override
  String monthOverview(int year) {
    return '$year · month overview';
  }

  @override
  String get nextUp => 'Next up';

  @override
  String get nothingScheduled => 'Nothing scheduled';

  @override
  String get importantUrgent => 'P0 · Important';

  @override
  String get importantLater => 'P1';

  @override
  String get urgentLowerValue => 'P2';

  @override
  String get neither => 'P3';

  @override
  String get importanceUrgency => 'One priority per quadrant';

  @override
  String get localDemo => 'Local demo';

  @override
  String get syncing => 'Syncing…';

  @override
  String get needsAttention => 'Needs attention';

  @override
  String get connected => 'Connected';

  @override
  String get personalizeCue => 'Personalize Cue for the way you work';

  @override
  String get preferences => 'PREFERENCES';

  @override
  String get appearance => 'Appearance';

  @override
  String get dark => 'Dark';

  @override
  String get light => 'Light';

  @override
  String get dateAndTime => 'Date & time';

  @override
  String get system => 'System';

  @override
  String get reminders => 'Reminders';

  @override
  String get minutesBefore => '15 min before';

  @override
  String get widgets => 'Widgets';

  @override
  String get activeWidgetCount => '2 active';

  @override
  String get aiFeatures => 'AI features';

  @override
  String get on => 'On';

  @override
  String get accountAndData => 'ACCOUNT & DATA';

  @override
  String get importAndSync => 'Import & sync';

  @override
  String get helpAndGuide => 'Help & guide';

  @override
  String get multiDeviceSync => 'Multi-device sync';

  @override
  String get syncDescription =>
      'Changes use the same Cue workspace on mobile, web, and desktop. Updates arrive automatically while connected; Cue also syncs when the app resumes.';

  @override
  String get revision => 'Revision';

  @override
  String get lastSynced => 'Last synced';

  @override
  String get server => 'Server';

  @override
  String get syncNow => 'Sync now';

  @override
  String get changeServer => 'Change server';

  @override
  String get cueWorkspace => 'Cue workspace';

  @override
  String get focusStreak => 'Focus streak · 12 days';

  @override
  String get more => 'More';

  @override
  String get backToToday => 'Back to Today';

  @override
  String get openBoard => 'Open Board';

  @override
  String get addNotesChecklist => '+  Add notes or a checklist…';

  @override
  String get toggleComplete => 'Toggle complete';

  @override
  String createdOn(String date) {
    return 'Created $date';
  }

  @override
  String get createdToday => 'today';

  @override
  String get notYet => 'Not yet';

  @override
  String get group => 'Section';

  @override
  String get addGroup => 'Add Section';

  @override
  String get renameGroup => 'Rename Section';

  @override
  String get deleteGroup => 'Delete Section';

  @override
  String get ungrouped => 'Ungrouped';

  @override
  String get groupSection => 'By Section';

  @override
  String get groupPriorityNone => 'No Priority';

  @override
  String get groupPriorityHigh => 'High Priority';

  @override
  String get groupPriorityMedium => 'Medium Priority';

  @override
  String get groupPriorityLow => 'Low Priority';

  @override
  String get enterGroupName => 'Enter section name';

  @override
  String get seeMore => 'See more';
}
