import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:to_do_app/components/list_view_time_table_tile.dart';
import 'package:to_do_app/components/pick_timetable_dialog.dart';
import 'package:to_do_app/components/search_bar.dart' as sb;
import 'package:to_do_app/components/tile_view_time_table_tile.dart';
import 'package:to_do_app/data/file_database_repository.dart';
import 'package:to_do_app/models/sorting_mode.dart';
import 'package:to_do_app/providers/file_search_provider.dart';
import 'package:to_do_app/providers/file_sort_provider.dart';
import 'package:to_do_app/providers/sorting_provider.dart';
import 'package:to_do_app/providers/view_provider.dart';
import 'package:to_do_app/services/file_sort_service.dart';
import 'package:to_do_app/services/file_storage_service.dart';

class SavedTimetablesPage extends StatefulWidget {
  const SavedTimetablesPage({super.key});

  @override
  State<SavedTimetablesPage> createState() => _SavedTimetablesPageState();
}

class _SavedTimetablesPageState extends State<SavedTimetablesPage> {
  FileRepository _fileRepository = FileRepository();
  FileRepository get fileRepository => _fileRepository;
  List<File> savedFiles = [];
  List<File> viewingFiles = [];
  String query = "";
  String view = "tileView";
  SortingMode sorting = SortingMode.createdDateDecreasing;
  @override
  initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final files = await FileStorageService.listTimetables();

      setState(() {
        savedFiles.clear();
        savedFiles.addAll(files);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    query = context.watch<FileSearchProvider>().searchQuery;
    sorting = context.watch<FileSortProvider>().sortingMode;
    view = context.watch<ViewProvider>().currentView;
    viewingFiles = List.from(
      savedFiles
          .where(
            (file) => file.path
                .split("/")
                .last
                .toLowerCase()
                .contains(query.toLowerCase()),
          )
          .toList(),
    );
    viewingFiles = FileSortService.sort(sorting, viewingFiles);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '   Saved Timetables ',
          style: TextStyle(
            fontFamily: 'Manrope',
            fontWeight: FontWeight.w900,
            fontSize: 20,
            letterSpacing: -0.4,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            itemBuilder:
                (context) => <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    //value: 'Sort',
                    child: PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [Text("Sort by"), Icon(Icons.chevron_right)],
                      ),
                      onSelected: (subValue) {
                        final sortingProvider =
                            context.read<FileSortProvider>();

                        switch (subValue) {
                          case "aToz":
                            sortingProvider.setSortingMode(SortingMode.aToz);
                            break;
                          case "zToa":
                            sortingProvider.setSortingMode(SortingMode.zToa);
                            break;
                          case "createdDateIncreasing":
                            sortingProvider.setSortingMode(
                              SortingMode.createdDateIncreasing,
                            );
                            break;
                          case "createdDateDecreasing":
                            sortingProvider.setSortingMode(
                              SortingMode.createdDateDecreasing,
                            );
                            break;

                          case "starredFirst":
                            sortingProvider.setSortingMode(
                              SortingMode.starredFirst,
                            );
                            break;
                          case "nonStarredFirst":
                            sortingProvider.setSortingMode(
                              SortingMode.nonStarredFirst,
                            );
                        }
                      },

                      itemBuilder:
                          (context) =>
                              [
                                SortingMode.aToz,
                                SortingMode.zToa,
                                SortingMode.createdDateDecreasing,
                                SortingMode.createdDateIncreasing,
                                SortingMode.nonStarredFirst,
                                SortingMode.starredFirst,
                              ].map((mode) {
                                return PopupMenuItem<String>(
                                  value: mode.toString().split('.').last,
                                  child: Text(
                                    mode.displayName,
                                  ), // Shows just the enum name
                                );
                              }).toList(),
                    ),
                  ),
                  PopupMenuItem<String>(
                    child: PopupMenuButton<String>(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [Text("View"), Icon(Icons.chevron_right)],
                      ),
                      onSelected: (subValue) {
                        final viewProvider = context.read<ViewProvider>();
                        //if(subValue=="view")
                        //viewProvider.setView("view");

                        switch (subValue) {
                          case "listView":
                            viewProvider.setView("listView");
                            break;
                          case "tilesView":
                            viewProvider.setView("tileView");
                            break;
                        }
                        //setState(() {});
                      },
                      itemBuilder:
                          (context) => <PopupMenuEntry<String>>[
                            PopupMenuItem<String>(
                              //value: 'Refresh',
                              child: Text("List View"),
                              value: "listView",
                            ),
                            PopupMenuItem<String>(
                              child: Text("Tiles View"),
                              value: "tilesView",
                            ),
                          ],
                    ),
                  ),
                ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        shape: CircleBorder(),
        onPressed: () async {
          await showPickFileDialog(context);
          // Action to add a new timetable
        },
        child: Icon(Icons.add),
      ),
      body: Column(
        children: [
          SizedBox(height: 16),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Container(
                decoration: BoxDecoration(
                  //color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.5),
                      spreadRadius: 2,
                      blurRadius: 5,
                      offset: Offset(0, 3), // changes position of shadow
                    ),
                  ],
                ),
                child: sb.SearchBar(searchType: "timetable"),
              ),
            ),
          ),
          SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: viewingFiles.length,
              //shrinkWrap: true,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.all(8.0),

                  child:
                      view == 'tileView'
                          ? TileViewTimeTableTile(
                            onDelete: () {
                              setState(() {
                                int i = savedFiles.indexOf(viewingFiles[index]);
                                savedFiles.removeAt(i);
                              });
                            },
                            onRenamed: (File file) {
                              setState(() {
                                int i = savedFiles.indexOf(viewingFiles[index]);

                                savedFiles[i] = file;
                              });
                            },
                            key: ValueKey(viewingFiles[index].path),
                            file: viewingFiles[index],
                            fileRepository: _fileRepository,
                          )
                          : ListViewTimeTableTile(
                            fileRepository: fileRepository,
                            key: ValueKey(viewingFiles[index].path),
                            file: viewingFiles[index],
                            onDeleted: () {
                              setState(() {
                                int i = savedFiles.indexOf(viewingFiles[index]);
                                savedFiles.removeAt(i);
                              });
                            },
                            onRenamed: (File file) {
                              setState(() {
                                int i = savedFiles.indexOf(viewingFiles[index]);

                                savedFiles[i] = file;
                              });
                            },
                          ),
                );
              },
            ),
          ),
          SizedBox(height: 30),
        ],
      ),
    );
  }

  Future<List<File>?> showPickFileDialog(BuildContext context) async {
    List<File>? pickedFiles = [];

    await showDialog(
      context: context,
      builder: (context) {
        return PickTimetableDialog(
          pickedFiles: pickedFiles,

          onFIlesPicked: () async {
            for (File f in pickedFiles!) {
              final filename = f.path.split('/').last;
              final Uint8List fileBytes = f.readAsBytesSync();
              await FileStorageService.saveFile(fileBytes, filename);
            }
            setState(() {
              savedFiles.addAll(pickedFiles);
            });
          },
        );
      },
    );

    return pickedFiles;
  }

  void checkSelectedFile(BuildContext context) async {
    final files = await showPickFileDialog(context);
    if (files != null) {
      // Save, preview, or open the file here
    } else {}
  }
}
