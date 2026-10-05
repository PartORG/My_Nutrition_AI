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

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @tierFree.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get tierFree;

  /// No description provided for @tierBasic.
  ///
  /// In en, this message translates to:
  /// **'Basic'**
  String get tierBasic;

  /// No description provided for @tierMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get tierMedium;

  /// No description provided for @tierPro.
  ///
  /// In en, this message translates to:
  /// **'Pro'**
  String get tierPro;

  /// No description provided for @plansTitle.
  ///
  /// In en, this message translates to:
  /// **'Plans'**
  String get plansTitle;

  /// No description provided for @monthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get monthly;

  /// No description provided for @yearly.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get yearly;

  /// No description provided for @perMonth.
  ///
  /// In en, this message translates to:
  /// **'{price} / month'**
  String perMonth(String price);

  /// No description provided for @perYear.
  ///
  /// In en, this message translates to:
  /// **'{price} / year'**
  String perYear(String price);

  /// No description provided for @trialThen.
  ///
  /// In en, this message translates to:
  /// **'7 days free, then {price}'**
  String trialThen(String price);

  /// No description provided for @subscribe.
  ///
  /// In en, this message translates to:
  /// **'Subscribe'**
  String get subscribe;

  /// No description provided for @upgrade.
  ///
  /// In en, this message translates to:
  /// **'Upgrade'**
  String get upgrade;

  /// No description provided for @switchPlan.
  ///
  /// In en, this message translates to:
  /// **'Switch'**
  String get switchPlan;

  /// No description provided for @currentPlan.
  ///
  /// In en, this message translates to:
  /// **'Current plan'**
  String get currentPlan;

  /// No description provided for @restorePurchases.
  ///
  /// In en, this message translates to:
  /// **'Restore purchases'**
  String get restorePurchases;

  /// No description provided for @subscriptionTerms.
  ///
  /// In en, this message translates to:
  /// **'Subscriptions renew automatically until cancelled. Cancel anytime in Google Play → Payments & subscriptions. One subscription covers every profile on this phone.'**
  String get subscriptionTerms;

  /// No description provided for @devBillingBanner.
  ///
  /// In en, this message translates to:
  /// **'Developer mode: no real payment. Pick any plan to try it.'**
  String get devBillingBanner;

  /// No description provided for @devBackToFree.
  ///
  /// In en, this message translates to:
  /// **'Back to Free (developer)'**
  String get devBackToFree;

  /// No description provided for @purchaseFailed.
  ///
  /// In en, this message translates to:
  /// **'The purchase didn\'t go through. Please try again.'**
  String get purchaseFailed;

  /// No description provided for @featBasic1.
  ///
  /// In en, this message translates to:
  /// **'Unlimited AI chat'**
  String get featBasic1;

  /// No description provided for @featBasic2.
  ///
  /// In en, this message translates to:
  /// **'Weekly and monthly dashboard'**
  String get featBasic2;

  /// No description provided for @featBasic3.
  ///
  /// In en, this message translates to:
  /// **'Micronutrients, streaks, weight trend'**
  String get featBasic3;

  /// No description provided for @featMedium1.
  ///
  /// In en, this message translates to:
  /// **'Everything in Basic'**
  String get featMedium1;

  /// No description provided for @featMedium2.
  ///
  /// In en, this message translates to:
  /// **'Health conditions: diet limits and suggestions'**
  String get featMedium2;

  /// No description provided for @featMedium3.
  ///
  /// In en, this message translates to:
  /// **'Symptom and reading journal, doctor export'**
  String get featMedium3;

  /// No description provided for @featPro1.
  ///
  /// In en, this message translates to:
  /// **'Everything in Medium'**
  String get featPro1;

  /// No description provided for @featPro2.
  ///
  /// In en, this message translates to:
  /// **'Photo, live camera and barcode recognition'**
  String get featPro2;

  /// No description provided for @featPro3.
  ///
  /// In en, this message translates to:
  /// **'Logs meals and finds recipes from what you see'**
  String get featPro3;

  /// No description provided for @yourPlan.
  ///
  /// In en, this message translates to:
  /// **'Your plan'**
  String get yourPlan;

  /// No description provided for @seePlans.
  ///
  /// In en, this message translates to:
  /// **'See plans'**
  String get seePlans;

  /// No description provided for @periodDay.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get periodDay;

  /// No description provided for @periodWeek.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get periodWeek;

  /// No description provided for @periodMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get periodMonth;

  /// No description provided for @lockedTitle.
  ///
  /// In en, this message translates to:
  /// **'Weekly and monthly trends are in Basic'**
  String get lockedTitle;

  /// No description provided for @lockedBody.
  ///
  /// In en, this message translates to:
  /// **'See calories per day against your goal, daily averages, micronutrients, your logging streak and your weight trend.'**
  String get lockedBody;

  /// No description provided for @caloriesPerDay.
  ///
  /// In en, this message translates to:
  /// **'Calories per day'**
  String get caloriesPerDay;

  /// No description provided for @goalLine.
  ///
  /// In en, this message translates to:
  /// **'Goal {kcal}'**
  String goalLine(int kcal);

  /// No description provided for @dailyAverage.
  ///
  /// In en, this message translates to:
  /// **'Daily average ({days} days with logs)'**
  String dailyAverage(int days);

  /// No description provided for @streakDays.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =0{No logging streak yet} =1{1-day logging streak} other{{days}-day logging streak}}'**
  String streakDays(int days);

  /// No description provided for @weightTrend.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get weightTrend;

  /// No description provided for @weightTrendEmpty.
  ///
  /// In en, this message translates to:
  /// **'Log your weight at least twice to see the trend.'**
  String get weightTrendEmpty;

  /// No description provided for @logWeight.
  ///
  /// In en, this message translates to:
  /// **'Log weight'**
  String get logWeight;

  /// No description provided for @weightLogged.
  ///
  /// In en, this message translates to:
  /// **'Weight saved'**
  String get weightLogged;

  /// No description provided for @plansUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Plans aren\'t available in this build.'**
  String get plansUnavailable;

  /// No description provided for @cautionAllergy.
  ///
  /// In en, this message translates to:
  /// **'Contains {food}, on your allergy list ({allergen})'**
  String cautionAllergy(String food, String allergen);

  /// No description provided for @cautionCondition.
  ///
  /// In en, this message translates to:
  /// **'Contains {food}, a food to avoid with {condition}'**
  String cautionCondition(String food, String condition);

  /// No description provided for @condDiabetesT2.
  ///
  /// In en, this message translates to:
  /// **'Type 2 diabetes'**
  String get condDiabetesT2;

  /// No description provided for @condHypertension.
  ///
  /// In en, this message translates to:
  /// **'High blood pressure'**
  String get condHypertension;

  /// No description provided for @condGout.
  ///
  /// In en, this message translates to:
  /// **'Gout'**
  String get condGout;

  /// No description provided for @condAls.
  ///
  /// In en, this message translates to:
  /// **'ALS'**
  String get condAls;

  /// No description provided for @condMs.
  ///
  /// In en, this message translates to:
  /// **'Multiple sclerosis'**
  String get condMs;

  /// No description provided for @healthTitle.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get healthTitle;

  /// No description provided for @healthMeHint.
  ///
  /// In en, this message translates to:
  /// **'Conditions, journal, timeline, report for your doctor'**
  String get healthMeHint;

  /// No description provided for @conditionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Conditions'**
  String get conditionsTitle;

  /// No description provided for @conditionsHint.
  ///
  /// In en, this message translates to:
  /// **'Recipe suggestions skip foods to avoid, and limits lower your daily targets. These are general suggestions, not medical advice: talk to your doctor before changing your diet.'**
  String get conditionsHint;

  /// No description provided for @limitLine.
  ///
  /// In en, this message translates to:
  /// **'{nutrient}: at most {amount} a day ({condition})'**
  String limitLine(String nutrient, String amount, String condition);

  /// No description provided for @avoidLine.
  ///
  /// In en, this message translates to:
  /// **'Foods to avoid: {foods}'**
  String avoidLine(String foods);

  /// No description provided for @limitFrom.
  ///
  /// In en, this message translates to:
  /// **'limit for {condition}'**
  String limitFrom(String condition);

  /// No description provided for @timelineTitle.
  ///
  /// In en, this message translates to:
  /// **'Timeline'**
  String get timelineTitle;

  /// No description provided for @timelineHint.
  ///
  /// In en, this message translates to:
  /// **'Nutrients, readings and symptoms by date'**
  String get timelineHint;

  /// No description provided for @timelineEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing recorded in this period.'**
  String get timelineEmpty;

  /// No description provided for @reportButton.
  ///
  /// In en, this message translates to:
  /// **'Report for your doctor'**
  String get reportButton;

  /// No description provided for @reportHint.
  ///
  /// In en, this message translates to:
  /// **'PDF and CSV of what you logged'**
  String get reportHint;

  /// No description provided for @journalTitle.
  ///
  /// In en, this message translates to:
  /// **'Journal'**
  String get journalTitle;

  /// No description provided for @journalHint.
  ///
  /// In en, this message translates to:
  /// **'Last 14 days'**
  String get journalHint;

  /// No description provided for @journalEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing recorded in the last 14 days.'**
  String get journalEmpty;

  /// No description provided for @symptom.
  ///
  /// In en, this message translates to:
  /// **'Symptom'**
  String get symptom;

  /// No description provided for @symptomHint.
  ///
  /// In en, this message translates to:
  /// **'What do you feel? e.g. fatigue'**
  String get symptomHint;

  /// No description provided for @severity.
  ///
  /// In en, this message translates to:
  /// **'Severity (optional)'**
  String get severity;

  /// No description provided for @severityHint.
  ///
  /// In en, this message translates to:
  /// **'1 = mild, 5 = severe'**
  String get severityHint;

  /// No description provided for @glucose.
  ///
  /// In en, this message translates to:
  /// **'Blood glucose'**
  String get glucose;

  /// No description provided for @bloodPressure.
  ///
  /// In en, this message translates to:
  /// **'Blood pressure'**
  String get bloodPressure;

  /// No description provided for @systolic.
  ///
  /// In en, this message translates to:
  /// **'Systolic (upper)'**
  String get systolic;

  /// No description provided for @diastolic.
  ///
  /// In en, this message translates to:
  /// **'Diastolic (lower)'**
  String get diastolic;

  /// No description provided for @deleteEntryTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this entry?'**
  String get deleteEntryTitle;

  /// No description provided for @healthLockedTitle.
  ///
  /// In en, this message translates to:
  /// **'Health tracking is part of Medium'**
  String get healthLockedTitle;

  /// No description provided for @healthLockedBody.
  ///
  /// In en, this message translates to:
  /// **'Medium adds conditions (recipe filtering and daily limits), a symptom and reading journal, timeline charts and a report to share with your doctor.'**
  String get healthLockedBody;

  /// No description provided for @conditionsStillApply.
  ///
  /// In en, this message translates to:
  /// **'Your conditions still filter recipes and limit your targets: {conditions}'**
  String conditionsStillApply(String conditions);

  /// No description provided for @days.
  ///
  /// In en, this message translates to:
  /// **'{count} days'**
  String days(int count);

  /// No description provided for @perDay.
  ///
  /// In en, this message translates to:
  /// **'per day'**
  String get perDay;

  /// No description provided for @symptomsTitle.
  ///
  /// In en, this message translates to:
  /// **'Symptoms'**
  String get symptomsTitle;

  /// No description provided for @readingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Readings'**
  String get readingsTitle;

  /// No description provided for @reportSheetHint.
  ///
  /// In en, this message translates to:
  /// **'A PDF to read and a CSV for spreadsheets, with everything you logged. You choose where to send them; the app shares nothing by itself.'**
  String get reportSheetHint;

  /// No description provided for @reportShare.
  ///
  /// In en, this message translates to:
  /// **'Create and share'**
  String get reportShare;

  /// No description provided for @reportSubject.
  ///
  /// In en, this message translates to:
  /// **'MyFoodMind report'**
  String get reportSubject;

  /// No description provided for @reportFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t create the report.'**
  String get reportFailed;

  /// No description provided for @reportTitle.
  ///
  /// In en, this message translates to:
  /// **'MyFoodMind report: {name}'**
  String reportTitle(String name);

  /// No description provided for @reportCreated.
  ///
  /// In en, this message translates to:
  /// **'created {date}'**
  String reportCreated(String date);

  /// No description provided for @reportDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Recorded by the user in the MyFoodMind app. Values are shown as logged; the app does not interpret them and gives no medical advice. Limits come from the conditions the user selected.'**
  String get reportDisclaimer;

  /// No description provided for @reportNone.
  ///
  /// In en, this message translates to:
  /// **'None recorded.'**
  String get reportNone;

  /// No description provided for @reportDailyNutrition.
  ///
  /// In en, this message translates to:
  /// **'Daily nutrition ({days} days with logs)'**
  String reportDailyNutrition(int days);

  /// No description provided for @reportDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get reportDate;

  /// No description provided for @reportItems.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get reportItems;

  /// No description provided for @reportMeasurement.
  ///
  /// In en, this message translates to:
  /// **'Measurement'**
  String get reportMeasurement;

  /// No description provided for @reportValue.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get reportValue;
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
