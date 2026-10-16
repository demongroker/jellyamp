import 'package:finamp/services/update_checker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider that checks for updates on app startup.
/// The check runs once and the result is cached.
final updateCheckerProvider = FutureProvider<UpdateInfo?>((ref) async {
  return UpdateChecker.checkForUpdate();
});
