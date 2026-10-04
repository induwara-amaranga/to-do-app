import 'dart:io';

import 'package:to_do_app/data/file_database_repository.dart';
import 'package:to_do_app/models/sorting_mode.dart';
import 'package:path/path.dart' as p;

FileRepository _fileRepository = FileRepository();

FileRepository get fileRepository => _fileRepository;

class FileSortService {
  static List<File> sort(SortingMode mode, List<File> files) {
    switch (mode) {
      case SortingMode.aToz:
        return sortFilesByNameAsc(files);
      case SortingMode.zToa:
        return sortFilesByNameDesc(files);
      case SortingMode.createdDateIncreasing:
        return sortFilesByModifiedDateAsc(files);
      case SortingMode.createdDateDecreasing:
        return sortFilesByModifiedDateDesc(files);
      case SortingMode.starredFirst:
        final starredFilePaths = _fileRepository.getAllStarredFilePaths();
        return sortFilesByStarredFirst(files, starredFilePaths.toSet());
      case SortingMode.nonStarredFirst:
        final starredFilePaths = _fileRepository.getAllStarredFilePaths();
        return FileSortService().sortFilesByNonStarredFirst(
          files,
          starredFilePaths.toSet(),
        );
      default:
        return files;
    }
  }

  static List<File> sortFilesByModifiedDateDesc(List<File> files) {
    files.sort((a, b) {
      final aModified = a.lastModifiedSync();
      final bModified = b.lastModifiedSync();
      return bModified.compareTo(aModified);
    });
    return files;
  }

  static List<File> sortFilesByModifiedDateAsc(List<File> files) {
    files.sort((a, b) {
      final aModified = a.lastModifiedSync();
      final bModified = b.lastModifiedSync();
      return aModified.compareTo(bModified);
    });
    return files;
  }

  static List<File> sortFilesByNameAsc(List<File> files) {
    files.sort((a, b) {
      // Compare the file names (case-insensitive)
      return p
          .basename(a.path)
          .toLowerCase()
          .compareTo(p.basename(b.path).toLowerCase());
    });
    return files;
  }

  static List<File> sortFilesByNameDesc(List<File> files) {
    files.sort((a, b) {
      // Compare the file names (case-insensitive)
      return p
          .basename(b.path)
          .toLowerCase()
          .compareTo(p.basename(a.path).toLowerCase());
    });
    return files;
  }

  static List<File> sortFilesByStarredFirst(
    List<File> files,
    Set<String> starredFilePaths,
  ) {
    files.sort((a, b) {
      final aStarred = starredFilePaths.contains(a.path);
      final bStarred = starredFilePaths.contains(b.path);
      if (aStarred && !bStarred) {
        return -1; // a comes before b
      } else if (!aStarred && bStarred) {
        return 1; // b comes before a
      } else {
        return 0; // maintain original order
      }
    });
    return files;
  }

  List<File> sortFilesByNonStarredFirst(
    List<File> files,
    Set<String> starredFilePaths,
  ) {
    files.sort((a, b) {
      final aStarred = starredFilePaths.contains(a.path);
      final bStarred = starredFilePaths.contains(b.path);
      if (!aStarred && bStarred) {
        return -1; // a comes before b
      } else if (aStarred && !bStarred) {
        return 1; // b comes before a
      } else {
        return 0; // maintain original order
      }
    });
    return files;
  }
}
