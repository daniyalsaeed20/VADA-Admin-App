// Cross-platform helper for downloading a text file.
//
// Web gets a real browser download; other platforms no-op for now.
import 'download_file_stub.dart'
    if (dart.library.html) 'download_file_web.dart';

Future<void> downloadTextFile({
  required String filename,
  required String mimeType,
  required String contents,
}) {
  return downloadTextFileImpl(
    filename: filename,
    mimeType: mimeType,
    contents: contents,
  );
}

