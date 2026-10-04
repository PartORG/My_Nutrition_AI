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

  /// No description provided for @aiKnowsTitle.
  ///
  /// In en, this message translates to:
  /// **'What the AI knows about you'**
  String get aiKnowsTitle;

  /// No description provided for @aiKnowsIntro.
  ///
  /// In en, this message translates to:
  /// **'This is everything the assistant is told about you. It stays on this phone.'**
  String get aiKnowsIntro;

  /// No description provided for @factsSection.
  ///
  /// In en, this message translates to:
  /// **'Things you told it'**
  String get factsSection;

  /// No description provided for @factsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing yet. Tell the chat things like “I have an air fryer”.'**
  String get factsEmpty;

  /// No description provided for @allergiesSection.
  ///
  /// In en, this message translates to:
  /// **'Allergies'**
  String get allergiesSection;

  /// No description provided for @allergiesEmpty.
  ///
  /// In en, this message translates to:
  /// **'None recorded.'**
  String get allergiesEmpty;

  /// No description provided for @habitsSection.
  ///
  /// In en, this message translates to:
  /// **'Habits it noticed (last 30 days)'**
  String get habitsSection;

  /// No description provided for @habitsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Not enough logged meals yet.'**
  String get habitsEmpty;

  /// No description provided for @conversationsSection.
  ///
  /// In en, this message translates to:
  /// **'Conversations'**
  String get conversationsSection;

  /// No description provided for @conversationsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No messages stored.} =1{1 message stored.} other{{count} messages stored.}}'**
  String conversationsCount(int count);

  /// No description provided for @forgetConversations.
  ///
  /// In en, this message translates to:
  /// **'Forget past conversations'**
  String get forgetConversations;

  /// No description provided for @forgetConversationsBody.
  ///
  /// In en, this message translates to:
  /// **'Deletes your chat history and the AI\'s memory of it. Logged meals, facts and allergies stay.'**
  String get forgetConversationsBody;

  /// No description provided for @forget.
  ///
  /// In en, this message translates to:
  /// **'Forget'**
  String get forget;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @tabToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get tabToday;

  /// No description provided for @tabChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get tabChat;

  /// No description provided for @tabLog.
  ///
  /// In en, this message translates to:
  /// **'Log'**
  String get tabLog;

  /// No description provided for @tabMe.
  ///
  /// In en, this message translates to:
  /// **'Me'**
  String get tabMe;

  /// No description provided for @eatenOfGoal.
  ///
  /// In en, this message translates to:
  /// **'of {goal} kcal'**
  String eatenOfGoal(int goal);

  /// No description provided for @kcalLeft.
  ///
  /// In en, this message translates to:
  /// **'{left} kcal left'**
  String kcalLeft(int left);

  /// No description provided for @kcalOver.
  ///
  /// In en, this message translates to:
  /// **'{over} kcal over'**
  String kcalOver(int over);

  /// No description provided for @overBy.
  ///
  /// In en, this message translates to:
  /// **'over by {amount}'**
  String overBy(String amount);

  /// No description provided for @eatenToday.
  ///
  /// In en, this message translates to:
  /// **'Eaten today'**
  String get eatenToday;

  /// No description provided for @setGoalsTitle.
  ///
  /// In en, this message translates to:
  /// **'Set your daily goals'**
  String get setGoalsTitle;

  /// No description provided for @setGoalsBody.
  ///
  /// In en, this message translates to:
  /// **'Tell us a little about you to get calorie and nutrient targets.'**
  String get setGoalsBody;

  /// No description provided for @setGoalsButton.
  ///
  /// In en, this message translates to:
  /// **'Set goals'**
  String get setGoalsButton;

  /// No description provided for @todaysMeals.
  ///
  /// In en, this message translates to:
  /// **'Today\'s meals'**
  String get todaysMeals;

  /// No description provided for @noMealsYet.
  ///
  /// In en, this message translates to:
  /// **'Nothing logged yet. Use the Log tab or tell the chat what you ate.'**
  String get noMealsYet;

  /// No description provided for @deleteMealTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this entry?'**
  String get deleteMealTitle;

  /// No description provided for @mealBreakfast.
  ///
  /// In en, this message translates to:
  /// **'Breakfast'**
  String get mealBreakfast;

  /// No description provided for @mealLunch.
  ///
  /// In en, this message translates to:
  /// **'Lunch'**
  String get mealLunch;

  /// No description provided for @mealDinner.
  ///
  /// In en, this message translates to:
  /// **'Dinner'**
  String get mealDinner;

  /// No description provided for @mealSnack.
  ///
  /// In en, this message translates to:
  /// **'Snack'**
  String get mealSnack;

  /// No description provided for @searchFood.
  ///
  /// In en, this message translates to:
  /// **'Search foods, dishes, recipes…'**
  String get searchFood;

  /// No description provided for @kindFood.
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get kindFood;

  /// No description provided for @kindDish.
  ///
  /// In en, this message translates to:
  /// **'Dish'**
  String get kindDish;

  /// No description provided for @kindRecipe.
  ///
  /// In en, this message translates to:
  /// **'Recipe'**
  String get kindRecipe;

  /// No description provided for @kindProduct.
  ///
  /// In en, this message translates to:
  /// **'Product'**
  String get kindProduct;

  /// No description provided for @perServing2.
  ///
  /// In en, this message translates to:
  /// **'{kcal} kcal per serving'**
  String perServing2(int kcal);

  /// No description provided for @per100g.
  ///
  /// In en, this message translates to:
  /// **'{kcal} kcal per 100 g'**
  String per100g(int kcal);

  /// No description provided for @servings.
  ///
  /// In en, this message translates to:
  /// **'Servings'**
  String get servings;

  /// No description provided for @grams.
  ///
  /// In en, this message translates to:
  /// **'Grams'**
  String get grams;

  /// No description provided for @logButton.
  ///
  /// In en, this message translates to:
  /// **'Log'**
  String get logButton;

  /// No description provided for @loggedSnack.
  ///
  /// In en, this message translates to:
  /// **'Logged {label}'**
  String loggedSnack(String label);

  /// No description provided for @noResults.
  ///
  /// In en, this message translates to:
  /// **'No match in the food database.'**
  String get noResults;

  /// No description provided for @goalsTitle.
  ///
  /// In en, this message translates to:
  /// **'Your daily goals'**
  String get goalsTitle;

  /// No description provided for @goalsIntro.
  ///
  /// In en, this message translates to:
  /// **'Used to compute your calorie and nutrient targets. Stays on this phone.'**
  String get goalsIntro;

  /// No description provided for @later.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get later;

  /// No description provided for @units.
  ///
  /// In en, this message translates to:
  /// **'Units'**
  String get units;

  /// No description provided for @metric.
  ///
  /// In en, this message translates to:
  /// **'Metric'**
  String get metric;

  /// No description provided for @imperial.
  ///
  /// In en, this message translates to:
  /// **'Imperial'**
  String get imperial;

  /// No description provided for @sex.
  ///
  /// In en, this message translates to:
  /// **'Sex used for the formula'**
  String get sex;

  /// No description provided for @female.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get female;

  /// No description provided for @male.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get male;

  /// No description provided for @other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get other;

  /// No description provided for @birthYear.
  ///
  /// In en, this message translates to:
  /// **'Birth year'**
  String get birthYear;

  /// No description provided for @heightCm.
  ///
  /// In en, this message translates to:
  /// **'Height (cm)'**
  String get heightCm;

  /// No description provided for @heightFt.
  ///
  /// In en, this message translates to:
  /// **'ft'**
  String get heightFt;

  /// No description provided for @heightIn.
  ///
  /// In en, this message translates to:
  /// **'in'**
  String get heightIn;

  /// No description provided for @weightKg.
  ///
  /// In en, this message translates to:
  /// **'Weight (kg)'**
  String get weightKg;

  /// No description provided for @weightLb.
  ///
  /// In en, this message translates to:
  /// **'Weight (lb)'**
  String get weightLb;

  /// No description provided for @activity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get activity;

  /// No description provided for @activitySedentary.
  ///
  /// In en, this message translates to:
  /// **'Sedentary: mostly sitting'**
  String get activitySedentary;

  /// No description provided for @activityLight.
  ///
  /// In en, this message translates to:
  /// **'Light: exercise 1–3 days a week'**
  String get activityLight;

  /// No description provided for @activityModerate.
  ///
  /// In en, this message translates to:
  /// **'Moderate: exercise 3–5 days a week'**
  String get activityModerate;

  /// No description provided for @activityActive.
  ///
  /// In en, this message translates to:
  /// **'Active: exercise 6–7 days a week'**
  String get activityActive;

  /// No description provided for @activityVeryActive.
  ///
  /// In en, this message translates to:
  /// **'Very active: hard daily training or physical job'**
  String get activityVeryActive;

  /// No description provided for @goal.
  ///
  /// In en, this message translates to:
  /// **'Goal'**
  String get goal;

  /// No description provided for @goalLose.
  ///
  /// In en, this message translates to:
  /// **'Lose weight'**
  String get goalLose;

  /// No description provided for @goalMaintain.
  ///
  /// In en, this message translates to:
  /// **'Maintain'**
  String get goalMaintain;

  /// No description provided for @goalGain.
  ///
  /// In en, this message translates to:
  /// **'Gain weight'**
  String get goalGain;

  /// No description provided for @invalidNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid number'**
  String get invalidNumber;

  /// No description provided for @under18.
  ///
  /// In en, this message translates to:
  /// **'For people under 18 these formulas don\'t apply. Set targets with your pediatrician below.'**
  String get under18;

  /// No description provided for @targetsTitle.
  ///
  /// In en, this message translates to:
  /// **'Daily targets'**
  String get targetsTitle;

  /// No description provided for @targetsNone.
  ///
  /// In en, this message translates to:
  /// **'No targets yet.'**
  String get targetsNone;

  /// No description provided for @custom.
  ///
  /// In en, this message translates to:
  /// **'custom'**
  String get custom;

  /// No description provided for @editTarget.
  ///
  /// In en, this message translates to:
  /// **'{name} target'**
  String editTarget(String name);

  /// No description provided for @resetTarget.
  ///
  /// In en, this message translates to:
  /// **'Use computed'**
  String get resetTarget;

  /// No description provided for @editDetails.
  ///
  /// In en, this message translates to:
  /// **'Edit my details'**
  String get editDetails;

  /// No description provided for @aiKnowsLoading.
  ///
  /// In en, this message translates to:
  /// **'Available when the AI has loaded.'**
  String get aiKnowsLoading;

  /// No description provided for @switchProfile.
  ///
  /// In en, this message translates to:
  /// **'Lock and switch profile'**
  String get switchProfile;

  /// No description provided for @limitSuffix.
  ///
  /// In en, this message translates to:
  /// **'max'**
  String get limitSuffix;

  /// No description provided for @remindersTitle.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get remindersTitle;

  /// No description provided for @remindersHint.
  ///
  /// In en, this message translates to:
  /// **'Times follow your usual meal times once you\'ve logged a few meals.'**
  String get remindersHint;

  /// No description provided for @reminderBreakfast.
  ///
  /// In en, this message translates to:
  /// **'Log breakfast'**
  String get reminderBreakfast;

  /// No description provided for @reminderLunch.
  ///
  /// In en, this message translates to:
  /// **'Log lunch'**
  String get reminderLunch;

  /// No description provided for @reminderDinner.
  ///
  /// In en, this message translates to:
  /// **'Log dinner'**
  String get reminderDinner;

  /// No description provided for @reminderEvening.
  ///
  /// In en, this message translates to:
  /// **'Evening check-in'**
  String get reminderEvening;

  /// No description provided for @notifMeal.
  ///
  /// In en, this message translates to:
  /// **'{name}, time to log your {meal}?'**
  String notifMeal(String name, String meal);

  /// No description provided for @notifEvening.
  ///
  /// In en, this message translates to:
  /// **'{name}, how did today go? Your summary is ready.'**
  String notifEvening(String name);

  /// No description provided for @notificationsDenied.
  ///
  /// In en, this message translates to:
  /// **'Notifications are turned off for MyFoodMind in Android settings.'**
  String get notificationsDenied;

  /// No description provided for @voiceInput.
  ///
  /// In en, this message translates to:
  /// **'Speak'**
  String get voiceInput;

  /// No description provided for @voiceStop.
  ///
  /// In en, this message translates to:
  /// **'Stop listening'**
  String get voiceStop;

  /// No description provided for @voiceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Voice input needs offline speech recognition on this phone (Google app → Settings → Voice → Offline speech recognition → English). MyFoodMind never sends your voice online.'**
  String get voiceUnavailable;

  /// No description provided for @youSaid.
  ///
  /// In en, this message translates to:
  /// **'You said: {text}'**
  String youSaid(String text);

  /// No description provided for @aiSaid.
  ///
  /// In en, this message translates to:
  /// **'MyFoodMind said: {text}'**
  String aiSaid(String text);

  /// No description provided for @useFingerprint.
  ///
  /// In en, this message translates to:
  /// **'Use fingerprint'**
  String get useFingerprint;

  /// No description provided for @fingerprintTitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock with fingerprint'**
  String get fingerprintTitle;

  /// No description provided for @fingerprintHint.
  ///
  /// In en, this message translates to:
  /// **'Only while this is the only profile on the phone: Android can\'t tell whose fingerprint it is.'**
  String get fingerprintHint;

  /// No description provided for @fingerprintReason.
  ///
  /// In en, this message translates to:
  /// **'Unlock {name}\'s profile'**
  String fingerprintReason(String name);
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
