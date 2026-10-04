import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:to_do_app/services/google_sign.dart';

class GoogleDriveService {
  // This is where Hive stores boxes by default
  static const webClientId =
      '879200055223-f40a49a8tvse1ca2sngrudqh8r5f3ccg.apps.googleusercontent.com';
  static const androidClientId =
      '879200055223-ber902b42l2nh4bbg43kuvs3tq41dd9i.apps.googleusercontent.com';
  // final GoogleSignIn _googleSignIn = GoogleSignIn(
  //   scopes: [
  //     drive.DriveApi.driveFileScope, // access only files your app creates
  //     // drive.DriveApi.driveScope,   // use this only if you need full Drive access
  //   ],
  // );

  static final drive.DriveApi? _driveApi = GoogleAuthService.driveApi;
  GoogleSignInAccount? _account;
  static GoogleSignInAccount? account;

  static final storage = FlutterSecureStorage();

  // static Future<bool> restoreLastSession() async {

  //   final auth = await storage.read(key: 'drive_auth_token');

  //   if (auth == null) {
  //     return false;
  //   }

  //   final headers = {'Authorization': auth, 'X-Goog-AuthUser': '0'};

  //   try {
  //     final client = _GoogleAuthClient(headers);

  //     _driveApi = drive.DriveApi(client);

  //     // test token
  //     //await _driveApi!.files.list(pageSize: 1);

  //     return true;
  //   } catch (e) {
  //     return false;
  //   }
  // }

  /// --------------------------
  ///  SIGN IN & INIT DRIVE API
  /// --------------------------
  // static Future<GoogleSignInAccount?> initializeSignIn() async {
  //   // 1️⃣ Initialize the singleton instance with your OAuth client IDs
  //   await GoogleSignIn.instance.initialize(
  //     clientId: androidClientId,
  //     serverClientId: webClientId,
  //   );

  //   // 2️⃣ Attempt SILENT sign-in first
  //   account = await GoogleSignIn.instance.attemptLightweightAuthentication();

  //   if (account != null) {
  //   } else {
  //     // 3️⃣ Fallback to UI sign-in
  //     account = await GoogleSignIn.instance.authenticate(
  //       scopeHint: ['https://www.googleapis.com/auth/calendar'],
  //     );
  //   }

  //   // // 2️⃣ Start the authentication flow
  //   // account = await GoogleSignIn.instance.authenticate(
  //   //   scopeHint: ['https://www.googleapis.com/auth/calendar'],
  //   // );
  //   if (account != null) {
  //     // 3️⃣ Get OAuth headers to use with Google APIs
  //     final headers = await account!.authorizationClient.authorizationHeaders([
  //       drive.DriveApi.driveFileScope, // access only files your app creates
  //       // drive.DriveApi.driveScope,   // use this only if you need full Drive access
  //     ], promptIfNecessary: true);

  //     await storage.write(
  //       key: 'drive_auth_token',
  //       value: headers?['Authorization'],
  //     );
  //     if (headers == null) {
  //       return null;
  //     }
  //     final client = _GoogleAuthClient(headers);

  //     _driveApi = drive.DriveApi(client);
  //     //final _driveApi = await getCalendarApi(headers);
  //     //_calendarApi = calendarApi;
  //     return account;
  //   } else {
  //     return null;
  //   }
  // }

  /// --------------------------
  ///  LIST FILES IN DRIVE
  /// --------------------------
  static Future<String?> getFileId(String folderId) async {
    String fileName = "mybox.hive";
    if (_driveApi == null) return null;

    final result = await _driveApi!.files.list(
      q: "name = '$fileName' and '$folderId' in parents and trashed = false",
      spaces: 'drive',
      $fields: 'files(id, name)',
    );

    if (result.files != null && result.files!.isNotEmpty) {
      return result.files!.first.id; // Return the ID of the fi
    }
    return null; // File not found
  }

  /// --------------------------
  ///  UPLOAD FILE
  /// --------------------------
  static Future<String?> uploadFileToFolder(File file, String folderId) async {
    if (_driveApi == null) return null;

    final fileName = file.path.split('/').last;

    try {
      // 1️⃣ Check if file already exists in the folder
      final existingFile = await getFileId(folderId);

      final media = drive.Media(file.openRead(), file.lengthSync());

      if (existingFile != null) {
        // File exists → update it
        final updated = await _driveApi!.files.update(
          drive.File()..name = fileName,

          existingFile,
          uploadMedia: media,
        );
        return updated.id;
      } else {
        // File does not exist → create it in the folder
        final uploaded = await _driveApi!.files.create(
          drive.File()
            ..name = fileName
            ..parents = [folderId],
          uploadMedia: media,
        );
        return uploaded.id;
      }
    } catch (e) {
      return null;
    }
  }

  /// --------------------------
  ///  DOWNLOAD FILE
  /// --------------------------
  static Future<File?> downloadFile(String fileId, String savePath) async {
    //final api = await initializeSignIn();
    if (_driveApi == null) return null;

    final media =
        await _driveApi!.files.get(
              fileId,
              downloadOptions: drive.DownloadOptions.fullMedia,
            )
            as drive.Media;

    final file = File(savePath);
    final sink = file.openWrite();

    await media.stream.pipe(sink);
    await sink.close();

    return file;
  }

  /// --------------------------
  ///  CREATE FOLDER
  /// --------------------------
  static Future<String?> createFolder() async {
    String folderName = "ToDoListData";
    if (_driveApi == null) return null;

    // 1️⃣ Check if folder already exists
    final existingFolders = await _driveApi!.files.list(
      q: "name = '$folderName' and mimeType = 'application/vnd.google-apps.folder' and trashed = false",
      $fields: "files(id, name)",
    );

    if (existingFolders.files != null && existingFolders.files!.isNotEmpty) {
      // Folder found → return existing ID
      return existingFolders.files!.first.id;
    }

    // 2️⃣ Create folder if not found
    final folder =
        drive.File()
          ..name = folderName
          ..mimeType = "application/vnd.google-apps.folder";

    final result = await _driveApi!.files.create(folder);
    return result.id;
  }

  /// --------------------------
  ///  UPLOAD FILE INTO FOLDER
  /// --------------------------
  // static Future<String?> uploadToFolder(File file, String folderId) async {
  //   //final api = await initializeSignIn();
  //   if (_driveApi == null) return null;

  //   final fileMeta =
  //       drive.File()
  //         ..name = file.path.split('/').last
  //         ..parents = [folderId];

  //   final uploaded = await _driveApi!.files.create(
  //     fileMeta,
  //     uploadMedia: drive.Media(file.openRead(), file.lengthSync()),
  //   );

  //   return uploaded.id;
  // }

  /// --------------------------
  ///  DELETE FILE
  /// --------------------------
  static Future<bool> deleteFile(String fileId) async {
    //final api = await initializeSignIn();
    if (_driveApi == null) return false;

    await _driveApi!.files.delete(fileId);
    return true;
  }

  /// --------------------------
  ///  SIGN OUT
  /// --------------------------
  //   static Future<void> signOut() async {
  //     _driveApi = null;
  //     await GoogleSignIn.instance.signOut();
  //   }
  // }

  /// Custom client for authenticated Google requests
  // class _GoogleAuthClient extends http.BaseClient {
  //   final Map<String, String> headers;
  //   final http.Client _inner = http.Client();

  //   _GoogleAuthClient(this.headers);

  //   @override
  //   Future<http.StreamedResponse> send(http.BaseRequest request) =>
  //       _inner.send(request..headers.addAll(headers));
  // }
}
