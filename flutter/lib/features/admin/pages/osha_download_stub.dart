import 'package:flutter/foundation.dart';

/// Stub implementation of [downloadCsvOnWeb] for non-web targets.
///
/// The real implementation lives in [osha_download_web.dart] and is selected
/// via the conditional import in [osha_export_page.dart]:
///
///   import 'osha_download_stub.dart'
///       if (dart.library.html) 'osha_download_web.dart';
///
/// On mobile and desktop this is a no-op because [kIsWeb] is false and the
/// caller never reaches this path.
void downloadCsvOnWeb(Uint8List bytes, String filename) {
  // No-op on non-web targets.
}
