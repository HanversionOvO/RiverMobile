import 'package:river/app/app_settings_controller.dart';
import 'package:river/core/account/account_store.dart';
import 'package:river/core/update/app_update_checker.dart';

class AppDependencies {
  const AppDependencies({
    required this.settingsController,
    required this.accountStore,
    required this.updateChecker,
  });

  final AppSettingsController settingsController;
  final AccountStore accountStore;
  final AppUpdateChecker updateChecker;
}
