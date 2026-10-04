// lib/services/import_from_ics.dart

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:icalendar_parser/icalendar_parser.dart';
import 'package:flutter/material.dart';
import 'package:to_do_app/models/task.dart';
import 'package:to_do_app/services/notification_service.dart';
import 'package:to_do_app/utils/date_time_utils.dart';
import 'package:uuid/uuid.dart';
import '../data/database.dart';

class ImportFromIcsService {
  static var uuid = Uuid();

  /// Picks an .ics file and parses its events into a list of task maps.
  static Future<List<Map<String, dynamic>>> pickAndParseICS() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['ics'],
    );

    if (result == null || result.files.single.path == null) return [];

    final file = File(result.files.single.path!);
    final content = await file.readAsString();
    final calendar = ICalendar.fromString(content);
    final events = calendar.data.where((e) => e['type'] == 'VEVENT').toList();

    final parsed =
        events.map((event) {
          DateTime? _startDate;
          try {
            _startDate =
                event['DTSTART'] != null
                    ? DateTime.tryParse(
                      event['DTSTART'] is Map
                          ? event['DTSTART']['value'].dt ?? event['DTSTART'].dt
                          : event['DTSTART'].dt,
                    )
                    : event['dtstart'] != null
                    ? DateTime.tryParse(
                      event['dstart'] is Map
                          ? event['dtstart']['value'].dt ?? event['dtstart'].dt
                          : event['dtstart'].dt,
                    )
                    : null;
          } catch (_) {}

          return {
            'taskName':
                event['SUMMARY'] ?? event['summary'] ?? 'Untitled Event',
            'taskNote': event['DESCRIPTION'] ?? event['description'] ?? '',
            'dueDate': _startDate,
            'dueTime': _startDate,
            // 'priority':
            //     priority ?? event['PRIORITY'] ?? event['priority'] ?? 'Medium',
            // 'category': category,
            // 'repeat': repeat,
            // 'remainderAmount': remainderAmount,
            // 'remainderType': remainderType,
            // 'isStarred': isStarred,
            'id': uuid.v4(),
          };
        }).toList();

    return parsed;
  }

  /// Imports a list of parsed tasks into the local database.
  static Future<void> importTasksToDB(
    BuildContext context,
    ToDoDataBase db,
    List<Map<String, dynamic>> parsedTasks,
    String priority,
    String category,
    String repeat,
    int remainderAmount,
    String remainderType,
    bool isStarred,
  ) async {
    final firstNewIndex = db.toDoList.length;
    for (final task in parsedTasks) {
      // final combined = DateTimeUtilsHelper.combineDateAndTime(
      //   task['dueDate'],

      //   task['dueDate'],
      // );
      final utcTime = DateTimeUtilsHelper.toUtcUsingLocal(task["dueDate"]);

      db.toDoList.add(
        Task(
          name: task['taskName'],
          completed: false,
          note: task['taskNote'],
          dueDate: DateTimeUtilsHelper.formatDate(utcTime),
          dueTime: DateTimeUtilsHelper.formatTime(utcTime),
          category: category,
          priority: priority,
          repeatType: repeat,
          reminderAmount: remainderAmount,
          reminderType: remainderType,
          isStarred: isStarred,
          createdAt: DateTime.now().toString(),
          id: task['id'],
          subtasks: [],
          source: "ICS",
          completedAt: "none",
          notificationIds: [],
        ),
      );
      await NotificationService.scheduleInitialRemainderForTask(
        task['id'],
        context,
        {
          'taskName': task['taskName'],
          'dueDate': DateTimeUtilsHelper.formatDate(utcTime), //utc time??
          'dueTime': DateTimeUtilsHelper.formatTime(utcTime),
          'remainderAmount': remainderAmount,
          'remainderType': remainderType,
          'taskPriority': priority,
        },
        db,
        db.toDoList.length - 1,
      );
    }

    await db.saveTasksFrom(firstNewIndex);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${parsedTasks.length} tasks imported successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    }
  }
}
