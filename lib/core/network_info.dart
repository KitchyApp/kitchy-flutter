import 'package:flutter/foundation.dart';

// =============================================================================
// NETWORK INFO
// =============================================================================
// Single source of truth for connectivity state across the entire app.
//
// Design
// ------
// [isOnlineNotifier]   — ValueNotifier<bool> updated by ApiClient on every
//                        HTTP attempt. Screens ValueListenableBuilder on this
//                        to reactively show/hide the offline banner and
//                        enable/disable internet-dependent buttons.
//
// [NoInternetException] — thrown by ApiClient when a SocketException or
//                         TimeoutException is caught during an HTTP call.
//                         Screens catch this and fall back to local cache
//                         instead of showing a generic error.
// =============================================================================

/// Thrown by [ApiClient] when no internet connectivity is detected.
///
/// Callers should catch this separately from other exceptions and show
/// cached content instead of an error message.
class NoInternetException implements Exception {
  const NoInternetException();

  @override
  String toString() => 'Sem ligação à internet.';
}

/// Live connectivity state for the whole app.
///
/// - `true`  → the last HTTP request completed (device is online).
/// - `false` → the last HTTP request failed with [SocketException] or
///             [TimeoutException] (device appears offline).
///
/// Updated automatically by [ApiClient]. Never set this directly from UI code.
final ValueNotifier<bool> isOnlineNotifier = ValueNotifier(true);
