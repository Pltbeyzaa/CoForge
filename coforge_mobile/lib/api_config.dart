import 'package:flutter/foundation.dart';

/// Platform-aware API base URL (no trailing slash, no /api prefix).
///   Web  → http://127.0.0.1:8000   (same machine as the browser)
///   Android emulator → http://10.0.2.2:8000  (host loopback alias)
final String kBaseUrl = kIsWeb ? 'http://127.0.0.1:8000' : 'http://10.0.2.2:8000';
