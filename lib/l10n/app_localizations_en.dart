// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'MyFoodMind';

  @override
  String get whoIsEating => 'Who\'s eating?';

  @override
  String get addProfile => 'Add profile';

  @override
  String get profileName => 'Name';

  @override
  String get nameRequired => 'Enter a name';

  @override
  String get pinLabel => 'PIN (4–6 digits)';

  @override
  String get pinConfirmLabel => 'Repeat PIN';

  @override
  String get pinInvalid => 'Use 4–6 digits';

  @override
  String get pinMismatch => 'PINs don\'t match';

  @override
  String get pinHint =>
      'Your PIN keeps this profile private on a shared phone. If you forget it, the profile can only be deleted.';

  @override
  String get create => 'Create';

  @override
  String get unlock => 'Unlock';

  @override
  String enterPinFor(String name) {
    return 'PIN for $name';
  }

  @override
  String pinWrong(int left) {
    String _temp0 = intl.Intl.pluralLogic(
      left,
      locale: localeName,
      other: 'Wrong PIN. $left tries left before a pause.',
      one: 'Wrong PIN. 1 try left before a pause.',
    );
    return '$_temp0';
  }

  @override
  String pinLocked(int seconds) {
    return 'Too many tries. Try again in $seconds s.';
  }

  @override
  String get forgotPin => 'Forgot PIN?';

  @override
  String deleteProfileTitle(String name) {
    return 'Delete $name?';
  }

  @override
  String get deleteProfileBody =>
      'A forgotten PIN can\'t be recovered. Deleting removes this profile and all its meals, journal and chat history from this phone. This can\'t be undone.';

  @override
  String get delete => 'Delete';

  @override
  String get cancel => 'Cancel';

  @override
  String get lock => 'Lock';

  @override
  String hello(String name) {
    return 'Hello, $name';
  }

  @override
  String get deviceUnsupportedTitle => 'This phone isn\'t supported';

  @override
  String deviceUnsupportedBody(String gb) {
    return 'MyFoodMind runs its AI fully on your phone and needs at least 6 GB of RAM. This phone has about $gb GB.';
  }
}
