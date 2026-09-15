enum CueTaskStatus { todo, doing, done }

class CueTask {
  const CueTask({
    required this.id,
    required this.title,
    required this.note,
    required this.status,
    required this.priority,
    required this.important,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
    this.dueAt,
    this.completedAt,
    this.deletedAt,
    this.version = 1,
    this.revision = 0,
  });

  final String id;
  final String title;
  final String note;
  final CueTaskStatus status;
  final int priority;
  final bool important;
  final double sortOrder;
  final DateTime? dueAt;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int version;
  final int revision;

  bool get isCompleted => status == CueTaskStatus.done;

  CueTask copyWith({
    String? title,
    String? note,
    CueTaskStatus? status,
    int? priority,
    bool? important,
    double? sortOrder,
    DateTime? dueAt,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
    DateTime? updatedAt,
    int? version,
    int? revision,
  }) {
    return CueTask(
      id: id,
      title: title ?? this.title,
      note: note ?? this.note,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      important: important ?? this.important,
      sortOrder: sortOrder ?? this.sortOrder,
      dueAt: dueAt ?? this.dueAt,
      completedAt: clearCompletedAt ? null : completedAt ?? this.completedAt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: clearDeletedAt ? null : deletedAt ?? this.deletedAt,
      version: version ?? this.version,
      revision: revision ?? this.revision,
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
      status: CueTaskStatus.values.byName(json['status'] as String),
      priority: json['priority'] as int,
      important: json['important'] as bool,
      sortOrder: (json['sortOrder'] as num).toDouble(),
      dueAt: optionalDate('dueAt'),
      completedAt: optionalDate('completedAt'),
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      updatedAt: DateTime.parse(json['updatedAt'] as String).toLocal(),
      deletedAt: optionalDate('deletedAt'),
      version: json['version'] as int,
      revision: json['revision'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toCreateJson() => {
    'title': title,
    'note': note,
    'status': status.name,
    'priority': priority,
    'important': important,
    'sortOrder': sortOrder,
    'dueAt': dueAt?.toUtc().toIso8601String(),
  };
}
