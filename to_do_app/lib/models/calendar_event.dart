import 'package:hive/hive.dart';
import 'package:to_do_app/models/sub_task.dart';

/// View-only calendar event imported from Google/Outlook/local calendar.
///
/// Distinct from [Task] because the legacy positional schema differs at
/// index 16: calendar imports store a single eventId String there, whereas
/// regular tasks store a `List<dynamic>` of remote IDs. Mixing them through
/// one adapter caused the eventId to be coerced to `['', '', '']` on every
/// save/load round-trip, breaking dedup and update lookups.
///
/// Schema is 19 positional fields (no notification IDs slot at index 19).
class CalendarEvent {
  String name; // 0
  bool completed; // 1
  String? note; // 2
  String? dueDate; // 3
  String? dueTime; // 4
  String category; // 5
  String priority; // 6
  String? repeatType; // 7
  int reminderAmount; // 8
  String? reminderType; // 9
  bool isStarred; // 10
  String? createdAt; // 11
  String id; // 12  uuid
  List<SubTask> subtasks; // 13
  String calendarId; // 14
  String eventId; // 15
  String remoteEventId; // 16  single String — the key difference from Task
  String source; // 17  google | outlook | local
  String? completedAt; // 18

  CalendarEvent({
    required this.name,
    this.completed = false,
    this.note,
    this.dueDate,
    this.dueTime,
    this.category = 'None',
    this.priority = 'Low',
    this.repeatType,
    this.reminderAmount = 0,
    this.reminderType,
    this.isStarred = false,
    this.createdAt,
    required this.id,
    List<SubTask>? subtasks,
    this.calendarId = '',
    this.eventId = '',
    this.remoteEventId = '',
    this.source = 'local',
    this.completedAt,
  }) : subtasks = subtasks ?? [];

  factory CalendarEvent.fromList(List<dynamic> raw) {
    String? str(int i) =>
        (raw.length > i && raw[i] != null) ? raw[i].toString() : null;

    List<SubTask> readSubs() {
      if (raw.length <= 13 || raw[13] is! List) return [];
      return (raw[13] as List)
          .map((e) => e is SubTask ? e : (e is Map ? SubTask.fromMap(e) : null))
          .whereType<SubTask>()
          .toList();
    }

    return CalendarEvent(
      name: (raw.isNotEmpty ? raw[0] : '') as String? ?? '',
      completed: raw.length > 1 ? (raw[1] == true) : false,
      note: str(2),
      dueDate: str(3),
      dueTime: str(4),
      category: str(5) ?? 'None',
      priority: str(6) ?? 'Low',
      repeatType: str(7),
      reminderAmount:
          raw.length > 8 && raw[8] is num ? (raw[8] as num).toInt() : 0,
      reminderType: str(9),
      isStarred: raw.length > 10 && (raw[10] == 'true' || raw[10] == true),
      createdAt: str(11),
      id: str(12) ?? '',
      subtasks: readSubs(),
      calendarId: str(14) ?? '',
      eventId: str(15) ?? '',
      remoteEventId: str(16) ?? '',
      source: str(17) ?? 'local',
      completedAt: str(18),
    );
  }
}

class CalendarEventAdapter extends TypeAdapter<CalendarEvent> {
  @override
  final int typeId = 2;

  @override
  CalendarEvent read(BinaryReader reader) {
    final fieldCount = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < fieldCount; i++) reader.readByte(): reader.read(),
    };
    return CalendarEvent(
      name: fields[0] as String,
      completed: fields[1] as bool? ?? false,
      note: fields[2] as String?,
      dueDate: fields[3] as String?,
      dueTime: fields[4] as String?,
      category: fields[5] as String? ?? 'None',
      priority: fields[6] as String? ?? 'Low',
      repeatType: fields[7] as String?,
      reminderAmount: fields[8] as int? ?? 0,
      reminderType: fields[9] as String?,
      isStarred: fields[10] as bool? ?? false,
      createdAt: fields[11] as String?,
      id: fields[12] as String,
      subtasks: (fields[13] as List?)?.cast<SubTask>(),
      calendarId: fields[14] as String? ?? '',
      eventId: fields[15] as String? ?? '',
      remoteEventId: fields[16] as String? ?? '',
      source: fields[17] as String? ?? 'local',
      completedAt: fields[18] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, CalendarEvent obj) {
    writer.writeByte(19);
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
      ..write(obj.calendarId)
      ..writeByte(15)
      ..write(obj.eventId)
      ..writeByte(16)
      ..write(obj.remoteEventId)
      ..writeByte(17)
      ..write(obj.source)
      ..writeByte(18)
      ..write(obj.completedAt);
  }
}
