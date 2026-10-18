import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_uk.dart';

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
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('fr'),
    Locale('uk'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'My Nutrition AI'**
  String get appTitle;

  /// No description provided for @addProfile.
  ///
  /// In en, this message translates to:
  /// **'Create profile'**
  String get addProfile;

  /// No description provided for @googleWrongAccount.
  ///
  /// In en, this message translates to:
  /// **'That isn’t the Google account this profile was created with.'**
  String get googleWrongAccount;

  /// No description provided for @signInWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google'**
  String get signInWithGoogle;

  /// No description provided for @continueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get continueWithGoogle;

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
  /// **'Your PIN unlocks the app when the fingerprint can’t. If you forget it, the profile can only be deleted.'**
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
  /// **'My Nutrition AI runs its AI fully on your phone and needs at least 6 GB of RAM. This phone has about {gb} GB.'**
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
  /// **'General information from published guidelines, not medical advice. It doesn\'t replace your doctor or dietitian: talk to them before changing your diet or medicines.'**
  String get notMedicalAdvice;

  /// No description provided for @chatDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'AI answers can be wrong and don\'t replace a doctor. In an emergency, call your local emergency number.'**
  String get chatDisclaimer;

  /// No description provided for @medicalDisclaimerTitle.
  ///
  /// In en, this message translates to:
  /// **'Medical disclaimer'**
  String get medicalDisclaimerTitle;

  /// No description provided for @medicalDisclaimerBody.
  ///
  /// In en, this message translates to:
  /// **'My Nutrition AI and its AI assistant give general information about food and nutrition. They are not a medical device and do not diagnose, treat, cure or prevent any disease.\n\nNothing in the app, including the assistant\'s answers, condition limits and health information, replaces advice from a doctor, dietitian or other qualified health professional. The AI runs on your phone and can make mistakes.\n\nAlways talk to your doctor before changing your diet, medicines or treatment, especially if you have a medical condition, are pregnant or breastfeeding, or have or had an eating disorder. Never ignore professional advice or delay seeking it because of something in this app.\n\nIf you think you may have a medical emergency, call your local emergency number right away.'**
  String get medicalDisclaimerBody;

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
  /// **'Allergies and diet'**
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

  /// No description provided for @birthMonth.
  ///
  /// In en, this message translates to:
  /// **'Birth month'**
  String get birthMonth;

  /// No description provided for @chooseMonth.
  ///
  /// In en, this message translates to:
  /// **'Choose a month'**
  String get chooseMonth;

  /// No description provided for @underweightNoLose.
  ///
  /// In en, this message translates to:
  /// **'Your BMI is under 18.5, so losing weight isn\'t safe: your targets stay at maintaining your weight. Talk to a doctor if you want to change it.'**
  String get underweightNoLose;

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

  /// No description provided for @aboutMe.
  ///
  /// In en, this message translates to:
  /// **'About me'**
  String get aboutMe;

  /// No description provided for @sexShort.
  ///
  /// In en, this message translates to:
  /// **'Sex'**
  String get sexShort;

  /// No description provided for @height.
  ///
  /// In en, this message translates to:
  /// **'Height'**
  String get height;

  /// No description provided for @weight.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get weight;

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
  /// **'Notifications are turned off for My Nutrition AI in Android settings.'**
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
  /// **'Voice input needs offline speech recognition on this phone (Google app → Settings → Voice → Offline speech recognition → English). My Nutrition AI never sends your voice online.'**
  String get voiceUnavailable;

  /// No description provided for @youSaid.
  ///
  /// In en, this message translates to:
  /// **'You said: {text}'**
  String youSaid(String text);

  /// No description provided for @aiSaid.
  ///
  /// In en, this message translates to:
  /// **'My Nutrition AI said: {text}'**
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
  /// **'Unlock with your fingerprint instead of the PIN.'**
  String get fingerprintHint;

  /// No description provided for @fingerprintReason.
  ///
  /// In en, this message translates to:
  /// **'Unlock {name}\'s profile'**
  String fingerprintReason(String name);

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

  /// No description provided for @featBasic3.
  ///
  /// In en, this message translates to:
  /// **'Water reminders, logging streak, micronutrients'**
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
  /// **'Photo and live camera food recognition'**
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
  /// **'More with Basic'**
  String get lockedTitle;

  /// No description provided for @lockedBody.
  ///
  /// In en, this message translates to:
  /// **'Your logging streak, a weekly meal plan with a shopping list, water reminders and 3 months of history.'**
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
  /// **'Log your weight on two different days to see the trend.'**
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
  /// **'Contains {food}, which your allergies or diet exclude ({allergen})'**
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
  /// **'My Nutrition AI report'**
  String get reportSubject;

  /// No description provided for @reportFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t create the report.'**
  String get reportFailed;

  /// No description provided for @reportTitle.
  ///
  /// In en, this message translates to:
  /// **'My Nutrition AI report: {name}'**
  String reportTitle(String name);

  /// No description provided for @reportCreated.
  ///
  /// In en, this message translates to:
  /// **'created {date}'**
  String reportCreated(String date);

  /// No description provided for @reportDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Recorded by the user in the My Nutrition AI app. Values are shown as logged; the app does not interpret them and gives no medical advice. Limits come from the conditions the user selected.'**
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

  /// No description provided for @cameraTitle.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get cameraTitle;

  /// No description provided for @cameraOpen.
  ///
  /// In en, this message translates to:
  /// **'Open camera'**
  String get cameraOpen;

  /// No description provided for @cameraPhoto.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get cameraPhoto;

  /// No description provided for @cameraLive.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get cameraLive;

  /// No description provided for @cameraUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The camera isn\'t available right now. Close other apps that use it and try again.'**
  String get cameraUnavailable;

  /// No description provided for @cameraShoot.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get cameraShoot;

  /// No description provided for @cameraNaming.
  ///
  /// In en, this message translates to:
  /// **'Recognizing food…'**
  String get cameraNaming;

  /// No description provided for @cameraNamingFailed.
  ///
  /// In en, this message translates to:
  /// **'AI recognition failed: showing quick detection instead. Check the items.'**
  String get cameraNamingFailed;

  /// No description provided for @cameraUseFound.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Continue} =1{Use 1 item} other{Use {count} items}}'**
  String cameraUseFound(int count);

  /// No description provided for @reviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Check what was found'**
  String get reviewTitle;

  /// No description provided for @reviewHint.
  ///
  /// In en, this message translates to:
  /// **'Amounts from a photo are estimates (≈). Change or remove anything; nothing is saved until you tap Log.'**
  String get reviewHint;

  /// No description provided for @reviewEmpty.
  ///
  /// In en, this message translates to:
  /// **'No food found. Add items by name.'**
  String get reviewEmpty;

  /// No description provided for @notInDatabase.
  ///
  /// In en, this message translates to:
  /// **'{name}: not in the database. Tap Change to pick a food.'**
  String notInDatabase(String name);

  /// No description provided for @reviewChange.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get reviewChange;

  /// No description provided for @reviewAdd.
  ///
  /// In en, this message translates to:
  /// **'Add item'**
  String get reviewAdd;

  /// No description provided for @reviewLog.
  ///
  /// In en, this message translates to:
  /// **'Log this meal'**
  String get reviewLog;

  /// No description provided for @reviewLogged.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item logged} other{{count} items logged}}'**
  String reviewLogged(int count);

  /// No description provided for @reviewCook.
  ///
  /// In en, this message translates to:
  /// **'What can I cook?'**
  String get reviewCook;

  /// No description provided for @yourRating.
  ///
  /// In en, this message translates to:
  /// **'Your rating'**
  String get yourRating;

  /// No description provided for @kindRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get kindRecent;

  /// No description provided for @recentFoods.
  ///
  /// In en, this message translates to:
  /// **'Recent and frequent'**
  String get recentFoods;

  /// No description provided for @repeatYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday\'s {meal} · {kcal} kcal'**
  String repeatYesterday(String meal, int kcal);

  /// No description provided for @quickAdd.
  ///
  /// In en, this message translates to:
  /// **'Quick add'**
  String get quickAdd;

  /// No description provided for @quickAddName.
  ///
  /// In en, this message translates to:
  /// **'Name (optional)'**
  String get quickAddName;

  /// No description provided for @editMeal.
  ///
  /// In en, this message translates to:
  /// **'Edit meal'**
  String get editMeal;

  /// No description provided for @changeFood.
  ///
  /// In en, this message translates to:
  /// **'Change food'**
  String get changeFood;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @cardLogMeal.
  ///
  /// In en, this message translates to:
  /// **'Log {meal}'**
  String cardLogMeal(String meal);

  /// No description provided for @cardSaveRecipe.
  ///
  /// In en, this message translates to:
  /// **'Save recipe'**
  String get cardSaveRecipe;

  /// No description provided for @cardRateRecipe.
  ///
  /// In en, this message translates to:
  /// **'Rate recipe'**
  String get cardRateRecipe;

  /// No description provided for @cardRemember.
  ///
  /// In en, this message translates to:
  /// **'Remember'**
  String get cardRemember;

  /// No description provided for @cardAddAllergy.
  ///
  /// In en, this message translates to:
  /// **'Add allergy'**
  String get cardAddAllergy;

  /// No description provided for @cardRemoveAllergy.
  ///
  /// In en, this message translates to:
  /// **'Remove allergy'**
  String get cardRemoveAllergy;

  /// No description provided for @cardAddDiet.
  ///
  /// In en, this message translates to:
  /// **'Add diet'**
  String get cardAddDiet;

  /// No description provided for @cardRemoveDiet.
  ///
  /// In en, this message translates to:
  /// **'Remove diet'**
  String get cardRemoveDiet;

  /// No description provided for @captionConfirm.
  ///
  /// In en, this message translates to:
  /// **'Check it and tap Save.'**
  String get captionConfirm;

  /// No description provided for @captionIdeas.
  ///
  /// In en, this message translates to:
  /// **'Here are some ideas. Tap one to see the recipe.'**
  String get captionIdeas;

  /// No description provided for @captionIdeasAvoiding.
  ///
  /// In en, this message translates to:
  /// **'Careful: you\'re allergic to or avoid {foods}, so I left it out. Here are recipes without it; tap one to see it.'**
  String captionIdeasAvoiding(String foods);

  /// No description provided for @captionRecipe.
  ///
  /// In en, this message translates to:
  /// **'Here\'s the recipe.'**
  String get captionRecipe;

  /// No description provided for @captionNumbers.
  ///
  /// In en, this message translates to:
  /// **'Here are the numbers.'**
  String get captionNumbers;

  /// No description provided for @captionCamera.
  ///
  /// In en, this message translates to:
  /// **'Tap the button to open the camera.'**
  String get captionCamera;

  /// No description provided for @cardLogSymptom.
  ///
  /// In en, this message translates to:
  /// **'Log symptom'**
  String get cardLogSymptom;

  /// No description provided for @cardLogGlucose.
  ///
  /// In en, this message translates to:
  /// **'Log blood glucose'**
  String get cardLogGlucose;

  /// No description provided for @cardLogBloodPressure.
  ///
  /// In en, this message translates to:
  /// **'Log blood pressure'**
  String get cardLogBloodPressure;

  /// No description provided for @cardLogWater.
  ///
  /// In en, this message translates to:
  /// **'Log water'**
  String get cardLogWater;

  /// No description provided for @last7Days.
  ///
  /// In en, this message translates to:
  /// **'Last 7 days'**
  String get last7Days;

  /// No description provided for @weekReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Your week'**
  String get weekReviewTitle;

  /// No description provided for @reviewLoggedDays.
  ///
  /// In en, this message translates to:
  /// **'You logged food on {days} of 7 days.'**
  String reviewLoggedDays(int days);

  /// No description provided for @reviewKcal.
  ///
  /// In en, this message translates to:
  /// **'On those days: {avg} kcal on average, goal {goal}.'**
  String reviewKcal(int avg, int goal);

  /// No description provided for @reviewUnder.
  ///
  /// In en, this message translates to:
  /// **'{nutrient} under 80 % of your goal on {days} days.'**
  String reviewUnder(String nutrient, int days);

  /// No description provided for @reviewOver.
  ///
  /// In en, this message translates to:
  /// **'{nutrient} over your limit on {days} days.'**
  String reviewOver(String nutrient, int days);

  /// No description provided for @reviewWater.
  ///
  /// In en, this message translates to:
  /// **'Water: {avg} ml a day, goal {goal} ml.'**
  String reviewWater(int avg, int goal);

  /// No description provided for @reviewTop.
  ///
  /// In en, this message translates to:
  /// **'Logged most: {food}.'**
  String reviewTop(String food);

  /// No description provided for @reviewIdeas.
  ///
  /// In en, this message translates to:
  /// **'Ideas for next week'**
  String get reviewIdeas;

  /// No description provided for @reviewAskHigh.
  ///
  /// In en, this message translates to:
  /// **'Suggest recipes high in {nutrient}'**
  String reviewAskHigh(String nutrient);

  /// No description provided for @reviewAskLow.
  ///
  /// In en, this message translates to:
  /// **'Suggest recipes low in {nutrient}'**
  String reviewAskLow(String nutrient);

  /// No description provided for @calcium.
  ///
  /// In en, this message translates to:
  /// **'Calcium'**
  String get calcium;

  /// No description provided for @iron.
  ///
  /// In en, this message translates to:
  /// **'Iron'**
  String get iron;

  /// No description provided for @magnesium.
  ///
  /// In en, this message translates to:
  /// **'Magnesium'**
  String get magnesium;

  /// No description provided for @potassium.
  ///
  /// In en, this message translates to:
  /// **'Potassium'**
  String get potassium;

  /// No description provided for @vitaminC.
  ///
  /// In en, this message translates to:
  /// **'Vitamin C'**
  String get vitaminC;

  /// No description provided for @vitaminD.
  ///
  /// In en, this message translates to:
  /// **'Vitamin D'**
  String get vitaminD;

  /// No description provided for @vitaminB12.
  ///
  /// In en, this message translates to:
  /// **'Vitamin B12'**
  String get vitaminB12;

  /// No description provided for @microsTitle.
  ///
  /// In en, this message translates to:
  /// **'Vitamins and minerals'**
  String get microsTitle;

  /// No description provided for @microsCoverage.
  ///
  /// In en, this message translates to:
  /// **'From {known} of {meals} meals with known values; EU reference intakes'**
  String microsCoverage(int known, int meals);

  /// No description provided for @productsTitle.
  ///
  /// In en, this message translates to:
  /// **'Packaged products'**
  String get productsTitle;

  /// No description provided for @productsNone.
  ///
  /// In en, this message translates to:
  /// **'Built in: products from 2019, few European ones. Download every product in Open Food Facts (all countries) to find what you buy. Wi-Fi recommended.'**
  String get productsNone;

  /// No description provided for @productsHave.
  ///
  /// In en, this message translates to:
  /// **'{count} products from Open Food Facts, updated {date}.'**
  String productsHave(String count, String date);

  /// No description provided for @productsDownload.
  ///
  /// In en, this message translates to:
  /// **'Download ({mb} MB)'**
  String productsDownload(int mb);

  /// No description provided for @productsRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get productsRemove;

  /// No description provided for @productsHint.
  ///
  /// In en, this message translates to:
  /// **'Missing a packaged product? Download all products in Me.'**
  String get productsHint;

  /// No description provided for @healthConnect.
  ///
  /// In en, this message translates to:
  /// **'Health Connect'**
  String get healthConnect;

  /// No description provided for @appleHealth.
  ///
  /// In en, this message translates to:
  /// **'Apple Health'**
  String get appleHealth;

  /// No description provided for @healthSyncHint.
  ///
  /// In en, this message translates to:
  /// **'Reads your weight (for your goals), steps and burnt calories (shown on Today). Nothing is written there and nothing leaves your phone. Turn off to disconnect.'**
  String get healthSyncHint;

  /// No description provided for @healthSyncDenied.
  ///
  /// In en, this message translates to:
  /// **'No access. Allow weight, steps and active calories in the health app\'s settings, then try again.'**
  String get healthSyncDenied;

  /// No description provided for @stepsToday.
  ///
  /// In en, this message translates to:
  /// **'{steps} steps today'**
  String stepsToday(String steps);

  /// No description provided for @mealPlan.
  ///
  /// In en, this message translates to:
  /// **'Meal plan'**
  String get mealPlan;

  /// No description provided for @planTab.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get planTab;

  /// No description provided for @planWeek.
  ///
  /// In en, this message translates to:
  /// **'Plan my week'**
  String get planWeek;

  /// No description provided for @planAgain.
  ///
  /// In en, this message translates to:
  /// **'Plan again'**
  String get planAgain;

  /// No description provided for @planSwap.
  ///
  /// In en, this message translates to:
  /// **'Another recipe'**
  String get planSwap;

  /// No description provided for @planCardEmpty.
  ///
  /// In en, this message translates to:
  /// **'Plan your week and get a shopping list'**
  String get planCardEmpty;

  /// No description provided for @makeShoppingList.
  ///
  /// In en, this message translates to:
  /// **'Shopping list'**
  String get makeShoppingList;

  /// No description provided for @shoppingList.
  ///
  /// In en, this message translates to:
  /// **'Shopping'**
  String get shoppingList;

  /// No description provided for @shoppingAdd.
  ///
  /// In en, this message translates to:
  /// **'Add an item'**
  String get shoppingAdd;

  /// No description provided for @shoppingEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing to buy. Make a list from your plan, or add a recipe\'s ingredients from the recipe.'**
  String get shoppingEmpty;

  /// No description provided for @clearTicked.
  ///
  /// In en, this message translates to:
  /// **'Clear ticked'**
  String get clearTicked;

  /// No description provided for @addToShopping.
  ///
  /// In en, this message translates to:
  /// **'Add to shopping list'**
  String get addToShopping;

  /// No description provided for @addedToShopping.
  ///
  /// In en, this message translates to:
  /// **'Added to the shopping list'**
  String get addedToShopping;

  /// No description provided for @waterLine.
  ///
  /// In en, this message translates to:
  /// **'Water {ml} / {goal} ml'**
  String waterLine(int ml, int goal);

  /// No description provided for @waterAddGlass.
  ///
  /// In en, this message translates to:
  /// **'Add a glass (250 ml)'**
  String get waterAddGlass;

  /// No description provided for @waterUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo the last glass'**
  String get waterUndo;

  /// No description provided for @waterGoal.
  ///
  /// In en, this message translates to:
  /// **'Daily water goal'**
  String get waterGoal;

  /// No description provided for @fasting.
  ///
  /// In en, this message translates to:
  /// **'Fasting'**
  String get fasting;

  /// No description provided for @fastingLine.
  ///
  /// In en, this message translates to:
  /// **'Fasting {h} h {m} min of {target} h'**
  String fastingLine(int h, int m, int target);

  /// No description provided for @fastStart.
  ///
  /// In en, this message translates to:
  /// **'Start now'**
  String get fastStart;

  /// No description provided for @fastSinceMeal.
  ///
  /// In en, this message translates to:
  /// **'Since last meal ({time})'**
  String fastSinceMeal(String time);

  /// No description provided for @fastEnd.
  ///
  /// In en, this message translates to:
  /// **'End fast'**
  String get fastEnd;

  /// No description provided for @fastDone.
  ///
  /// In en, this message translates to:
  /// **'Goal reached. End the fast whenever you eat.'**
  String get fastDone;

  /// No description provided for @fastingSwitch.
  ///
  /// In en, this message translates to:
  /// **'Fasting timer'**
  String get fastingSwitch;

  /// No description provided for @fastingCaution.
  ///
  /// In en, this message translates to:
  /// **'Not advised in pregnancy, with an eating disorder, or with diabetes treated with insulin or sulfonylureas. Ask your doctor first.'**
  String get fastingCaution;

  /// No description provided for @widgetKcalTitle.
  ///
  /// In en, this message translates to:
  /// **'Calories on the home-screen widget'**
  String get widgetKcalTitle;

  /// No description provided for @widgetKcalHint.
  ///
  /// In en, this message translates to:
  /// **'Add the My Nutrition AI widget to your home screen. Today\'s calories are then visible there without your PIN.'**
  String get widgetKcalHint;

  /// No description provided for @welcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Log your first meal'**
  String get welcomeTitle;

  /// No description provided for @nextMealTitle.
  ///
  /// In en, this message translates to:
  /// **'No {meal} logged yet'**
  String nextMealTitle(String meal);

  /// No description provided for @nextMealBody.
  ///
  /// In en, this message translates to:
  /// **'Log what you had, or get an idea for what to eat.'**
  String get nextMealBody;

  /// No description provided for @getIdea.
  ///
  /// In en, this message translates to:
  /// **'Get an idea'**
  String get getIdea;

  /// No description provided for @logIt.
  ///
  /// In en, this message translates to:
  /// **'Log it'**
  String get logIt;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @wallpaperColors.
  ///
  /// In en, this message translates to:
  /// **'Wallpaper colours'**
  String get wallpaperColors;

  /// No description provided for @wallpaperColorsHint.
  ///
  /// In en, this message translates to:
  /// **'Use your phone\'s colours (Android 12 and newer).'**
  String get wallpaperColorsHint;

  /// No description provided for @suggestAte.
  ///
  /// In en, this message translates to:
  /// **'I ate {food}'**
  String suggestAte(String food);

  /// No description provided for @suggestIdea.
  ///
  /// In en, this message translates to:
  /// **'Something new for {meal}'**
  String suggestIdea(String meal);

  /// No description provided for @suggestLeft.
  ///
  /// In en, this message translates to:
  /// **'What\'s left for today?'**
  String get suggestLeft;

  /// No description provided for @rateStars.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Rate 1 star} other{Rate {count} stars}}'**
  String rateStars(int count);

  /// No description provided for @recipesYouAte.
  ///
  /// In en, this message translates to:
  /// **'Recipes you ate'**
  String get recipesYouAte;

  /// No description provided for @recipesYouAteHint.
  ///
  /// In en, this message translates to:
  /// **'Tap one to see it again and rate it. Recipe ideas follow your stars.'**
  String get recipesYouAteHint;

  /// No description provided for @cookNone.
  ///
  /// In en, this message translates to:
  /// **'No recipe in the database uses these foods.'**
  String get cookNone;

  /// No description provided for @per100Suffix.
  ///
  /// In en, this message translates to:
  /// **' / 100 g'**
  String get per100Suffix;

  /// No description provided for @aiDownloadTitle.
  ///
  /// In en, this message translates to:
  /// **'Download the AI assistant'**
  String get aiDownloadTitle;

  /// No description provided for @aiDownloadBody.
  ///
  /// In en, this message translates to:
  /// **'The chat assistant runs entirely on your phone. Its model ({gb} GB) downloads once from Hugging Face; use Wi-Fi. Nothing about you is sent. Logging, recipes and your dashboard already work without it.'**
  String aiDownloadBody(String gb);

  /// No description provided for @aiDownloadButton.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get aiDownloadButton;

  /// No description provided for @aiModelTitle.
  ///
  /// In en, this message translates to:
  /// **'AI model'**
  String get aiModelTitle;

  /// No description provided for @aiModelStandard.
  ///
  /// In en, this message translates to:
  /// **'Standard · {gb} GB'**
  String aiModelStandard(String gb);

  /// No description provided for @aiModelStandardHint.
  ///
  /// In en, this message translates to:
  /// **'Faster answers. Works on every supported phone.'**
  String get aiModelStandardHint;

  /// No description provided for @aiModelLarge.
  ///
  /// In en, this message translates to:
  /// **'Larger · {gb} GB'**
  String aiModelLarge(String gb);

  /// No description provided for @aiModelLargeHint.
  ///
  /// In en, this message translates to:
  /// **'Understands more and recognises food on photos better; answers about 2-3x slower. For phones with 12 GB RAM.'**
  String get aiModelLargeHint;

  /// No description provided for @aiModelSwitch.
  ///
  /// In en, this message translates to:
  /// **'Switch'**
  String get aiModelSwitch;

  /// No description provided for @aiModelSwitchBody.
  ///
  /// In en, this message translates to:
  /// **'The other model downloads first; the current one is deleted when it\'s done.'**
  String get aiModelSwitchBody;

  /// No description provided for @aiModelInUse.
  ///
  /// In en, this message translates to:
  /// **'In use'**
  String get aiModelInUse;

  /// No description provided for @aiDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading'**
  String get aiDownloading;

  /// No description provided for @aiDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'The download stopped. Check your connection and free space, then try again; it continues where it stopped.'**
  String get aiDownloadFailed;

  /// No description provided for @downloadNoWifiTitle.
  ///
  /// In en, this message translates to:
  /// **'Not on Wi-Fi'**
  String get downloadNoWifiTitle;

  /// No description provided for @downloadNoWifiBody.
  ///
  /// In en, this message translates to:
  /// **'You are not connected to Wi-Fi. This download is {mb} MB; over mobile data it can use up your data plan or cost money.'**
  String downloadNoWifiBody(int mb);

  /// No description provided for @downloadWaitWifi.
  ///
  /// In en, this message translates to:
  /// **'Wait for Wi-Fi'**
  String get downloadWaitWifi;

  /// No description provided for @downloadUseMobile.
  ///
  /// In en, this message translates to:
  /// **'Use mobile data'**
  String get downloadUseMobile;

  /// No description provided for @downloadOnMobile.
  ///
  /// In en, this message translates to:
  /// **'Mobile data allowed: this download can use your data plan.'**
  String get downloadOnMobile;

  /// No description provided for @downloadWaitingWifi.
  ///
  /// In en, this message translates to:
  /// **'Waiting for Wi-Fi'**
  String get downloadWaitingWifi;

  /// No description provided for @downloadWaitingNetwork.
  ///
  /// In en, this message translates to:
  /// **'Waiting for a connection'**
  String get downloadWaitingNetwork;

  /// No description provided for @downloadRetrying.
  ///
  /// In en, this message translates to:
  /// **'Connection lost; it continues when it\'s back'**
  String get downloadRetrying;

  /// No description provided for @downloadPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get downloadPaused;

  /// No description provided for @downloadInstalling.
  ///
  /// In en, this message translates to:
  /// **'Installing…'**
  String get downloadInstalling;

  /// No description provided for @downloadPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get downloadPause;

  /// No description provided for @downloadResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get downloadResume;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get privacyPolicy;

  /// No description provided for @termsOfUse.
  ///
  /// In en, this message translates to:
  /// **'Terms of use'**
  String get termsOfUse;

  /// No description provided for @licenses.
  ///
  /// In en, this message translates to:
  /// **'Licenses and AI models'**
  String get licenses;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @drawerFood.
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get drawerFood;

  /// No description provided for @drawerAssistant.
  ///
  /// In en, this message translates to:
  /// **'Assistant'**
  String get drawerAssistant;

  /// No description provided for @shoppingListNav.
  ///
  /// In en, this message translates to:
  /// **'Shopping list'**
  String get shoppingListNav;

  /// No description provided for @healthJournalNav.
  ///
  /// In en, this message translates to:
  /// **'Health journal and report'**
  String get healthJournalNav;

  /// No description provided for @settingsAi.
  ///
  /// In en, this message translates to:
  /// **'AI and data'**
  String get settingsAi;

  /// No description provided for @settingsTracking.
  ///
  /// In en, this message translates to:
  /// **'Tracking'**
  String get settingsTracking;

  /// No description provided for @settingsPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy and security'**
  String get settingsPrivacy;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @settingsDanger.
  ///
  /// In en, this message translates to:
  /// **'Danger zone'**
  String get settingsDanger;

  /// No description provided for @deleteThisProfile.
  ///
  /// In en, this message translates to:
  /// **'Delete this profile'**
  String get deleteThisProfile;

  /// No description provided for @deleteThisProfileBody.
  ///
  /// In en, this message translates to:
  /// **'This removes the profile and all its meals, journal and chat history from this phone. This can\'t be undone.'**
  String get deleteThisProfileBody;

  /// No description provided for @featBasic2.
  ///
  /// In en, this message translates to:
  /// **'Meal plan and shopping list'**
  String get featBasic2;

  /// No description provided for @featBasic4.
  ///
  /// In en, this message translates to:
  /// **'3 months of history'**
  String get featBasic4;

  /// No description provided for @featMedium4.
  ///
  /// In en, this message translates to:
  /// **'8 months of history'**
  String get featMedium4;

  /// No description provided for @featPro4.
  ///
  /// In en, this message translates to:
  /// **'Year dashboard and 12 months of history'**
  String get featPro4;

  /// No description provided for @periodYear.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get periodYear;

  /// No description provided for @yearLockedTitle.
  ///
  /// In en, this message translates to:
  /// **'The Year view is in Pro'**
  String get yearLockedTitle;

  /// No description provided for @yearLockedBody.
  ///
  /// In en, this message translates to:
  /// **'Twelve months at a glance: calories per month, a logging calendar, nutrient averages with your best and worst months, your weight and what you ate most.'**
  String get yearLockedBody;

  /// No description provided for @yearCalories.
  ///
  /// In en, this message translates to:
  /// **'Calories per day, monthly average'**
  String get yearCalories;

  /// No description provided for @yearCalendar.
  ///
  /// In en, this message translates to:
  /// **'Logging calendar'**
  String get yearCalendar;

  /// No description provided for @yearLoggedDays.
  ///
  /// In en, this message translates to:
  /// **'{days} days logged · best streak {best} days'**
  String yearLoggedDays(int days, int best);

  /// No description provided for @yearNutrients.
  ///
  /// In en, this message translates to:
  /// **'Daily averages this year'**
  String get yearNutrients;

  /// No description provided for @yearBestWorst.
  ///
  /// In en, this message translates to:
  /// **'{nutrient}: best month {best}, worst {worst}'**
  String yearBestWorst(String nutrient, String best, String worst);

  /// No description provided for @yearTopFoods.
  ///
  /// In en, this message translates to:
  /// **'Eaten most'**
  String get yearTopFoods;

  /// No description provided for @calendarOnGoal.
  ///
  /// In en, this message translates to:
  /// **'Within 10% of goal'**
  String get calendarOnGoal;

  /// No description provided for @calendarNear.
  ///
  /// In en, this message translates to:
  /// **'Within 25%'**
  String get calendarNear;

  /// No description provided for @calendarFar.
  ///
  /// In en, this message translates to:
  /// **'Further off'**
  String get calendarFar;

  /// No description provided for @calendarNotLogged.
  ///
  /// In en, this message translates to:
  /// **'Not logged'**
  String get calendarNotLogged;

  /// No description provided for @historyTitle.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get historyTitle;

  /// No description provided for @lastDays.
  ///
  /// In en, this message translates to:
  /// **'Last {count} days'**
  String lastDays(int count);

  /// No description provided for @pickDates.
  ///
  /// In en, this message translates to:
  /// **'Pick dates'**
  String get pickDates;

  /// No description provided for @historyEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing logged on these days.'**
  String get historyEmpty;

  /// No description provided for @historyLockedTitle.
  ///
  /// In en, this message translates to:
  /// **'History shows the last {days} days'**
  String historyLockedTitle(int days);

  /// No description provided for @historyLockedBody.
  ///
  /// In en, this message translates to:
  /// **'Older meals stay on your phone. Basic shows 3 months, Medium 8 and Pro 12.'**
  String get historyLockedBody;

  /// No description provided for @planLockedTitle.
  ///
  /// In en, this message translates to:
  /// **'The meal plan is in Basic'**
  String get planLockedTitle;

  /// No description provided for @planLockedBody.
  ///
  /// In en, this message translates to:
  /// **'Plan your week from recipes that fit your goals and allergens, and turn it into a shopping list.'**
  String get planLockedBody;

  /// No description provided for @reminderWater.
  ///
  /// In en, this message translates to:
  /// **'Drink water'**
  String get reminderWater;

  /// No description provided for @reminderWaterHint.
  ///
  /// In en, this message translates to:
  /// **'{count} a day, {from}–{to}: one glass each to reach your water goal'**
  String reminderWaterHint(int count, String from, String to);

  /// No description provided for @reminderWaterLocked.
  ///
  /// In en, this message translates to:
  /// **'Water reminders are in Basic'**
  String get reminderWaterLocked;

  /// No description provided for @notifWater.
  ///
  /// In en, this message translates to:
  /// **'{name}, time for a glass of water.'**
  String notifWater(String name);

  /// No description provided for @machineTranslated.
  ///
  /// In en, this message translates to:
  /// **'Ingredient names machine-translated'**
  String get machineTranslated;

  /// No description provided for @translateSteps.
  ///
  /// In en, this message translates to:
  /// **'Translate steps'**
  String get translateSteps;

  /// No description provided for @machineTranslatedSteps.
  ///
  /// In en, this message translates to:
  /// **'Steps machine-translated on your phone'**
  String get machineTranslatedSteps;

  /// No description provided for @showOriginal.
  ///
  /// In en, this message translates to:
  /// **'Show original'**
  String get showOriginal;

  /// No description provided for @showTranslation.
  ///
  /// In en, this message translates to:
  /// **'Show translation'**
  String get showTranslation;

  /// No description provided for @translateBusy.
  ///
  /// In en, this message translates to:
  /// **'The assistant is busy. Try again in a moment.'**
  String get translateBusy;

  /// No description provided for @translateFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t translate the steps. Please try again.'**
  String get translateFailed;

  /// No description provided for @translateNeedsAi.
  ///
  /// In en, this message translates to:
  /// **'Translating needs the AI model (see the Chat tab).'**
  String get translateNeedsAi;

  /// No description provided for @tabPlan.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get tabPlan;

  /// No description provided for @trendWeight.
  ///
  /// In en, this message translates to:
  /// **'Trend weight'**
  String get trendWeight;

  /// No description provided for @weightChangeIn.
  ///
  /// In en, this message translates to:
  /// **'{change} in {days} days'**
  String weightChangeIn(String change, int days);

  /// No description provided for @rangeMonths.
  ///
  /// In en, this message translates to:
  /// **'{n}M'**
  String rangeMonths(int n);

  /// No description provided for @rangeYear.
  ///
  /// In en, this message translates to:
  /// **'1Y'**
  String get rangeYear;

  /// No description provided for @legendScale.
  ///
  /// In en, this message translates to:
  /// **'Scale'**
  String get legendScale;

  /// No description provided for @legendTrend.
  ///
  /// In en, this message translates to:
  /// **'Trend'**
  String get legendTrend;

  /// No description provided for @perWeek.
  ///
  /// In en, this message translates to:
  /// **'{unit} per week'**
  String perWeek(String unit);

  /// No description provided for @latestScale.
  ///
  /// In en, this message translates to:
  /// **'Latest on the scale'**
  String get latestScale;

  /// No description provided for @weightTrendNote.
  ///
  /// In en, this message translates to:
  /// **'The trend smooths out daily water swings, so one heavy morning is not mistaken for a real change.'**
  String get weightTrendNote;

  /// No description provided for @weightChartLabel.
  ///
  /// In en, this message translates to:
  /// **'Weight, {n} readings, trend from {from} to {to}'**
  String weightChartLabel(int n, String from, String to);

  /// No description provided for @addShort.
  ///
  /// In en, this message translates to:
  /// **'+ Add'**
  String get addShort;

  /// No description provided for @calories.
  ///
  /// In en, this message translates to:
  /// **'Calories'**
  String get calories;

  /// No description provided for @cook.
  ///
  /// In en, this message translates to:
  /// **'Cook'**
  String get cook;

  /// No description provided for @eatenWord.
  ///
  /// In en, this message translates to:
  /// **'Eaten'**
  String get eatenWord;

  /// No description provided for @leftWord.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get leftWord;

  /// No description provided for @kcalLeftShort.
  ///
  /// In en, this message translates to:
  /// **'kcal left'**
  String get kcalLeftShort;

  /// No description provided for @kcalOverShort.
  ///
  /// In en, this message translates to:
  /// **'kcal over'**
  String get kcalOverShort;

  /// No description provided for @fastNotRunning.
  ///
  /// In en, this message translates to:
  /// **'Not fasting'**
  String get fastNotRunning;

  /// No description provided for @fromYourPlan.
  ///
  /// In en, this message translates to:
  /// **'from your plan'**
  String get fromYourPlan;

  /// No description provided for @glassAdded.
  ///
  /// In en, this message translates to:
  /// **'Glass of water added'**
  String get glassAdded;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @water.
  ///
  /// In en, this message translates to:
  /// **'Water'**
  String get water;

  /// No description provided for @litreUnit.
  ///
  /// In en, this message translates to:
  /// **'L'**
  String get litreUnit;

  /// No description provided for @yourWeek.
  ///
  /// In en, this message translates to:
  /// **'Your week'**
  String get yourWeek;

  /// No description provided for @yourMonth.
  ///
  /// In en, this message translates to:
  /// **'Your month'**
  String get yourMonth;

  /// No description provided for @yourYear.
  ///
  /// In en, this message translates to:
  /// **'Your year'**
  String get yourYear;

  /// No description provided for @addToMeal.
  ///
  /// In en, this message translates to:
  /// **'Add to {meal}'**
  String addToMeal(String meal);

  /// No description provided for @fastGoalHours.
  ///
  /// In en, this message translates to:
  /// **'{hours} h goal'**
  String fastGoalHours(int hours);

  /// No description provided for @fitsLeft.
  ///
  /// In en, this message translates to:
  /// **'fits your {amount} left'**
  String fitsLeft(String amount);

  /// No description provided for @hoursMinutes.
  ///
  /// In en, this message translates to:
  /// **'{h} h {m} min'**
  String hoursMinutes(int h, int m);

  /// No description provided for @minutesShort.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String minutesShort(int minutes);

  /// No description provided for @kindAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get kindAll;

  /// No description provided for @lessServing.
  ///
  /// In en, this message translates to:
  /// **'Half a serving less'**
  String get lessServing;

  /// No description provided for @moreServing.
  ///
  /// In en, this message translates to:
  /// **'Half a serving more'**
  String get moreServing;

  /// No description provided for @logFoodTitle.
  ///
  /// In en, this message translates to:
  /// **'Log food'**
  String get logFoodTitle;

  /// No description provided for @snapPhoto.
  ///
  /// In en, this message translates to:
  /// **'Snap a photo'**
  String get snapPhoto;

  /// No description provided for @servingsAmount.
  ///
  /// In en, this message translates to:
  /// **'{amount} × serving'**
  String servingsAmount(String amount);

  /// No description provided for @yesterdaysMeal.
  ///
  /// In en, this message translates to:
  /// **'Yesterday\'s {meal}'**
  String yesterdaysMeal(String meal);

  /// No description provided for @assistantTitle.
  ///
  /// In en, this message translates to:
  /// **'Assistant'**
  String get assistantTitle;

  /// No description provided for @openRecipe.
  ///
  /// In en, this message translates to:
  /// **'Open recipe'**
  String get openRecipe;

  /// No description provided for @runsOnPhone.
  ///
  /// In en, this message translates to:
  /// **'Runs on this phone · nothing leaves it'**
  String get runsOnPhone;

  /// No description provided for @gramsProtein.
  ///
  /// In en, this message translates to:
  /// **'{n} g protein'**
  String gramsProtein(int n);

  /// No description provided for @messagesLeft.
  ///
  /// In en, this message translates to:
  /// **'{n} of {total} left today'**
  String messagesLeft(int n, int total);

  /// No description provided for @addedToPlan.
  ///
  /// In en, this message translates to:
  /// **'Added to your plan'**
  String get addedToPlan;

  /// No description provided for @addToPlan.
  ///
  /// In en, this message translates to:
  /// **'Add to plan'**
  String get addToPlan;

  /// No description provided for @addToShoppingShort.
  ///
  /// In en, this message translates to:
  /// **'+ Add to shopping'**
  String get addToShoppingShort;

  /// No description provided for @aisleProduce.
  ///
  /// In en, this message translates to:
  /// **'Fruit and vegetables'**
  String get aisleProduce;

  /// No description provided for @aisleMeatFish.
  ///
  /// In en, this message translates to:
  /// **'Meat and fish'**
  String get aisleMeatFish;

  /// No description provided for @aisleDairyEggs.
  ///
  /// In en, this message translates to:
  /// **'Dairy and eggs'**
  String get aisleDairyEggs;

  /// No description provided for @aisleBakery.
  ///
  /// In en, this message translates to:
  /// **'Bakery'**
  String get aisleBakery;

  /// No description provided for @aislePantry.
  ///
  /// In en, this message translates to:
  /// **'Pantry'**
  String get aislePantry;

  /// No description provided for @aisleSpices.
  ///
  /// In en, this message translates to:
  /// **'Spices'**
  String get aisleSpices;

  /// No description provided for @aisleFrozen.
  ///
  /// In en, this message translates to:
  /// **'Frozen'**
  String get aisleFrozen;

  /// No description provided for @aisleDrinks.
  ///
  /// In en, this message translates to:
  /// **'Drinks'**
  String get aisleDrinks;

  /// No description provided for @aisleOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get aisleOther;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @boxEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet. Save a recipe with its bookmark, or search above.'**
  String get boxEmpty;

  /// No description provided for @boxFootnote.
  ///
  /// In en, this message translates to:
  /// **'Recipes with your allergens never appear here. Ideas follow your stars.'**
  String get boxFootnote;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @doneCooking.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get doneCooking;

  /// No description provided for @fewerServings.
  ///
  /// In en, this message translates to:
  /// **'Fewer servings'**
  String get fewerServings;

  /// No description provided for @moreServings.
  ///
  /// In en, this message translates to:
  /// **'More servings'**
  String get moreServings;

  /// No description provided for @findRecipes.
  ///
  /// In en, this message translates to:
  /// **'Find recipes'**
  String get findRecipes;

  /// No description provided for @forThisStep.
  ///
  /// In en, this message translates to:
  /// **'For this step'**
  String get forThisStep;

  /// No description provided for @fridgeHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. eggs, spinach, feta'**
  String get fridgeHint;

  /// No description provided for @logServing.
  ///
  /// In en, this message translates to:
  /// **'Log a serving'**
  String get logServing;

  /// No description provided for @nextStep.
  ///
  /// In en, this message translates to:
  /// **'Next step'**
  String get nextStep;

  /// No description provided for @noSteps.
  ///
  /// In en, this message translates to:
  /// **'This recipe has no steps.'**
  String get noSteps;

  /// No description provided for @recipesTitle.
  ///
  /// In en, this message translates to:
  /// **'Recipes'**
  String get recipesTitle;

  /// No description provided for @removeSaved.
  ///
  /// In en, this message translates to:
  /// **'Remove from saved'**
  String get removeSaved;

  /// No description provided for @savedLabel.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get savedLabel;

  /// No description provided for @searchRecipes.
  ///
  /// In en, this message translates to:
  /// **'Search 166,000 recipes…'**
  String get searchRecipes;

  /// No description provided for @servingsLabel.
  ///
  /// In en, this message translates to:
  /// **'Servings'**
  String get servingsLabel;

  /// No description provided for @servingsHint.
  ///
  /// In en, this message translates to:
  /// **'Amounts and nutrition update'**
  String get servingsHint;

  /// No description provided for @shelfCooked.
  ///
  /// In en, this message translates to:
  /// **'Cooked'**
  String get shelfCooked;

  /// No description provided for @shelfLoved.
  ///
  /// In en, this message translates to:
  /// **'4★ and up'**
  String get shelfLoved;

  /// No description provided for @shelfQuick.
  ///
  /// In en, this message translates to:
  /// **'≤ 30 min'**
  String get shelfQuick;

  /// No description provided for @startCooking.
  ///
  /// In en, this message translates to:
  /// **'Start cooking'**
  String get startCooking;

  /// No description provided for @thisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get thisWeek;

  /// No description provided for @timerDone.
  ///
  /// In en, this message translates to:
  /// **'Time\'s up'**
  String get timerDone;

  /// No description provided for @whatCanICook.
  ///
  /// In en, this message translates to:
  /// **'What can I cook?'**
  String get whatCanICook;

  /// No description provided for @whatCanICookBody.
  ///
  /// In en, this message translates to:
  /// **'Say or snap what\'s in your fridge'**
  String get whatCanICookBody;

  /// No description provided for @allergensLeftOut.
  ///
  /// In en, this message translates to:
  /// **'{list} are left out: they\'re on your allergy list.'**
  String allergensLeftOut(String list);

  /// No description provided for @clearTickedN.
  ///
  /// In en, this message translates to:
  /// **'Clear ticked ({n})'**
  String clearTickedN(int n);

  /// No description provided for @cookedTimes.
  ///
  /// In en, this message translates to:
  /// **'cooked {n}×'**
  String cookedTimes(int n);

  /// No description provided for @cookSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Screen stays on · {servings} servings'**
  String cookSubtitle(int servings);

  /// No description provided for @forRecipe.
  ///
  /// In en, this message translates to:
  /// **'For: {title}'**
  String forRecipe(String title);

  /// No description provided for @ideasFor.
  ///
  /// In en, this message translates to:
  /// **'Ideas for: {list}'**
  String ideasFor(String list);

  /// No description provided for @itemsLeft.
  ///
  /// In en, this message translates to:
  /// **'{n} of {total} left'**
  String itemsLeft(int n, int total);

  /// No description provided for @plannedFor.
  ///
  /// In en, this message translates to:
  /// **'Planned for {day}'**
  String plannedFor(String day);

  /// No description provided for @planOfKcal.
  ///
  /// In en, this message translates to:
  /// **'{n} of {total} kcal'**
  String planOfKcal(int n, int total);

  /// No description provided for @roomForSnack.
  ///
  /// In en, this message translates to:
  /// **'Room for a {kcal} kcal snack.'**
  String roomForSnack(int kcal);

  /// No description provided for @shelfSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved · {n}'**
  String shelfSaved(int n);

  /// No description provided for @shoppingTabCount.
  ///
  /// In en, this message translates to:
  /// **'Shopping · {n}'**
  String shoppingTabCount(int n);

  /// No description provided for @startTimer.
  ///
  /// In en, this message translates to:
  /// **'Start {time} timer'**
  String startTimer(String time);

  /// No description provided for @stepOf.
  ///
  /// In en, this message translates to:
  /// **'Step {step} of {steps}'**
  String stepOf(int step, int steps);

  /// No description provided for @timerRunning.
  ///
  /// In en, this message translates to:
  /// **'{time} · tap to stop'**
  String timerRunning(String time);

  /// No description provided for @youRated.
  ///
  /// In en, this message translates to:
  /// **'you rated {stars}'**
  String youRated(int stars);

  /// No description provided for @changePin.
  ///
  /// In en, this message translates to:
  /// **'Change PIN'**
  String get changePin;

  /// No description provided for @currentPin.
  ///
  /// In en, this message translates to:
  /// **'Current PIN'**
  String get currentPin;

  /// No description provided for @pinChanged.
  ///
  /// In en, this message translates to:
  /// **'PIN changed'**
  String get pinChanged;

  /// No description provided for @dailyTargets.
  ///
  /// In en, this message translates to:
  /// **'Daily targets'**
  String get dailyTargets;

  /// No description provided for @tapToOverride.
  ///
  /// In en, this message translates to:
  /// **'Tap to override'**
  String get tapToOverride;

  /// No description provided for @googleAccount.
  ///
  /// In en, this message translates to:
  /// **'Google account'**
  String get googleAccount;

  /// No description provided for @googleNotLinked.
  ///
  /// In en, this message translates to:
  /// **'Not linked: PIN and fingerprint only'**
  String get googleNotLinked;

  /// No description provided for @googleLinked.
  ///
  /// In en, this message translates to:
  /// **'{email} · name only'**
  String googleLinked(String email);

  /// No description provided for @historyAndYear.
  ///
  /// In en, this message translates to:
  /// **'History and Year view'**
  String get historyAndYear;

  /// No description provided for @limitShort.
  ///
  /// In en, this message translates to:
  /// **'max'**
  String get limitShort;

  /// No description provided for @link.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get link;

  /// No description provided for @unlink.
  ///
  /// In en, this message translates to:
  /// **'Unlink'**
  String get unlink;

  /// No description provided for @lookAndLanguage.
  ///
  /// In en, this message translates to:
  /// **'Look and language'**
  String get lookAndLanguage;

  /// No description provided for @onDeviceAiAndData.
  ///
  /// In en, this message translates to:
  /// **'On-device AI and data'**
  String get onDeviceAiAndData;

  /// No description provided for @savedRecipesTitle.
  ///
  /// In en, this message translates to:
  /// **'Saved recipes'**
  String get savedRecipesTitle;

  /// No description provided for @bornIn.
  ///
  /// In en, this message translates to:
  /// **'born {year}'**
  String bornIn(int year);

  /// No description provided for @planChip.
  ///
  /// In en, this message translates to:
  /// **'{tier} plan · See plans'**
  String planChip(String tier);

  /// No description provided for @addAllergyTitle.
  ///
  /// In en, this message translates to:
  /// **'Add an allergy or diet'**
  String get addAllergyTitle;

  /// No description provided for @addAllergyHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. peanuts, gluten, vegetarian'**
  String get addAllergyHint;

  /// No description provided for @allergyUnknown.
  ///
  /// In en, this message translates to:
  /// **'\"{text}\" isn\'t an allergen or diet the app can filter. Try peanuts, tree nuts, milk, egg, gluten, shellfish, fish, soy, sesame, vegetarian, vegan or pescatarian.'**
  String allergyUnknown(String text);

  /// No description provided for @continueButton.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueButton;

  /// No description provided for @dataLocked.
  ///
  /// In en, this message translates to:
  /// **'Your data is locked on this phone.'**
  String get dataLocked;

  /// No description provided for @firstRunNext.
  ///
  /// In en, this message translates to:
  /// **'Next: a PIN or fingerprint, then your goals.'**
  String get firstRunNext;

  /// No description provided for @googleOnlyName.
  ///
  /// In en, this message translates to:
  /// **'Google only fills in your name.'**
  String get googleOnlyName;

  /// No description provided for @lockItTitle.
  ///
  /// In en, this message translates to:
  /// **'Lock it to you'**
  String get lockItTitle;

  /// No description provided for @nameExample.
  ///
  /// In en, this message translates to:
  /// **'e.g. Sam'**
  String get nameExample;

  /// No description provided for @recordsNotInterprets.
  ///
  /// In en, this message translates to:
  /// **'The app records what you enter and never interprets it. General information from published guidelines, not medical advice.'**
  String get recordsNotInterprets;

  /// No description provided for @recordTitle.
  ///
  /// In en, this message translates to:
  /// **'Record'**
  String get recordTitle;

  /// No description provided for @reportHintShort.
  ///
  /// In en, this message translates to:
  /// **'PDF and CSV of what you logged'**
  String get reportHintShort;

  /// No description provided for @startTrial.
  ///
  /// In en, this message translates to:
  /// **'Start 7-day free trial'**
  String get startTrial;

  /// No description provided for @touchSensor.
  ///
  /// In en, this message translates to:
  /// **'Touch the sensor to unlock'**
  String get touchSensor;

  /// No description provided for @trialBadge.
  ///
  /// In en, this message translates to:
  /// **'7 DAYS FREE'**
  String get trialBadge;

  /// No description provided for @usePin.
  ///
  /// In en, this message translates to:
  /// **'Use PIN'**
  String get usePin;

  /// No description provided for @welcomeHeadline.
  ///
  /// In en, this message translates to:
  /// **'Eat well, privately'**
  String get welcomeHeadline;

  /// No description provided for @welcomeIntro.
  ///
  /// In en, this message translates to:
  /// **'An AI nutrition assistant that runs on this phone. No cloud AI, no analytics.'**
  String get welcomeIntro;

  /// No description provided for @welcomePointPrivate.
  ///
  /// In en, this message translates to:
  /// **'Your meals and chats never leave the phone'**
  String get welcomePointPrivate;

  /// No description provided for @welcomePointData.
  ///
  /// In en, this message translates to:
  /// **'55,000 foods and 166,000 recipes built in'**
  String get welcomePointData;

  /// No description provided for @welcomePointAllergens.
  ///
  /// In en, this message translates to:
  /// **'Allergens filtered out of every recipe'**
  String get welcomePointAllergens;

  /// No description provided for @yourName.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get yourName;

  /// No description provided for @currentTier.
  ///
  /// In en, this message translates to:
  /// **'Current: {tier}'**
  String currentTier(String tier);

  /// No description provided for @severityN.
  ///
  /// In en, this message translates to:
  /// **'severity {n}'**
  String severityN(int n);

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back, {name}'**
  String welcomeBack(String name);

  /// No description provided for @bestStreak.
  ///
  /// In en, this message translates to:
  /// **'best streak'**
  String get bestStreak;

  /// No description provided for @daysLogged.
  ///
  /// In en, this message translates to:
  /// **'days logged'**
  String get daysLogged;

  /// No description provided for @avgValue.
  ///
  /// In en, this message translates to:
  /// **'avg {value}'**
  String avgValue(String value);

  /// No description provided for @dayLine.
  ///
  /// In en, this message translates to:
  /// **'{amount} kcal · {n} meals'**
  String dayLine(String amount, int n);

  /// No description provided for @sinceMonth.
  ///
  /// In en, this message translates to:
  /// **'since {month}'**
  String sinceMonth(String month);

  /// No description provided for @streakShort.
  ///
  /// In en, this message translates to:
  /// **'{n}-day streak'**
  String streakShort(int n);

  /// No description provided for @estimatedTotal.
  ///
  /// In en, this message translates to:
  /// **'Estimated total'**
  String get estimatedTotal;

  /// No description provided for @logThisMeal.
  ///
  /// In en, this message translates to:
  /// **'Log this {meal}'**
  String logThisMeal(String meal);

  /// No description provided for @activeKcalBurned.
  ///
  /// In en, this message translates to:
  /// **'{kcal} kcal burnt'**
  String activeKcalBurned(String kcal);

  /// No description provided for @weightUpdatedToday.
  ///
  /// In en, this message translates to:
  /// **'Today\'s weight updated.'**
  String get weightUpdatedToday;

  /// No description provided for @historyMeals.
  ///
  /// In en, this message translates to:
  /// **'Meals'**
  String get historyMeals;

  /// No description provided for @historyRecipes.
  ///
  /// In en, this message translates to:
  /// **'Recipes cooked'**
  String get historyRecipes;

  /// No description provided for @historyRecipesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No recipes on these days. When you log a recipe (“I ate this”), it shows up here.'**
  String get historyRecipesEmpty;

  /// No description provided for @lastCooked.
  ///
  /// In en, this message translates to:
  /// **'last {date}'**
  String lastCooked(String date);

  /// No description provided for @removeItem.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removeItem;

  /// No description provided for @seenAs.
  ///
  /// In en, this message translates to:
  /// **'seen: {name}'**
  String seenAs(String name);

  /// No description provided for @confirmUndone.
  ///
  /// In en, this message translates to:
  /// **'Undone'**
  String get confirmUndone;

  /// No description provided for @editOnToday.
  ///
  /// In en, this message translates to:
  /// **'Edit on Today'**
  String get editOnToday;

  /// No description provided for @thinking.
  ///
  /// In en, this message translates to:
  /// **'Thinking…'**
  String get thinking;

  /// No description provided for @searchInsteadInLog.
  ///
  /// In en, this message translates to:
  /// **'Search foods in Log instead'**
  String get searchInsteadInLog;

  /// No description provided for @burntWord.
  ///
  /// In en, this message translates to:
  /// **'Burnt'**
  String get burntWord;

  /// No description provided for @aiCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Get the AI assistant'**
  String get aiCardTitle;

  /// No description provided for @aiCardBody.
  ///
  /// In en, this message translates to:
  /// **'Describe meals in your own words and ask about food. It runs on this phone: one download (a few GB, Wi-Fi recommended). Search and quick add work without it.'**
  String get aiCardBody;

  /// No description provided for @welcomeLog.
  ///
  /// In en, this message translates to:
  /// **'Search it in Log, or quick-add the calories.'**
  String get welcomeLog;

  /// No description provided for @welcomeChat.
  ///
  /// In en, this message translates to:
  /// **'Or type or say it in Chat (\"I had 2 eggs and toast\").'**
  String get welcomeChat;

  /// No description provided for @welcomePhoto.
  ///
  /// In en, this message translates to:
  /// **'Or take a photo of your plate.'**
  String get welcomePhoto;

  /// No description provided for @welcomeEnd.
  ///
  /// In en, this message translates to:
  /// **'Your day fills in here.'**
  String get welcomeEnd;

  /// No description provided for @microsLowest.
  ///
  /// In en, this message translates to:
  /// **'Lowest: {name} · {amount}'**
  String microsLowest(String name, String amount);

  /// No description provided for @healthSheetReads.
  ///
  /// In en, this message translates to:
  /// **'Reads your weight, steps and active calories. Nothing is written there and nothing leaves your phone.'**
  String get healthSheetReads;

  /// No description provided for @lastSynced.
  ///
  /// In en, this message translates to:
  /// **'Last synced at {time}'**
  String lastSynced(String time);

  /// No description provided for @syncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get syncNow;

  /// No description provided for @disconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get disconnect;

  /// No description provided for @healthSyncedWeights.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Weights are up to date} =1{1 new weight} other{{count} new weights}}'**
  String healthSyncedWeights(int count);

  /// No description provided for @cameraPermissionOff.
  ///
  /// In en, this message translates to:
  /// **'Camera access is off. Allow it in the app\'s settings to photograph your meal.'**
  String get cameraPermissionOff;

  /// No description provided for @openSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get openSettings;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @cameraChoosePhoto.
  ///
  /// In en, this message translates to:
  /// **'Choose photo'**
  String get cameraChoosePhoto;

  /// No description provided for @cameraGalleryNeedsAi.
  ///
  /// In en, this message translates to:
  /// **'A photo from the gallery needs the AI assistant. Download it in Chat.'**
  String get cameraGalleryNeedsAi;

  /// No description provided for @mealsTitle.
  ///
  /// In en, this message translates to:
  /// **'Meals'**
  String get mealsTitle;

  /// No description provided for @mealsLogged.
  ///
  /// In en, this message translates to:
  /// **'{n} of 4 logged'**
  String mealsLogged(int n);

  /// No description provided for @suggestedAmount.
  ///
  /// In en, this message translates to:
  /// **'Suggested ~{amount}'**
  String suggestedAmount(String amount);

  /// No description provided for @rateWhatYouAte.
  ///
  /// In en, this message translates to:
  /// **'Rate what you ate'**
  String get rateWhatYouAte;

  /// No description provided for @rateButton.
  ///
  /// In en, this message translates to:
  /// **'Rate'**
  String get rateButton;

  /// No description provided for @leftToday.
  ///
  /// In en, this message translates to:
  /// **'Left today'**
  String get leftToday;

  /// No description provided for @drawerTrack.
  ///
  /// In en, this message translates to:
  /// **'Track'**
  String get drawerTrack;

  /// No description provided for @meOverline.
  ///
  /// In en, this message translates to:
  /// **'Profile & targets'**
  String get meOverline;

  /// No description provided for @goalIs.
  ///
  /// In en, this message translates to:
  /// **'Goal: {goal}'**
  String goalIs(String goal);

  /// No description provided for @energy.
  ///
  /// In en, this message translates to:
  /// **'Energy'**
  String get energy;

  /// No description provided for @bornLabel.
  ///
  /// In en, this message translates to:
  /// **'Born'**
  String get bornLabel;

  /// No description provided for @planHeroTitle.
  ///
  /// In en, this message translates to:
  /// **'Your whole week, planned in one tap'**
  String get planHeroTitle;

  /// No description provided for @planHeroBody.
  ///
  /// In en, this message translates to:
  /// **'Breakfast, lunch and dinner from 166,000 recipes.'**
  String get planHeroBody;

  /// No description provided for @planSized.
  ///
  /// In en, this message translates to:
  /// **'Sized to your {amount} goal'**
  String planSized(String amount);

  /// No description provided for @planNoAllergens.
  ///
  /// In en, this message translates to:
  /// **'Without your allergens'**
  String get planNoAllergens;

  /// No description provided for @planStarsFirst.
  ///
  /// In en, this message translates to:
  /// **'Your 4★+ recipes first'**
  String get planStarsFirst;

  /// No description provided for @fillsAfterPlanning.
  ///
  /// In en, this message translates to:
  /// **'Fills in after planning'**
  String get fillsAfterPlanning;

  /// No description provided for @allergenFreeForYou.
  ///
  /// In en, this message translates to:
  /// **'Allergen-free for you'**
  String get allergenFreeForYou;

  /// No description provided for @ideasForMeal.
  ///
  /// In en, this message translates to:
  /// **'Ideas for your {meal}'**
  String ideasForMeal(String meal);

  /// No description provided for @amountLeftApprox.
  ///
  /// In en, this message translates to:
  /// **'~{amount} left'**
  String amountLeftApprox(String amount);

  /// No description provided for @microsLocked.
  ///
  /// In en, this message translates to:
  /// **'Today\'s vitamins and minerals against EU reference intakes, with Basic.'**
  String get microsLocked;

  /// No description provided for @highProtein.
  ///
  /// In en, this message translates to:
  /// **'High protein'**
  String get highProtein;

  /// No description provided for @avatarTitle.
  ///
  /// In en, this message translates to:
  /// **'Your picture'**
  String get avatarTitle;

  /// No description provided for @avatarWoman.
  ///
  /// In en, this message translates to:
  /// **'Woman'**
  String get avatarWoman;

  /// No description provided for @avatarMan.
  ///
  /// In en, this message translates to:
  /// **'Man'**
  String get avatarMan;

  /// No description provided for @avatarNeutral.
  ///
  /// In en, this message translates to:
  /// **'Neutral'**
  String get avatarNeutral;

  /// No description provided for @avatarPhoto.
  ///
  /// In en, this message translates to:
  /// **'Choose photo'**
  String get avatarPhoto;

  /// No description provided for @avatarRemovePhoto.
  ///
  /// In en, this message translates to:
  /// **'Remove photo'**
  String get avatarRemovePhoto;

  /// No description provided for @avatarColor.
  ///
  /// In en, this message translates to:
  /// **'Background colour'**
  String get avatarColor;

  /// No description provided for @voiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get voiceTitle;

  /// No description provided for @voiceRepliesHint.
  ///
  /// In en, this message translates to:
  /// **'When you talk to the assistant, it answers out loud too. It uses the voices installed on your phone; nothing leaves your phone.'**
  String get voiceRepliesHint;

  /// No description provided for @voiceRepliesSwitch.
  ///
  /// In en, this message translates to:
  /// **'Read answers aloud'**
  String get voiceRepliesSwitch;

  /// No description provided for @voiceWoman.
  ///
  /// In en, this message translates to:
  /// **'Woman\'s voice'**
  String get voiceWoman;

  /// No description provided for @voiceMan.
  ///
  /// In en, this message translates to:
  /// **'Man\'s voice'**
  String get voiceMan;

  /// No description provided for @voiceTest.
  ///
  /// In en, this message translates to:
  /// **'Play a sample'**
  String get voiceTest;

  /// No description provided for @voiceSample.
  ///
  /// In en, this message translates to:
  /// **'Hi! Tell me what you ate, and I\'ll log it for you.'**
  String get voiceSample;

  /// No description provided for @listening.
  ///
  /// In en, this message translates to:
  /// **'Listening… tap the mic to stop'**
  String get listening;

  /// No description provided for @transcribing.
  ///
  /// In en, this message translates to:
  /// **'Writing down what you said…'**
  String get transcribing;

  /// No description provided for @voiceNothingHeard.
  ///
  /// In en, this message translates to:
  /// **'Nothing heard. Try again, a little closer to the phone.'**
  String get voiceNothingHeard;

  /// No description provided for @micDenied.
  ///
  /// In en, this message translates to:
  /// **'The microphone is turned off for this app. Turn it on in Android settings to talk to the assistant.'**
  String get micDenied;

  /// No description provided for @reviewCheck.
  ///
  /// In en, this message translates to:
  /// **'Check this: the AI isn\'t sure'**
  String get reviewCheck;

  /// No description provided for @reviewAddFat.
  ///
  /// In en, this message translates to:
  /// **'Cooked with oil or butter?'**
  String get reviewAddFat;

  /// No description provided for @reviewAddFatHint.
  ///
  /// In en, this message translates to:
  /// **'Fried or roasted food usually is, and a photo can\'t show it. Adds a tablespoon of oil, which you can change.'**
  String get reviewAddFatHint;

  /// No description provided for @aiModelRecommended.
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get aiModelRecommended;
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
      <String>['de', 'en', 'fr', 'uk'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
    case 'uk':
      return AppLocalizationsUk();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
