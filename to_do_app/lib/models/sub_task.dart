import 'package:hive/hive.dart';

class SubTask {
  String name;
  String? dueDate;
  String? dueTime;
  bool completed;

  SubTask({
    required this.name,
    this.dueDate,
    this.dueTime,
    this.completed = false,
  });

  Map<String, dynamic> toMap() => {
    'name': name,
    'dueDate': dueDate,
    'dueTime': dueTime,
    'completed': completed,
  };

  factory SubTask.fromMap(Map map) => SubTask(
    name: (map['name'] ?? '') as String,
    dueDate: map['dueDate'] as String?,
    dueTime: map['dueTime'] as String?,
    completed: (map['completed'] ?? false) as bool,
  );
}

class SubTaskAdapter extends TypeAdapter<SubTask> {
  @override
  final int typeId = 1;

  @override
  SubTask read(BinaryReader reader) {
    return SubTask(
      name: reader.readString(),
      dueDate: reader.readBool() ? reader.readString() : null,
      dueTime: reader.readBool() ? reader.readString() : null,
      completed: reader.readBool(),
    );
  }

  @override
  void write(BinaryWriter writer, SubTask obj) {
    writer.writeString(obj.name);
    writer.writeBool(obj.dueDate != null);
    if (obj.dueDate != null) writer.writeString(obj.dueDate!);
    writer.writeBool(obj.dueTime != null);
    if (obj.dueTime != null) writer.writeString(obj.dueTime!);
    writer.writeBool(obj.completed);
  }
}
