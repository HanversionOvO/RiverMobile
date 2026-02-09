import 'package:river/app/app_settings_controller.dart';
import 'package:river/core/account/account_store.dart';

class AppDependencies {
  const AppDependencies({
    required this.settingsController,
    required this.accountStore,
  });

  final AppSettingsController settingsController;
  final AccountStore accountStore;
}
