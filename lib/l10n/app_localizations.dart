import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'MyFoodMind'**
  String get appTitle;

  /// No description provided for @whoIsEating.
  ///
  /// In en, this message translates to:
  /// **'Who\'s eating?'**
  String get whoIsEating;

  /// No description provided for @addProfile.
  ///
  /// In en, this message translates to:
  /// **'Add profile'**
  String get addProfile;

  /// No description provided for @profileName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get profileName;

  /// No description provided for @nameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a name'**
  String get nameRequired;

  /// No description provided for @pinLabel.
  ///
  /// In en, this message translates to:
  /// **'PIN (4–6 digits)'**
  String get pinLabel;

  /// No description provided for @pinConfirmLabel.
  ///
  /// In en, this message translates to:
  /// **'Repeat PIN'**
  String get pinConfirmLabel;

  /// No description provided for @pinInvalid.
  ///
  /// In en, this message translates to:
  /// **'Use 4–6 digits'**
  String get pinInvalid;

  /// No description provided for @pinMismatch.
  ///
  /// In en, this message translates to:
  /// **'PINs don\'t match'**
  String get pinMismatch;

  /// No description provided for @pinHint.
  ///
  /// In en, this message translates to:
  /// **'Your PIN keeps this profile private on a shared phone. If you forget it, the profile can only be deleted.'**
  String get pinHint;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @unlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get unlock;

  /// No description provided for @enterPinFor.
  ///
  /// In en, this message translates to:
  /// **'PIN for {name}'**
  String enterPinFor(String name);

  /// No description provided for @pinWrong.
  ///
  /// In en, this message translates to:
  /// **'{left, plural, =1{Wrong PIN. 1 try left before a pause.} other{Wrong PIN. {left} tries left before a pause.}}'**
  String pinWrong(int left);

  /// No description provided for @pinLocked.
  ///
  /// In en, this message translates to:
  /// **'Too many tries. Try again in {seconds} s.'**
  String pinLocked(int seconds);

  /// No description provided for @forgotPin.
  ///
  /// In en, this message translates to:
  /// **'Forgot PIN?'**
  String get forgotPin;

  /// No description provided for @deleteProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}?'**
  String deleteProfileTitle(String name);

  /// No description provided for @deleteProfileBody.
  ///
  /// In en, this message translates to:
  /// **'A forgotten PIN can\'t be recovered. Deleting removes this profile and all its meals, journal and chat history from this phone. This can\'t be undone.'**
  String get deleteProfileBody;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @lock.
  ///
  /// In en, this message translates to:
  /// **'Lock'**
  String get lock;

  /// No description provided for @hello.
  ///
  /// In en, this message translates to:
  /// **'Hello, {name}'**
  String hello(String name);

  /// No description provided for @deviceUnsupportedTitle.
  ///
  /// In en, this message translates to:
  /// **'This phone isn\'t supported'**
  String get deviceUnsupportedTitle;

  /// No description provided for @deviceUnsupportedBody.
  ///
  /// In en, this message translates to:
  /// **'MyFoodMind runs its AI fully on your phone and needs at least 6 GB of RAM. This phone has about {gb} GB.'**
  String deviceUnsupportedBody(String gb);

  /// No description provided for @chatHint.
  ///
  /// In en, this message translates to:
  /// **'Ask about food, log a meal…'**
  String get chatHint;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @preparingAi.
  ///
  /// In en, this message translates to:
  /// **'Preparing the on-device AI… The first start takes about a minute.'**
  String get preparingAi;

  /// No description provided for @modelsMissing.
  ///
  /// In en, this message translates to:
  /// **'AI model files are missing in {dir}: {files}'**
  String modelsMissing(String dir, String files);

  /// No description provided for @confirmSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get confirmSave;

  /// No description provided for @confirmDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get confirmDiscard;

  /// No description provided for @confirmSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get confirmSaved;

  /// No description provided for @confirmDiscarded.
  ///
  /// In en, this message translates to:
  /// **'Discarded'**
  String get confirmDiscarded;

  /// No description provided for @perServing.
  ///
  /// In en, this message translates to:
  /// **'Per serving'**
  String get perServing;

  /// No description provided for @minutesServings.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min · {servings} servings'**
  String minutesServings(int minutes, int servings);

  /// No description provided for @notMedicalAdvice.
  ///
  /// In en, this message translates to:
  /// **'General information, not medical advice. Talk to your doctor before changing your diet.'**
  String get notMedicalAdvice;

  /// No description provided for @cameraComing.
  ///
  /// In en, this message translates to:
  /// **'The camera arrives with the Pro plan in a later version.'**
  String get cameraComing;

  /// No description provided for @crisisTitle.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have to go through this alone'**
  String get crisisTitle;

  /// No description provided for @crisisBody.
  ///
  /// In en, this message translates to:
  /// **'If you might hurt yourself, call your local emergency number now. Free, confidential helplines in your country are listed at findahelpline.com.'**
  String get crisisBody;

  /// No description provided for @crisisButton.
  ///
  /// In en, this message translates to:
  /// **'Find a helpline'**
  String get crisisButton;

  /// No description provided for @limitReached.
  ///
  /// In en, this message translates to:
  /// **'You\'ve used today\'s {count} free AI messages. They reset at midnight, or get unlimited chat with Basic.'**
  String limitReached(int count);

  /// No description provided for @agentError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get agentError;

  /// No description provided for @reportResponse.
  ///
  /// In en, this message translates to:
  /// **'Report this response'**
  String get reportResponse;

  /// No description provided for @kcal.
  ///
  /// In en, this message translates to:
  /// **'kcal'**
  String get kcal;

  /// No description provided for @protein.
  ///
  /// In en, this message translates to:
  /// **'Protein'**
  String get protein;

  /// No description provided for @fat.
  ///
  /// In en, this message translates to:
  /// **'Fat'**
  String get fat;

  /// No description provided for @carbs.
  ///
  /// In en, this message translates to:
  /// **'Carbs'**
  String get carbs;

  /// No description provided for @fiber.
  ///
  /// In en, this message translates to:
  /// **'Fiber'**
  String get fiber;

  /// No description provided for @sugar.
  ///
  /// In en, this message translates to:
  /// **'Sugar'**
  String get sugar;

  /// No description provided for @sodium.
  ///
  /// In en, this message translates to:
  /// **'Sodium'**
  String get sodium;

  /// No description provided for @recipeIdeas.
  ///
  /// In en, this message translates to:
  /// **'Recipe ideas'**
  String get recipeIdeas;

  /// No description provided for @ingredients.
  ///
  /// In en, this message translates to:
  /// **'Ingredients'**
  String get ingredients;

  /// No description provided for @steps.
  ///
  /// In en, this message translates to:
  /// **'Steps'**
  String get steps;

  /// No description provided for @healthInfo.
  ///
  /// In en, this message translates to:
  /// **'Health information'**
  String get healthInfo;

  /// No description provided for @servingsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 serving} other{{count} servings}}'**
  String servingsCount(int count);

  /// No description provided for @iAteThis.
  ///
  /// In en, this message translates to:
  /// **'I ate this'**
  String get iAteThis;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
