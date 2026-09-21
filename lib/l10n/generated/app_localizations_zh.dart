// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Cue — 给任务一个 Cue';

  @override
  String get tagline => '给任务一个 Cue';

  @override
  String get language => '语言';

  @override
  String get systemDefault => '跟随系统';

  @override
  String get chinese => '中文';

  @override
  String get english => 'English';

  @override
  String get back => '返回';

  @override
  String get change => '更改';

  @override
  String get save => '保存';

  @override
  String get moreOptions => '更多操作';

  @override
  String get email => '邮箱';

  @override
  String get password => '密码';

  @override
  String get enterValidEmail => '请输入有效的邮箱地址';

  @override
  String get passwordMinLength => '密码至少需要 8 个字符';

  @override
  String get showPassword => '显示密码';

  @override
  String get hidePassword => '隐藏密码';

  @override
  String get signIn => '登录';

  @override
  String get singleAdministrator => '此工作区仅有一个管理员账户。';

  @override
  String get connectToCue => '连接到 Cue';

  @override
  String get enterServerAddress => '输入你的 Cue 服务器地址';

  @override
  String get serverUrl => '服务器地址';

  @override
  String get serverUrlRequired => '请输入服务器地址';

  @override
  String get serverUrlSchemeRequired => '请以 http:// 或 https:// 开头';

  @override
  String get serverUrlInvalid => '请输入有效的服务器地址';

  @override
  String get serverUnreachable => '无法连接服务器，请检查地址。';

  @override
  String get serverIncompatible => '这不是 Cue 服务器。';

  @override
  String get serverVerificationFailed => '无法验证服务器，请重试。';

  @override
  String get serverUrlHelp => '以 http:// 或 https:// 开头，/api 可省略。';

  @override
  String get connect => '连接';

  @override
  String get serverVerificationHelp => '登录前会先验证服务器，你可以稍后在设置中更改。';

  @override
  String get inbox => '收集箱';

  @override
  String get today => '今天';

  @override
  String get tomorrow => '明天';

  @override
  String get later => '稍后';

  @override
  String get upcoming => '即将到来';

  @override
  String get list => '列表';

  @override
  String get allTasks => '所有任务';

  @override
  String get board => '看板';

  @override
  String get calendar => '日历';

  @override
  String get quadrants => '四象限';

  @override
  String get settings => '设置';

  @override
  String get addTask => '添加任务';

  @override
  String openTaskCount(int count) {
    return '$count 个未完成任务';
  }

  @override
  String taskCount(int count) {
    return '$count 个任务';
  }

  @override
  String get planWhatComesNext => '规划接下来的事项';

  @override
  String get oneTaskModel => '一个任务模型，汇集所有未完成事项';

  @override
  String get monthViewDueOnly => '月视图 · 仅显示截止日期';

  @override
  String get importanceUrgencyTwoDays => '优先级四象限 · 每个象限对应一个优先级';

  @override
  String get taskAddedToday => '任务已添加到今天';

  @override
  String get newTask => '新建任务';

  @override
  String get taskTitle => '任务标题';

  @override
  String get taskTitleHint => '接下来需要推进什么？';

  @override
  String get note => '备注';

  @override
  String get notes => '备注';

  @override
  String get priority => '优先级';

  @override
  String get status => '状态';

  @override
  String get due => '截止';

  @override
  String get dueDate => '截止日期';

  @override
  String get important => '重要';

  @override
  String get quadrantUsage => '用于四象限视图';

  @override
  String get quadrantControl => '决定任务所在的象限';

  @override
  String get showInPriorityQuadrants => '显示在优先级四象限中';

  @override
  String get cancel => '取消';

  @override
  String get close => '关闭';

  @override
  String get deleteTask => '删除任务';

  @override
  String get deleteTaskQuestion => '删除任务？';

  @override
  String deleteTaskExplanation(String title) {
    return '“$title”将从所有视图中移除。服务器会保留同步删除标记，以便其他会话应用这次删除。';
  }

  @override
  String get delete => '删除';

  @override
  String get noDueDate => '无截止日期';

  @override
  String get noTime => '无时间';

  @override
  String get dueToday => '今天截止';

  @override
  String get dueTomorrow => '明天截止';

  @override
  String dueOn(String date) {
    return '$date 截止';
  }

  @override
  String completedAt(String time) {
    return '已于 $time 完成';
  }

  @override
  String get hardware => '硬件';

  @override
  String get simulation => '仿真';

  @override
  String get writing => '写作';

  @override
  String get operations => '运营';

  @override
  String get product => '产品';

  @override
  String get personal => '个人';

  @override
  String get synced => '已同步';

  @override
  String userSynced(String email) {
    return '$email · 已同步';
  }

  @override
  String get signOut => '退出登录';

  @override
  String get focusForToday => '专注今天';

  @override
  String openTasksLabel(int count) {
    return '未完成 · $count';
  }

  @override
  String comingUpLabel(int count) {
    return '即将到来 · $count';
  }

  @override
  String allTasksLabel(int count) {
    return '所有任务 · $count';
  }

  @override
  String tasksLabel(int count) {
    return '任务 · $count';
  }

  @override
  String get completed => '已完成';

  @override
  String get quickAddHint => '添加任务… 例如“明天 10:30 评审 PCB”';

  @override
  String get add => '添加';

  @override
  String get emptyList => '这里空空如也，享受片刻清闲吧。';

  @override
  String get groupPriority => '优先级';

  @override
  String get groupDueDate => '截止日期';

  @override
  String get dragCards => '拖动卡片可调整分组';

  @override
  String get groupingPreview => '任务分组';

  @override
  String get month => '月';

  @override
  String get dueOnly => '仅看截止';

  @override
  String scheduledSummary(int scheduled, int due) {
    return '已安排 $scheduled 项 · 本周到期 $due 项';
  }

  @override
  String get allTasksFilter => '所有任务';

  @override
  String get importantFilter => '重要';

  @override
  String get dueSoon => '即将到期';

  @override
  String get urgentDefinition => '仅 P0 为重要任务';

  @override
  String get doNow => '立即处理';

  @override
  String get doNowRule => 'P0 · 重要';

  @override
  String get schedule => '安排时间';

  @override
  String get scheduleRule => 'P1';

  @override
  String get batch => '批量处理';

  @override
  String get batchRule => 'P2';

  @override
  String get reconsider => '重新考虑';

  @override
  String get reconsiderRule => 'P3';

  @override
  String get noMatchingTasks => '没有匹配的任务';

  @override
  String get closeTaskDetails => '关闭任务详情';

  @override
  String get morning => '上午';

  @override
  String get laterUpper => '稍后';

  @override
  String get upcomingUpper => '即将到来';

  @override
  String get priorityUpper => '优先级';

  @override
  String get allClear => '全部完成';

  @override
  String monthOverview(int year) {
    return '$year 年 · 月度概览';
  }

  @override
  String get nextUp => '接下来';

  @override
  String get nothingScheduled => '没有已安排的任务';

  @override
  String get importantUrgent => 'P0 · 重要';

  @override
  String get importantLater => 'P1';

  @override
  String get urgentLowerValue => 'P2';

  @override
  String get neither => 'P3';

  @override
  String get importanceUrgency => '每个象限对应一个优先级';

  @override
  String get localDemo => '本地演示';

  @override
  String get syncing => '同步中…';

  @override
  String get needsAttention => '需要处理';

  @override
  String get connected => '已连接';

  @override
  String get personalizeCue => '让 Cue 更适合你的工作方式';

  @override
  String get preferences => '偏好设置';

  @override
  String get appearance => '外观';

  @override
  String get dark => '深色';

  @override
  String get light => '浅色';

  @override
  String get dateAndTime => '日期与时间';

  @override
  String get system => '系统';

  @override
  String get reminders => '提醒';

  @override
  String get minutesBefore => '提前 15 分钟';

  @override
  String get widgets => '小组件';

  @override
  String get activeWidgetCount => '2 个启用';

  @override
  String get aiFeatures => 'AI 功能';

  @override
  String get on => '开启';

  @override
  String get accountAndData => '账户与数据';

  @override
  String get importAndSync => '导入与同步';

  @override
  String get helpAndGuide => '帮助与指南';

  @override
  String get multiDeviceSync => '多设备同步';

  @override
  String get syncDescription =>
      '更改会同步到移动端、网页端和桌面端的同一个 Cue 工作区。连接时自动接收更新，应用恢复时也会同步。';

  @override
  String get revision => '版本';

  @override
  String get lastSynced => '上次同步';

  @override
  String get server => '服务器';

  @override
  String get syncNow => '立即同步';

  @override
  String get changeServer => '更改服务器';

  @override
  String get cueWorkspace => 'Cue 工作区';

  @override
  String get focusStreak => '已连续专注 12 天';

  @override
  String get more => '更多';

  @override
  String get backToToday => '返回今天';

  @override
  String get openBoard => '打开看板';

  @override
  String get addNotesChecklist => '+  添加备注或检查清单…';

  @override
  String get toggleComplete => '切换完成状态';

  @override
  String createdOn(String date) {
    return '创建于 $date';
  }

  @override
  String get createdToday => '今天';

  @override
  String get notYet => '尚未';

  @override
  String get group => '分组';

  @override
  String get addGroup => '添加分组';

  @override
  String get renameGroup => '重命名分组';

  @override
  String get deleteGroup => '删除分组';

  @override
  String get ungrouped => '未分组';

  @override
  String get groupSection => '按分组';

  @override
  String get groupPriorityNone => '无优先级';

  @override
  String get groupPriorityHigh => '高优先级';

  @override
  String get groupPriorityMedium => '中优先级';

  @override
  String get groupPriorityLow => '低优先级';

  @override
  String get enterGroupName => '输入分组名称';

  @override
  String get seeMore => '查看更多';
}
