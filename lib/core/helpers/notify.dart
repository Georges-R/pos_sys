import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// User-facing messages.
///
/// `Get.snackbar` reaches for the navigator overlay and throws when there
/// isn't one — during a route transition, or before the first frame. That
/// exception used to escape from inside a `catch` block, turning a handled
/// failure into a crash. Messages are best-effort: never let one take the app
/// down.
class Notify {
  const Notify._();

  static void info(String title, String message) =>
      _show(title, message, null, null);

  static void success(String title, String message) =>
      _show(title, message, Colors.green, Colors.white);

  static void error(String title, String message) =>
      _show(title, message, Colors.red, Colors.white);

  static void _show(
    String title,
    String message,
    Color? background,
    Color? foreground,
  ) {
    try {
      final overlayContext = Get.overlayContext;
      // GetX queues the snackbar asynchronously, so a missing overlay throws
      // outside this try block. Check for a usable one up front instead.
      if (overlayContext == null || Overlay.maybeOf(overlayContext) == null) {
        debugPrint('[$title] $message');
        return;
      }
      Get.snackbar(
        title,
        message,
        backgroundColor: background,
        colorText: foreground,
      );
    } catch (e) {
      debugPrint('[$title] $message (snackbar unavailable: $e)');
    }
  }
}
