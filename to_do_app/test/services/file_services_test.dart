import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:to_do_app/data/file_database_repository.dart';
import 'package:to_do_app/models/sorting_mode.dart';
import 'package:to_do_app/services/file_sort_service.dart';
import 'package:to_do_app/services/file_storage_service.dart';

String base(File f) => f.uri.pathSegments.last;

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('todo_files_');
    Hive.init(dir.path);
    await Hive.openBox('fileMetaBox');
  });
  tearDown(() async {
    await Hive.close();
    try {
      await dir.delete(recursive: true);
    } catch (_) {}
  });

  File make(String name, {DateTime? modified}) {
    final f = File('${dir.path}/$name')..writeAsStringSync(name);
    if (modified != null) f.setLastModifiedSync(modified);
    return f;
  }

  group('FileRepository (starred files)', () {
    test('a file is not starred by default', () {
      final repo = FileRepository();
      expect(repo.isStarred('${dir.path}/none.pdf'), isFalse);
      expect(repo.getFileMetaData('${dir.path}/none.pdf'), isNull);
    });

    test('toggleStar flips the flag on and off', () async {
      final repo = FileRepository();
      final path = '${dir.path}/a.pdf';
      await repo.toggleStar(path);
      expect(repo.isStarred(path), isTrue);
      await repo.toggleStar(path);
      expect(repo.isStarred(path), isFalse);
    });

    test('getAllStarredFilePaths lists only starred files', () async {
      final repo = FileRepository();
      final a = '${dir.path}/a.pdf';
      final b = '${dir.path}/b.pdf';
      await repo.saveFileMetaData(a, {'isStarred': true});
      await repo.saveFileMetaData(b, {'isStarred': false});
      expect(repo.getAllStarredFilePaths(), contains(a));
      expect(repo.getAllStarredFilePaths(), isNot(contains(b)));
    });

    test('changeFilePath moves the metadata to the new path', () async {
      final repo = FileRepository();
      final oldPath = '${dir.path}/old.pdf';
      final newPath = '${dir.path}/new.pdf';
      await repo.saveFileMetaData(oldPath, {'isStarred': true});
      await repo.changeFilePath(oldPath, newPath);
      expect(repo.isStarred(newPath), isTrue);
      expect(repo.getFileMetaData(oldPath), isNull);
    });

    test('changeFilePath on an unknown file does nothing', () async {
      final repo = FileRepository();
      await repo.changeFilePath('${dir.path}/ghost', '${dir.path}/ghost2');
      expect(repo.getFileMetaData('${dir.path}/ghost2'), isNull);
    });

    test('deleteFileMetaData forgets the file', () async {
      final repo = FileRepository();
      final path = '${dir.path}/gone.pdf';
      await repo.saveFileMetaData(path, {'isStarred': true});
      await repo.deleteFileMetaData(path);
      expect(repo.isStarred(path), isFalse);
    });

    test('metadata survives being reloaded from the box', () async {
      final repo = FileRepository();
      final path = '${dir.path}/persist.pdf';
      await repo.toggleStar(path);
      final reloaded = FileRepository(); // reloads from Hive
      expect(reloaded.isStarred(path), isTrue);
    });
  });

  group('FileSortService', () {
    test('by name ascending is case-insensitive', () {
      final files = [make('b.txt'), make('A.txt'), make('c.txt')];
      expect(FileSortService.sort(SortingMode.aToz, files).map(base), [
        'A.txt',
        'b.txt',
        'c.txt',
      ]);
    });

    test('by name descending', () {
      final files = [make('b.txt'), make('A.txt'), make('c.txt')];
      expect(FileSortService.sort(SortingMode.zToa, files).map(base), [
        'c.txt',
        'b.txt',
        'A.txt',
      ]);
    });

    test('by modified date, oldest first and newest first', () {
      final old = make('old.txt', modified: DateTime(2020, 1, 1));
      final mid = make('mid.txt', modified: DateTime(2022, 1, 1));
      final fresh = make('new.txt', modified: DateTime(2024, 1, 1));
      expect(
        FileSortService.sort(SortingMode.createdDateIncreasing, [
          fresh,
          old,
          mid,
        ]).map(base),
        ['old.txt', 'mid.txt', 'new.txt'],
      );
      expect(
        FileSortService.sort(SortingMode.createdDateDecreasing, [
          old,
          fresh,
          mid,
        ]).map(base),
        ['new.txt', 'mid.txt', 'old.txt'],
      );
    });

    test('starred first / non-starred first', () async {
      final a = make('a.txt');
      final b = make('b.txt');
      final c = make('c.txt');
      await FileRepository().saveFileMetaData(b.path, {'isStarred': true});

      expect(
        FileSortService.sort(SortingMode.starredFirst, [a, b, c]).map(base),
        ['b.txt', 'a.txt', 'c.txt'],
      );
      expect(
        FileSortService.sort(SortingMode.nonStarredFirst, [b, a, c]).map(base),
        ['a.txt', 'c.txt', 'b.txt'],
      );
    });

    test('other modes leave the order untouched', () {
      final files = [make('z.txt'), make('a.txt')];
      expect(FileSortService.sort(SortingMode.manual, files).map(base), [
        'z.txt',
        'a.txt',
      ]);
    });

    test('empty list', () {
      expect(FileSortService.sort(SortingMode.aToz, []), isEmpty);
    });
  });

  group('FileStorageService', () {
    test('allowed extensions cover documents and images', () {
      expect(
        FileStorageService.allowedExtensions,
        containsAll(['pdf', 'png', 'jpg', 'docx', 'xlsx', 'txt']),
      );
    });

    test('renameOnlyFileName keeps the folder and moves metadata', () async {
      final file = make('before.txt');
      await FileRepository().saveFileMetaData(file.path, {'isStarred': true});

      final renamed = await FileStorageService.renameOnlyFileName(
        file.path,
        'after.txt',
      );

      expect(base(renamed), 'after.txt');
      expect(renamed.parent.path, file.parent.path);
      expect(await file.exists(), isFalse);
      expect(await renamed.exists(), isTrue);
      expect(FileRepository().isStarred(renamed.path), isTrue);
    });

    test('renameOnlyFileName throws for a missing file', () async {
      expect(
        () => FileStorageService.renameOnlyFileName(
          '${dir.path}/missing.txt',
          'x.txt',
        ),
        throwsException,
      );
    });
  });
}
