import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Cue — Move what’s next'**
  String get appTitle;

  /// No description provided for @tagline.
  ///
  /// In en, this message translates to:
  /// **'Move what’s next'**
  String get tagline;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @systemDefault.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get systemDefault;

  /// No description provided for @chinese.
  ///
  /// In en, this message translates to:
  /// **'中文'**
  String get chinese;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @change.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get change;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @moreOptions.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get moreOptions;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @enterValidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email'**
  String get enterValidEmail;

  /// No description provided for @passwordMinLength.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters'**
  String get passwordMinLength;

  /// No description provided for @showPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePassword;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @singleAdministrator.
  ///
  /// In en, this message translates to:
  /// **'This workspace has one administrator account.'**
  String get singleAdministrator;

  /// No description provided for @connectToCue.
  ///
  /// In en, this message translates to:
  /// **'Connect to Cue'**
  String get connectToCue;

  /// No description provided for @enterServerAddress.
  ///
  /// In en, this message translates to:
  /// **'Enter the address of your Cue server'**
  String get enterServerAddress;

  /// No description provided for @serverUrl.
  ///
  /// In en, this message translates to:
  /// **'Server URL'**
  String get serverUrl;

  /// No description provided for @serverUrlHelp.
  ///
  /// In en, this message translates to:
  /// **'Use the base address you open in a browser. “/api” is optional. Prefer HTTPS outside a trusted local network.'**
  String get serverUrlHelp;

  /// No description provided for @connect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// No description provided for @serverVerificationHelp.
  ///
  /// In en, this message translates to:
  /// **'The server is verified before sign in. You can change it later in Settings.'**
  String get serverVerificationHelp;

  /// No description provided for @inbox.
  ///
  /// In en, this message translates to:
  /// **'Inbox'**
  String get inbox;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @tomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get tomorrow;

  /// No description provided for @later.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get later;

  /// No description provided for @upcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get upcoming;

  /// No description provided for @list.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get list;

  /// No description provided for @allTasks.
  ///
  /// In en, this message translates to:
  /// **'All tasks'**
  String get allTasks;

  /// No description provided for @board.
  ///
  /// In en, this message translates to:
  /// **'Board'**
  String get board;

  /// No description provided for @calendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get calendar;

  /// No description provided for @quadrants.
  ///
  /// In en, this message translates to:
  /// **'Quadrants'**
  String get quadrants;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @addTask.
  ///
  /// In en, this message translates to:
  /// **'Add task'**
  String get addTask;

  /// No description provided for @openTaskCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No open tasks} =1{1 open task} other{{count} open tasks}}'**
  String openTaskCount(int count);

  /// No description provided for @taskCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No tasks} =1{1 task} other{{count} tasks}}'**
  String taskCount(int count);

  /// No description provided for @planWhatComesNext.
  ///
  /// In en, this message translates to:
  /// **'Plan what comes next'**
  String get planWhatComesNext;

  /// No description provided for @oneTaskModel.
  ///
  /// In en, this message translates to:
  /// **'One task model, every active item'**
  String get oneTaskModel;

  /// No description provided for @threeStages.
  ///
  /// In en, this message translates to:
  /// **'Three focused stages, one task model'**
  String get threeStages;

  /// No description provided for @monthViewDueOnly.
  ///
  /// In en, this message translates to:
  /// **'Month view · Due dates only'**
  String get monthViewDueOnly;

  /// No description provided for @importanceUrgencyTwoDays.
  ///
  /// In en, this message translates to:
  /// **'Importance × urgency · urgency within 2 days'**
  String get importanceUrgencyTwoDays;

  /// No description provided for @taskAddedToday.
  ///
  /// In en, this message translates to:
  /// **'Task added to Today'**
  String get taskAddedToday;

  /// No description provided for @newTask.
  ///
  /// In en, this message translates to:
  /// **'New task'**
  String get newTask;

  /// No description provided for @taskTitle.
  ///
  /// In en, this message translates to:
  /// **'Task title'**
  String get taskTitle;

  /// No description provided for @taskTitleHint.
  ///
  /// In en, this message translates to:
  /// **'What needs to move next?'**
  String get taskTitleHint;

  /// No description provided for @note.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get note;

  /// No description provided for @notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// No description provided for @priority.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get priority;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @toDo.
  ///
  /// In en, this message translates to:
  /// **'To do'**
  String get toDo;

  /// No description provided for @doing.
  ///
  /// In en, this message translates to:
  /// **'Doing'**
  String get doing;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @due.
  ///
  /// In en, this message translates to:
  /// **'Due'**
  String get due;

  /// No description provided for @dueDate.
  ///
  /// In en, this message translates to:
  /// **'Due date'**
  String get dueDate;

  /// No description provided for @important.
  ///
  /// In en, this message translates to:
  /// **'Important'**
  String get important;

  /// No description provided for @quadrantUsage.
  ///
  /// In en, this message translates to:
  /// **'Used by the quadrant view'**
  String get quadrantUsage;

  /// No description provided for @quadrantControl.
  ///
  /// In en, this message translates to:
  /// **'Controls the quadrant projection'**
  String get quadrantControl;

  /// No description provided for @showInPriorityQuadrants.
  ///
  /// In en, this message translates to:
  /// **'Show in priority quadrants'**
  String get showInPriorityQuadrants;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @defaultTaskNote.
  ///
  /// In en, this message translates to:
  /// **'A focused next action in your Cue workspace.'**
  String get defaultTaskNote;

  /// No description provided for @moveToDoing.
  ///
  /// In en, this message translates to:
  /// **'Move to Doing'**
  String get moveToDoing;

  /// No description provided for @reopen.
  ///
  /// In en, this message translates to:
  /// **'Reopen'**
  String get reopen;

  /// No description provided for @complete.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get complete;

  /// No description provided for @deleteTask.
  ///
  /// In en, this message translates to:
  /// **'Delete task'**
  String get deleteTask;

  /// No description provided for @deleteTaskQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete task?'**
  String get deleteTaskQuestion;

  /// No description provided for @deleteTaskExplanation.
  ///
  /// In en, this message translates to:
  /// **'“{title}” will be removed from every view. The server keeps a sync tombstone so other sessions can apply the deletion.'**
  String deleteTaskExplanation(String title);

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @noDueDate.
  ///
  /// In en, this message translates to:
  /// **'No due date'**
  String get noDueDate;

  /// No description provided for @noTime.
  ///
  /// In en, this message translates to:
  /// **'No time'**
  String get noTime;

  /// No description provided for @dueToday.
  ///
  /// In en, this message translates to:
  /// **'Due today'**
  String get dueToday;

  /// No description provided for @dueTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Due tomorrow'**
  String get dueTomorrow;

  /// No description provided for @dueOn.
  ///
  /// In en, this message translates to:
  /// **'Due {date}'**
  String dueOn(String date);

  /// No description provided for @completedAt.
  ///
  /// In en, this message translates to:
  /// **'Completed {time}'**
  String completedAt(String time);

  /// No description provided for @hardware.
  ///
  /// In en, this message translates to:
  /// **'Hardware'**
  String get hardware;

  /// No description provided for @simulation.
  ///
  /// In en, this message translates to:
  /// **'Simulation'**
  String get simulation;

  /// No description provided for @writing.
  ///
  /// In en, this message translates to:
  /// **'Writing'**
  String get writing;

  /// No description provided for @operations.
  ///
  /// In en, this message translates to:
  /// **'Operations'**
  String get operations;

  /// No description provided for @product.
  ///
  /// In en, this message translates to:
  /// **'Product'**
  String get product;

  /// No description provided for @personal.
  ///
  /// In en, this message translates to:
  /// **'Personal'**
  String get personal;

  /// No description provided for @synced.
  ///
  /// In en, this message translates to:
  /// **'Synced'**
  String get synced;

  /// No description provided for @userSynced.
  ///
  /// In en, this message translates to:
  /// **'{email} · Synced'**
  String userSynced(String email);

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @focusForToday.
  ///
  /// In en, this message translates to:
  /// **'Focus for today'**
  String get focusForToday;

  /// No description provided for @openTasksLabel.
  ///
  /// In en, this message translates to:
  /// **'Open tasks · {count}'**
  String openTasksLabel(int count);

  /// No description provided for @comingUpLabel.
  ///
  /// In en, this message translates to:
  /// **'Coming up · {count}'**
  String comingUpLabel(int count);

  /// No description provided for @allTasksLabel.
  ///
  /// In en, this message translates to:
  /// **'All tasks · {count}'**
  String allTasksLabel(int count);

  /// No description provided for @tasksLabel.
  ///
  /// In en, this message translates to:
  /// **'Tasks · {count}'**
  String tasksLabel(int count);

  /// No description provided for @completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// No description provided for @quickAddHint.
  ///
  /// In en, this message translates to:
  /// **'Add a task…  try “PCB review tomorrow 10:30”'**
  String get quickAddHint;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @emptyList.
  ///
  /// In en, this message translates to:
  /// **'Nothing here — enjoy the space.'**
  String get emptyList;

  /// No description provided for @groupStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get groupStatus;

  /// No description provided for @groupPriority.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get groupPriority;

  /// No description provided for @groupDueDate.
  ///
  /// In en, this message translates to:
  /// **'Due date'**
  String get groupDueDate;

  /// No description provided for @dragCards.
  ///
  /// In en, this message translates to:
  /// **'Drag cards to update status'**
  String get dragCards;

  /// No description provided for @groupingPreview.
  ///
  /// In en, this message translates to:
  /// **'Grouped tasks'**
  String get groupingPreview;

  /// No description provided for @todoColumn.
  ///
  /// In en, this message translates to:
  /// **'TODO'**
  String get todoColumn;

  /// No description provided for @doingColumn.
  ///
  /// In en, this message translates to:
  /// **'DOING'**
  String get doingColumn;

  /// No description provided for @doneColumn.
  ///
  /// In en, this message translates to:
  /// **'DONE'**
  String get doneColumn;

  /// No description provided for @month.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get month;

  /// No description provided for @dueOnly.
  ///
  /// In en, this message translates to:
  /// **'Due only'**
  String get dueOnly;

  /// No description provided for @scheduledSummary.
  ///
  /// In en, this message translates to:
  /// **'{scheduled} scheduled · {due} due this week'**
  String scheduledSummary(int scheduled, int due);

  /// No description provided for @allTasksFilter.
  ///
  /// In en, this message translates to:
  /// **'All tasks'**
  String get allTasksFilter;

  /// No description provided for @importantFilter.
  ///
  /// In en, this message translates to:
  /// **'Important'**
  String get importantFilter;

  /// No description provided for @dueSoon.
  ///
  /// In en, this message translates to:
  /// **'Due soon'**
  String get dueSoon;

  /// No description provided for @urgentDefinition.
  ///
  /// In en, this message translates to:
  /// **'Urgent = due within 2 days'**
  String get urgentDefinition;

  /// No description provided for @doNow.
  ///
  /// In en, this message translates to:
  /// **'Do now'**
  String get doNow;

  /// No description provided for @doNowRule.
  ///
  /// In en, this message translates to:
  /// **'Important · due within 2 days'**
  String get doNowRule;

  /// No description provided for @schedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get schedule;

  /// No description provided for @scheduleRule.
  ///
  /// In en, this message translates to:
  /// **'Important · not urgent'**
  String get scheduleRule;

  /// No description provided for @batch.
  ///
  /// In en, this message translates to:
  /// **'Batch'**
  String get batch;

  /// No description provided for @batchRule.
  ///
  /// In en, this message translates to:
  /// **'Due soon · lower importance'**
  String get batchRule;

  /// No description provided for @reconsider.
  ///
  /// In en, this message translates to:
  /// **'Reconsider'**
  String get reconsider;

  /// No description provided for @reconsiderRule.
  ///
  /// In en, this message translates to:
  /// **'Neither important nor urgent'**
  String get reconsiderRule;

  /// No description provided for @noMatchingTasks.
  ///
  /// In en, this message translates to:
  /// **'No matching tasks'**
  String get noMatchingTasks;

  /// No description provided for @closeTaskDetails.
  ///
  /// In en, this message translates to:
  /// **'Close task details'**
  String get closeTaskDetails;

  /// No description provided for @morning.
  ///
  /// In en, this message translates to:
  /// **'MORNING'**
  String get morning;

  /// No description provided for @laterUpper.
  ///
  /// In en, this message translates to:
  /// **'LATER'**
  String get laterUpper;

  /// No description provided for @upcomingUpper.
  ///
  /// In en, this message translates to:
  /// **'UPCOMING'**
  String get upcomingUpper;

  /// No description provided for @priorityUpper.
  ///
  /// In en, this message translates to:
  /// **'PRIORITY'**
  String get priorityUpper;

  /// No description provided for @allClear.
  ///
  /// In en, this message translates to:
  /// **'All clear'**
  String get allClear;

  /// No description provided for @swipeStages.
  ///
  /// In en, this message translates to:
  /// **'Swipe stages · {count}'**
  String swipeStages(String count);

  /// No description provided for @monthOverview.
  ///
  /// In en, this message translates to:
  /// **'{year} · month overview'**
  String monthOverview(int year);

  /// No description provided for @nextUp.
  ///
  /// In en, this message translates to:
  /// **'Next up'**
  String get nextUp;

  /// No description provided for @nothingScheduled.
  ///
  /// In en, this message translates to:
  /// **'Nothing scheduled'**
  String get nothingScheduled;

  /// No description provided for @importantUrgent.
  ///
  /// In en, this message translates to:
  /// **'Important · urgent'**
  String get importantUrgent;

  /// No description provided for @importantLater.
  ///
  /// In en, this message translates to:
  /// **'Important · later'**
  String get importantLater;

  /// No description provided for @urgentLowerValue.
  ///
  /// In en, this message translates to:
  /// **'Urgent · lower value'**
  String get urgentLowerValue;

  /// No description provided for @neither.
  ///
  /// In en, this message translates to:
  /// **'Neither'**
  String get neither;

  /// No description provided for @importanceUrgency.
  ///
  /// In en, this message translates to:
  /// **'Importance × urgency'**
  String get importanceUrgency;

  /// No description provided for @localDemo.
  ///
  /// In en, this message translates to:
  /// **'Local demo'**
  String get localDemo;

  /// No description provided for @syncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing…'**
  String get syncing;

  /// No description provided for @needsAttention.
  ///
  /// In en, this message translates to:
  /// **'Needs attention'**
  String get needsAttention;

  /// No description provided for @connected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connected;

  /// No description provided for @personalizeCue.
  ///
  /// In en, this message translates to:
  /// **'Personalize Cue for the way you work'**
  String get personalizeCue;

  /// No description provided for @preferences.
  ///
  /// In en, this message translates to:
  /// **'PREFERENCES'**
  String get preferences;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

  /// No description provided for @light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// No description provided for @dateAndTime.
  ///
  /// In en, this message translates to:
  /// **'Date & time'**
  String get dateAndTime;

  /// No description provided for @system.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get system;

  /// No description provided for @reminders.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get reminders;

  /// No description provided for @minutesBefore.
  ///
  /// In en, this message translates to:
  /// **'15 min before'**
  String get minutesBefore;

  /// No description provided for @widgets.
  ///
  /// In en, this message translates to:
  /// **'Widgets'**
  String get widgets;

  /// No description provided for @activeWidgetCount.
  ///
  /// In en, this message translates to:
  /// **'2 active'**
  String get activeWidgetCount;

  /// No description provided for @aiFeatures.
  ///
  /// In en, this message translates to:
  /// **'AI features'**
  String get aiFeatures;

  /// No description provided for @on.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get on;

  /// No description provided for @accountAndData.
  ///
  /// In en, this message translates to:
  /// **'ACCOUNT & DATA'**
  String get accountAndData;

  /// No description provided for @importAndSync.
  ///
  /// In en, this message translates to:
  /// **'Import & sync'**
  String get importAndSync;

  /// No description provided for @helpAndGuide.
  ///
  /// In en, this message translates to:
  /// **'Help & guide'**
  String get helpAndGuide;

  /// No description provided for @multiDeviceSync.
  ///
  /// In en, this message translates to:
  /// **'Multi-device sync'**
  String get multiDeviceSync;

  /// No description provided for @syncDescription.
  ///
  /// In en, this message translates to:
  /// **'Changes use the same Cue workspace on mobile, web, and desktop. Updates arrive automatically while connected; Cue also syncs when the app resumes.'**
  String get syncDescription;

  /// No description provided for @revision.
  ///
  /// In en, this message translates to:
  /// **'Revision'**
  String get revision;

  /// No description provided for @lastSynced.
  ///
  /// In en, this message translates to:
  /// **'Last synced'**
  String get lastSynced;

  /// No description provided for @server.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get server;

  /// No description provided for @syncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get syncNow;

  /// No description provided for @changeServer.
  ///
  /// In en, this message translates to:
  /// **'Change server'**
  String get changeServer;

  /// No description provided for @cueWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Cue workspace'**
  String get cueWorkspace;

  /// No description provided for @focusStreak.
  ///
  /// In en, this message translates to:
  /// **'Focus streak · 12 days'**
  String get focusStreak;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @backToToday.
  ///
  /// In en, this message translates to:
  /// **'Back to Today'**
  String get backToToday;

  /// No description provided for @openBoard.
  ///
  /// In en, this message translates to:
  /// **'Open Board'**
  String get openBoard;

  /// No description provided for @addNotesChecklist.
  ///
  /// In en, this message translates to:
  /// **'+  Add notes or a checklist…'**
  String get addNotesChecklist;

  /// No description provided for @toggleComplete.
  ///
  /// In en, this message translates to:
  /// **'Toggle complete'**
  String get toggleComplete;

  /// No description provided for @createdOn.
  ///
  /// In en, this message translates to:
  /// **'Created {date}'**
  String createdOn(String date);

  /// No description provided for @createdToday.
  ///
  /// In en, this message translates to:
  /// **'today'**
  String get createdToday;

  /// No description provided for @notYet.
  ///
  /// In en, this message translates to:
  /// **'Not yet'**
  String get notYet;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
