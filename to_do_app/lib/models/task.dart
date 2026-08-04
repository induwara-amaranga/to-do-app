import 'package:hive/hive.dart';
import 'package:to_do_app/models/sub_task.dart';

/// Typed task model used for disk storage via Hive TypeAdapter.
/// Index mapping mirrors the legacy `List<dynamic>` schema so
/// `Task.fromList(legacyList)` can migrate data from the old `mybox`
/// positional format.
class Task {
  String name; // 0
  bool completed; // 1
  String? note; // 2
  String? dueDate; // 3  yyyy-MM-dd UTC
  String? dueTime; // 4  HH:mm UTC
  String category; // 5
  String priority; // 6  Low | Medium | High
  String? repeatType; // 7  none | daily | weekly | monthly | yearly
  int reminderAmount; // 8
  String? reminderType; // 9  minutes | hours | days | weeks | none
  bool isStarred; // 10  (legacy stored as String "true"/"false")
  String? createdAt; // 11  UTC ISO
  String id; // 12  uuid
  List<SubTask> subtasks; // 13
  String localCalendarId; // 14
  String localEventId; // 15
  List<dynamic>
  remoteEventIds; // 16  e.g. ["calId", "googleEventId", "outlookEventId"]
  String source; // 17  manual | google | outlook | local
  String? completedAt; // 18  UTC ISO or "none"
  List<int> notificationIds; // 19

  Task({
    required this.name,
    this.completed = false,
    this.note,
    this.dueDate,
    this.dueTime,
    this.category = 'None',
    this.priority = 'Medium',
    this.repeatType,
    this.reminderAmount = 0,
    this.reminderType,
    this.isStarred = false,
    this.createdAt,
    required this.id,
    List<SubTask>? subtasks,
    this.localCalendarId = '',
    this.localEventId = '',
    List<dynamic>? remoteEventIds,
    this.source = 'manual',
    this.completedAt,
    List<int>? notificationIds,
  }) : subtasks = subtasks ?? [],
       remoteEventIds = remoteEventIds ?? const ['', '', ''],
       notificationIds = notificationIds ?? [];

  factory Task.fromList(List<dynamic> raw) {
    String? str(int i) =>
        (raw.length > i && raw[i] != null) ? raw[i].toString() : null;

    List<SubTask> readSubs() {
      if (raw.length <= 13 || raw[13] is! List) return [];
      return (raw[13] as List)
          .map((e) => e is SubTask ? e : (e is Map ? SubTask.fromMap(e) : null))
          .whereType<SubTask>()
          .toList();
    }

    return Task(
      name: (raw.isNotEmpty ? raw[0] : '') as String? ?? '',
      completed: raw.length > 1 ? (raw[1] == true) : false,
      note: str(2),
      dueDate: str(3),
      dueTime: str(4),
      category: str(5) ?? 'None',
      priority: str(6) ?? 'Medium',
      repeatType: str(7),
      reminderAmount:
          raw.length > 8 && raw[8] is num ? (raw[8] as num).toInt() : 0,
      reminderType: str(9),
      isStarred: raw.length > 10 && (raw[10] == 'true' || raw[10] == true),
      createdAt: str(11),
      id: str(12) ?? '',
      subtasks: readSubs(),
      localCalendarId: str(14) ?? '',
      localEventId: str(15) ?? '',
      remoteEventIds:
          raw.length > 16 && raw[16] is List
              ? List<dynamic>.from(raw[16] as List)
              : const ['', '', ''],
      source: str(17) ?? 'manual',
      completedAt: str(18),
      notificationIds:
          raw.length > 19 && raw[19] is List
              ? (raw[19] as List)
                  .whereType<num>()
                  .map((n) => n.toInt())
                  .toList()
              : <int>[],
    );
  }
}

class TaskAdapter extends TypeAdapter<Task> {
  @override
  final int typeId = 0;

  @override
  Task read(BinaryReader reader) {
    final fieldCount = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < fieldCount; i++) reader.readByte(): reader.read(),
    };
    return Task(
      name: fields[0] as String,
      completed: fields[1] as bool? ?? false,
      note: fields[2] as String?,
      dueDate: fields[3] as String?,
      dueTime: fields[4] as String?,
      category: fields[5] as String? ?? 'None',
      priority: fields[6] as String? ?? 'Medium',
      repeatType: fields[7] as String?,
      reminderAmount: fields[8] as int? ?? 0,
      reminderType: fields[9] as String?,
      isStarred: fields[10] as bool? ?? false,
      createdAt: fields[11] as String?,
      id: fields[12] as String,
      subtasks: (fields[13] as List?)?.cast<SubTask>(),
      localCalendarId: fields[14] as String? ?? '',
      localEventId: fields[15] as String? ?? '',
      remoteEventIds: (fields[16] as List?)?.cast<dynamic>(),
      source: fields[17] as String? ?? 'manual',
      completedAt: fields[18] as String?,
      notificationIds: (fields[19] as List?)?.whereType<int>().toList(),
    );
  }

  @override
  void write(BinaryWriter writer, Task obj) {
    writer.writeByte(20);
    writer
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.completed)
      ..writeByte(2)
      ..write(obj.note)
      ..writeByte(3)
      ..write(obj.dueDate)
      ..writeByte(4)
      ..write(obj.dueTime)
      ..writeByte(5)
      ..write(obj.category)
      ..writeByte(6)
      ..write(obj.priority)
      ..writeByte(7)
      ..write(obj.repeatType)
      ..writeByte(8)
      ..write(obj.reminderAmount)
      ..writeByte(9)
      ..write(obj.reminderType)
      ..writeByte(10)
      ..write(obj.isStarred)
      ..writeByte(11)
      ..write(obj.createdAt)
      ..writeByte(12)
      ..write(obj.id)
      ..writeByte(13)
      ..write(obj.subtasks)
      ..writeByte(14)
      ..write(obj.localCalendarId)
      ..writeByte(15)
      ..write(obj.localEventId)
      ..writeByte(16)
      ..write(obj.remoteEventIds)
      ..writeByte(17)
      ..write(obj.source)
      ..writeByte(18)
      ..write(obj.completedAt)
      ..writeByte(19)
      ..write(obj.notificationIds);
  }
}
