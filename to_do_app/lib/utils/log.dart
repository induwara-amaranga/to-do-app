import 'package:flutter/foundation.dart';

/// Debug-only logging.
///
/// The services layer logs heavily, including inside per-event loops during
/// calendar sync and import. `print` runs in release builds too, so that cost
/// scales with how much data is moving through those loops rather than with
/// how much a developer actually needs to see. Routing through here makes the
/// whole lot a no-op once `kDebugMode` is false — the tree shaker drops the
/// call and the string interpolation that feeds it.
///
/// Use for diagnostics. Genuine user-facing errors should surface in the UI,
/// not only here.
void logd(Object? message) {
  if (kDebugMode) {
    print(message);
  }
}
