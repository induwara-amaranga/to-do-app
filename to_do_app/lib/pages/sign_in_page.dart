//import 'dart:ffi';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
//import 'package:path_provider/path_provider.dart';
import 'package:to_do_app/data/database.dart';
import 'package:to_do_app/providers/auth_provider.dart';
import 'package:to_do_app/services/google_drive_service.dart';
import 'package:to_do_app/services/google_sign.dart';
import 'package:to_do_app/services/sync_problem.dart';
import 'package:to_do_app/components/sync_problem_dialog.dart';
import 'package:to_do_app/themes/app_colors.dart';

import 'package:to_do_app/components/app_toggle.dart';

import 'package:to_do_app/components/brand_logo.dart';

class SignInPage extends StatefulWidget {
  final String? filePath;
  final ToDoDataBase db;
  final VoidCallback onSignIn;
  final VoidCallback onImported;
  const SignInPage({
    super.key,
    required this.onSignIn,
    required this.filePath,
    required this.db,
    required this.onImported,
  });

  @override
  State<SignInPage> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<SignInPage> {
  var isAutoSyncOn = false;
  bool isSignedIn = false;
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await GoogleAuthService.ensureApisReady();
      } catch (_) {}
    });
  }

  /// Runs a Drive step. Makes sure the Google token is usable first, and turns
  /// any failure into a dialog that says what to do (sign in again, check the
  /// connection...). [job] returns normally on success.
  Future<bool> _runDriveJob(Future<void> Function() job) async {
    try {
      if (!await GoogleAuthService.ensureApisReady()) {
        throw GoogleAuthService.lastError ?? const NotSignedInException();
      }
      await job();
      return true;
    } catch (e) {
      debugPrint('Google Drive step failed: $e');
      if (!mounted) return false;
      await showSyncProblem(
        context,
        SyncProblem.classify(e, SyncService.googleDrive),
        onRetry: () => _runDriveJob(job),
      );
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'signOut') {
                await GoogleAuthService.signOut();
                if (!context.mounted) return;
                context.read<AuthProvider>().signOutGoogle();
                setState(() {
                  isSignedIn = false;
                });
                widget.onSignIn();
              }
            },
            itemBuilder:
                (context) => [
                  const PopupMenuItem(
                    value: 'signOut',
                    child: Text('sign Out'),
                  ),
                  //const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
          ),
        ],
        title: Text(
          'Sign In with Google',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            SizedBox(height: 20),
            CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.secondary,
              radius: 50,
              child: ClipOval(
                child: Image.network(
                  auth.photoUrl,
                  fit: BoxFit.cover,
                  width: 60,
                  height: 60,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.person_rounded,
                      size: 48,
                      color: context.appColors.muted,
                    );
                  },
                ),
              ),
            ),
            SizedBox(height: 14),
            Text(
              auth.isGoogleSignedIn && auth.displayName.isNotEmpty
                  ? auth.displayName
                  : 'Not Signed In!',

              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 40),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 50.0),
              child: GestureDetector(
                onTap: () async {
                  try {
                    final auth = context.read<AuthProvider>();
                    GoogleSignInAccount? user =
                        await GoogleAuthService.ensureSignedIn(auth: auth);
                    if (user != null) {
                      if (!context.mounted) return;

                      setState(() {
                        isSignedIn = true;
                      });
                      //
                      widget.onSignIn();
                    } else {}
                  } catch (_) {}
                },
                child: Image.asset(
                  scale: 1.5,
                  'assets/images/google/android_light_rd_SI@2x.png',
                  key: const ValueKey('google_image'),

                  fit: BoxFit.cover,
                ),
              ),
            ),
            SizedBox(height: 2),
            // ElevatedButton(
            //   onPressed: () async {
            //     String boxName = "mybox";

            //     // 1. Close the box if it's open
            //     if (Hive.isBoxOpen(boxName)) {
            //       await Hive.box(boxName).close();
            //     }

            //     final hiveFile = File(widget.filePath!);

            //     // 2. Create/Get folder on Drive
            //     final folderId = await GoogleDriveService.createFolder();
            //     if (folderId == null) {
            //       return;
            //     }

            //     // 3. Get file ID in that folder
            //     String? fileId = await GoogleDriveService.getFileId(folderId);

            //     // 4. Download file if exists (await is important!)
            //     if (fileId != null) {
            //       await GoogleDriveService.downloadFile(
            //         fileId,
            //         widget.filePath!,
            //       );
            //     }

            //     // 5. Upload local file to Drive (overwrite if necessary)
            //     await GoogleDriveService.uploadFileToFolder(
            //       hiveFile,
            //       folderId,
            //     );

            //     // 6. Reopen Hive box after file is downloaded/overwritten
            //     await Hive.openBox(boxName);

            //     // 7. Load or initialize data
            //     if (_myBox.get("TODOLIST") == null &&
            //         _myBox.get("CATEGORIES") == null) {
            //       widget.db.createInitialData();
            //     } else {
            //       widget.db.loadData();
            //     }
            //   },

            //   child: Text('Sync Manually'),
            // ),
            SizedBox(height: 40),
            ElevatedButton(
              onPressed: () async {
                //String boxName = "mybox";

                // // 1. Close the box if it's open
                // if (Hive.isBoxOpen(boxName)) {
                //   await Hive.box(boxName).close();
                // }

                final hiveFile = File(widget.filePath!);

                final ok = await _runDriveJob(() async {
                  // 2. Create/Get folder on Drive
                  final folderId = await GoogleDriveService.createFolder();
                  if (folderId == null) throw const NotSignedInException();

                  // 5. Upload local file to Drive (overwrite if necessary)
                  await GoogleDriveService.uploadFileToFolder(
                    hiveFile,
                    folderId,
                  );
                });
                if (!ok || !context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Backup finished.')),
                );
              },

              style: ElevatedButton.styleFrom(
                backgroundColor: context.appColors.accent,
                foregroundColor: context.appColors.onAccent,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 11,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text('Backup'),
            ),

            SizedBox(height: 14),
            ElevatedButton(
              onPressed: () async {
                String boxName = "mybox";

                // 1. Close the box if it's open
                if (Hive.isBoxOpen(boxName)) {
                  await Hive.box(boxName).close();
                }

                bool ok;
                try {
                  ok = await _runDriveJob(() async {
                    // 2. Create/Get folder on Drive
                    final folderId = await GoogleDriveService.createFolder();
                    if (folderId == null) throw const NotSignedInException();

                    // 3. Get file ID in that folder
                    String? fileId = await GoogleDriveService.getFileId(
                      folderId,
                    );

                    // 4. Download file if exists (await is important!)
                    if (fileId != null) {
                      await GoogleDriveService.downloadFile(
                        fileId,
                        widget.filePath!,
                      );
                    }
                  });
                } finally {
                  // 6. Reopen the box even when the download failed, so the
                  // app is never left with a closed box.
                  await Hive.openBox(boxName);
                }

                // 7. Load or initialize data
                if (ok) widget.onImported();
              },

              style: ElevatedButton.styleFrom(
                backgroundColor: context.appColors.accent,
                foregroundColor: context.appColors.onAccent,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 11,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text('Restore'),
            ),
            SizedBox(height: 48),
            Row(
              children: [
                const BrandLogo(BrandIcon.googleDrive),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Auto Back Up With Google Drive',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Backup and Sync Your Tasks Seamlessly across Devices',
                        style: TextStyle(
                          fontSize: 14,
                          color: context.appColors.muted,
                        ),
                        softWrap: true,
                      ),
                    ],
                  ),
                ),
                AppToggle(
                  value: isAutoSyncOn,
                  onChanged: (value) {
                    setState(() => isAutoSyncOn = value);
                  },
                ),
              ],
            ),
            SizedBox(height: 30),
            Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sync History',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Last synced: Never',
                    style: TextStyle(
                      fontSize: 14,
                      color: context.appColors.muted,
                    ),
                    softWrap: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
