class CueTask {
  const CueTask({
    required this.id,
    required this.title,
    required this.note,
    required this.priority,
    required this.important,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
    this.dueAt,
    this.reminder,
    this.recurrence,
    this.completedAt,
    this.deletedAt,
    this.version = 1,
    this.revision = 0,
    this.group,
  });

  final String id;
  final String title;
  final String note;
  final int priority;
  final bool important;
  final double sortOrder;
  final DateTime? dueAt;
  final String? reminder;
  final String? recurrence;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int version;
  final int revision;
  final String? group;

  bool get isCompleted => completedAt != null;

  CueTask copyWith({
    String? title,
    String? note,
    int? priority,
    bool? important,
    double? sortOrder,
    DateTime? dueAt,
    bool clearDueAt = false,
    String? reminder,
    bool clearReminder = false,
    String? recurrence,
    bool clearRecurrence = false,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
    DateTime? updatedAt,
    int? version,
    int? revision,
    String? group,
    bool clearGroup = false,
  }) {
    return CueTask(
      id: id,
      title: title ?? this.title,
      note: note ?? this.note,
      priority: priority ?? this.priority,
      important: important ?? this.important,
      sortOrder: sortOrder ?? this.sortOrder,
      dueAt: clearDueAt ? null : dueAt ?? this.dueAt,
      reminder: clearReminder ? null : reminder ?? this.reminder,
      recurrence: clearRecurrence ? null : recurrence ?? this.recurrence,
      completedAt: clearCompletedAt ? null : completedAt ?? this.completedAt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: clearDeletedAt ? null : deletedAt ?? this.deletedAt,
      version: version ?? this.version,
      revision: revision ?? this.revision,
      group: clearGroup ? null : group ?? this.group,
    );
  }

  factory CueTask.fromJson(Map<String, dynamic> json) {
    DateTime? optionalDate(String key) {
      final value = json[key] as String?;
      return value == null ? null : DateTime.parse(value).toLocal();
    }

    return CueTask(
      id: json['id'] as String,
      title: json['title'] as String,
      note: json['note'] as String? ?? '',
      priority: json['priority'] as int,
      important: json['important'] as bool,
      sortOrder: (json['sortOrder'] as num).toDouble(),
      dueAt: optionalDate('dueAt'),
      reminder: json['reminder'] as String?,
      recurrence: json['recurrence'] as String?,
      completedAt: optionalDate('completedAt'),
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      updatedAt: DateTime.parse(json['updatedAt'] as String).toLocal(),
      deletedAt: optionalDate('deletedAt'),
      version: json['version'] as int,
      revision: json['revision'] as int? ?? 0,
      group: json['group'] as String?,
    );
  }

  Map<String, dynamic> toCreateJson() => {
    'title': title,
    'note': note,
    'priority': priority,
    'important': important,
    'sortOrder': sortOrder,
    'dueAt': dueAt?.toUtc().toIso8601String(),
    'reminder': reminder,
    'recurrence': recurrence,
    'group': group,
  };
}
