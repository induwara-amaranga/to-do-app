import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:to_do_app/utils/log.dart';

import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:to_do_app/data/file_database_repository.dart';
import 'package:share_plus/share_plus.dart';
//import 'package:share_plus/share_plus.dart';

FileRepository _fileRepository = FileRepository();

class FileStorageService {
  static List<String> allowedExtensions = [
    'pdf',
    'png',
    'jpg',
    'jpeg',
    'webp',
    'doc',
    'docx',
    'xls',
    'xlsx',
    'txt',
  ];
  static Future<File> saveFile(Uint8List bytes, String filename) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$filename');
    await _fileRepository.saveFileMetaData(file.path, {"isStarred": false});
    return file.writeAsBytes(bytes);
  }

  /// Renames **only the file name** while keeping the same directory
  static Future<File> renameOnlyFileName(
    String filePath,
    String newFileName,
  ) async {
    final file = File(filePath);

    if (!await file.exists()) {
      logd("File not found: $filePath");
      throw Exception("File not found: $filePath");
    }

    final dir = p.dirname(filePath);
    final newPath = p.join(dir, newFileName);

    try {
      await _fileRepository.changeFilePath(filePath, newPath);
      return await file.rename(newPath);
    } on FileSystemException {
      // fallback: copy → delete
      final newFile = await file.copy(newPath);
      await file.delete();
      await _fileRepository.changeFilePath(filePath, newPath);
      return newFile;
    }
  }

  static Future<void> shareFile(String path) async {
    final file = XFile(path);

    final result = await SharePlus.instance.share(
      ShareParams(files: [file], text: "Check this file!"),
    );

    logd(result.status); // success / dismissed / unavailable
  }

  static void deleteFile(File file) async {
    await file.delete();
    await _fileRepository.deleteFileMetaData(file.path);
    //setState(() {}); // refresh grid
  }

  static Future<void> openFile(File file) async {
    final result = await OpenFile.open(file.path);

    // Optional: handle result
    if (result.type == ResultType.done) {
      logd("File opened successfully");
    } else {
      logd("Error opening file: ${result.message}");
    }
  }

  // static Future<void> shareFile(File file) async {
  //   try {
  //     final result = await SharePlus.instance.share(
  //       ShareParams(files: [XFile(file.path)]),
  //     );

  //     // (Optional) Handle result
  //     if (result.status == ShareResultStatus.success) {
  //       logd("File shared successfully!");
  //     }
  //   } catch (e) {
  //     logd("Error sharing file: $e");
  //   }
  // }

  static Future<List<File>?> pickTimetableFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
      allowMultiple: true, // <-- Enable multiple selection
    );

    if (result != null && result.files.isNotEmpty) {
      return result.files.map((f) => File(f.path!)).toList();
    }

    return null; // User canceled
  }

  static Future<List<File>> listTimetables() async {
    final dir = await getApplicationDocumentsDirectory();
    List<FileSystemEntity> fileEntities = dir.listSync();
    List<File> files = fileEntities.whereType<File>().toList();

    return files.where((f) {
      final name = f.path.toLowerCase();
      return allowedExtensions.any((ext) => name.endsWith(".$ext"));
    }).toList();
  }
}
