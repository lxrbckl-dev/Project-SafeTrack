import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// Web implementation of [downloadCsvOnWeb].
///
/// Creates a temporary `<a download>` element pointing at a base64 data-URI
/// and programmatically clicks it, triggering the browser's file-save flow.
///
/// Selected via the conditional import in [osha_export_page.dart] only when
/// `dart.library.html` is available (Flutter web builds).
void downloadCsvOnWeb(Uint8List bytes, String filename) {
  final b64 = base64Encode(bytes);
  final dataUri = 'data:text/csv;charset=utf-8;base64,$b64'.toJS;

  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = dataUri.toDart
    ..download = filename
    ..style.display = 'none';

  web.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
}
