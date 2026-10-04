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

  @override
  String get chatHint => 'Ask about food, log a meal…';

  @override
  String get send => 'Send';

  @override
  String get preparingAi =>
      'Preparing the on-device AI… The first start takes about a minute.';

  @override
  String modelsMissing(String dir, String files) {
    return 'AI model files are missing in $dir: $files';
  }

  @override
  String get confirmSave => 'Save';

  @override
  String get confirmDiscard => 'Discard';

  @override
  String get confirmSaved => 'Saved';

  @override
  String get confirmDiscarded => 'Discarded';

  @override
  String get perServing => 'Per serving';

  @override
  String minutesServings(int minutes, int servings) {
    return '$minutes min · $servings servings';
  }

  @override
  String get notMedicalAdvice =>
      'General information, not medical advice. Talk to your doctor before changing your diet.';

  @override
  String get cameraComing =>
      'The camera arrives with the Pro plan in a later version.';

  @override
  String get crisisTitle => 'You don\'t have to go through this alone';

  @override
  String get crisisBody =>
      'If you might hurt yourself, call your local emergency number now. Free, confidential helplines in your country are listed at findahelpline.com.';

  @override
  String get crisisButton => 'Find a helpline';

  @override
  String limitReached(int count) {
    return 'You\'ve used today\'s $count free AI messages. They reset at midnight, or get unlimited chat with Basic.';
  }

  @override
  String get agentError => 'Something went wrong. Please try again.';

  @override
  String get reportResponse => 'Report this response';

  @override
  String get kcal => 'kcal';

  @override
  String get protein => 'Protein';

  @override
  String get fat => 'Fat';

  @override
  String get carbs => 'Carbs';

  @override
  String get fiber => 'Fiber';

  @override
  String get sugar => 'Sugar';

  @override
  String get sodium => 'Sodium';

  @override
  String get recipeIdeas => 'Recipe ideas';

  @override
  String get ingredients => 'Ingredients';

  @override
  String get steps => 'Steps';

  @override
  String get healthInfo => 'Health information';

  @override
  String servingsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count servings',
      one: '1 serving',
    );
    return '$_temp0';
  }

  @override
  String get iAteThis => 'I ate this';

  @override
  String get aiKnowsTitle => 'What the AI knows about you';

  @override
  String get aiKnowsIntro =>
      'This is everything the assistant is told about you. It stays on this phone.';

  @override
  String get factsSection => 'Things you told it';

  @override
  String get factsEmpty =>
      'Nothing yet. Tell the chat things like “I have an air fryer”.';

  @override
  String get allergiesSection => 'Allergies';

  @override
  String get allergiesEmpty => 'None recorded.';

  @override
  String get habitsSection => 'Habits it noticed (last 30 days)';

  @override
  String get habitsEmpty => 'Not enough logged meals yet.';

  @override
  String get conversationsSection => 'Conversations';

  @override
  String conversationsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messages stored.',
      one: '1 message stored.',
      zero: 'No messages stored.',
    );
    return '$_temp0';
  }

  @override
  String get forgetConversations => 'Forget past conversations';

  @override
  String get forgetConversationsBody =>
      'Deletes your chat history and the AI\'s memory of it. Logged meals, facts and allergies stay.';

  @override
  String get forget => 'Forget';

  @override
  String get edit => 'Edit';

  @override
  String get tabToday => 'Today';

  @override
  String get tabChat => 'Chat';

  @override
  String get tabLog => 'Log';

  @override
  String get tabMe => 'Me';

  @override
  String eatenOfGoal(int goal) {
    return 'of $goal kcal';
  }

  @override
  String kcalLeft(int left) {
    return '$left kcal left';
  }

  @override
  String kcalOver(int over) {
    return '$over kcal over';
  }

  @override
  String overBy(String amount) {
    return 'over by $amount';
  }

  @override
  String get eatenToday => 'Eaten today';

  @override
  String get setGoalsTitle => 'Set your daily goals';

  @override
  String get setGoalsBody =>
      'Tell us a little about you to get calorie and nutrient targets.';

  @override
  String get setGoalsButton => 'Set goals';

  @override
  String get todaysMeals => 'Today\'s meals';

  @override
  String get noMealsYet =>
      'Nothing logged yet. Use the Log tab or tell the chat what you ate.';

  @override
  String get deleteMealTitle => 'Delete this entry?';

  @override
  String get mealBreakfast => 'Breakfast';

  @override
  String get mealLunch => 'Lunch';

  @override
  String get mealDinner => 'Dinner';

  @override
  String get mealSnack => 'Snack';

  @override
  String get searchFood => 'Search foods, dishes, recipes…';

  @override
  String get kindFood => 'Food';

  @override
  String get kindDish => 'Dish';

  @override
  String get kindRecipe => 'Recipe';

  @override
  String get kindProduct => 'Product';

  @override
  String perServing2(int kcal) {
    return '$kcal kcal per serving';
  }

  @override
  String per100g(int kcal) {
    return '$kcal kcal per 100 g';
  }

  @override
  String get servings => 'Servings';

  @override
  String get grams => 'Grams';

  @override
  String get logButton => 'Log';

  @override
  String loggedSnack(String label) {
    return 'Logged $label';
  }

  @override
  String get noResults => 'No match in the food database.';

  @override
  String get goalsTitle => 'Your daily goals';

  @override
  String get goalsIntro =>
      'Used to compute your calorie and nutrient targets. Stays on this phone.';

  @override
  String get later => 'Later';

  @override
  String get units => 'Units';

  @override
  String get metric => 'Metric';

  @override
  String get imperial => 'Imperial';

  @override
  String get sex => 'Sex used for the formula';

  @override
  String get female => 'Female';

  @override
  String get male => 'Male';

  @override
  String get other => 'Other';

  @override
  String get birthYear => 'Birth year';

  @override
  String get heightCm => 'Height (cm)';

  @override
  String get heightFt => 'ft';

  @override
  String get heightIn => 'in';

  @override
  String get weightKg => 'Weight (kg)';

  @override
  String get weightLb => 'Weight (lb)';

  @override
  String get activity => 'Activity';

  @override
  String get activitySedentary => 'Sedentary: mostly sitting';

  @override
  String get activityLight => 'Light: exercise 1–3 days a week';

  @override
  String get activityModerate => 'Moderate: exercise 3–5 days a week';

  @override
  String get activityActive => 'Active: exercise 6–7 days a week';

  @override
  String get activityVeryActive =>
      'Very active: hard daily training or physical job';

  @override
  String get goal => 'Goal';

  @override
  String get goalLose => 'Lose weight';

  @override
  String get goalMaintain => 'Maintain';

  @override
  String get goalGain => 'Gain weight';

  @override
  String get invalidNumber => 'Enter a valid number';

  @override
  String get under18 =>
      'For people under 18 these formulas don\'t apply. Set targets with your pediatrician below.';

  @override
  String get targetsTitle => 'Daily targets';

  @override
  String get targetsNone => 'No targets yet.';

  @override
  String get custom => 'custom';

  @override
  String editTarget(String name) {
    return '$name target';
  }

  @override
  String get resetTarget => 'Use computed';

  @override
  String get editDetails => 'Edit my details';

  @override
  String get aiKnowsLoading => 'Available when the AI has loaded.';

  @override
  String get switchProfile => 'Lock and switch profile';

  @override
  String get limitSuffix => 'max';

  @override
  String get remindersTitle => 'Reminders';

  @override
  String get remindersHint =>
      'Times follow your usual meal times once you\'ve logged a few meals.';

  @override
  String get reminderBreakfast => 'Log breakfast';

  @override
  String get reminderLunch => 'Log lunch';

  @override
  String get reminderDinner => 'Log dinner';

  @override
  String get reminderEvening => 'Evening check-in';

  @override
  String notifMeal(String name, String meal) {
    return '$name, time to log your $meal?';
  }

  @override
  String notifEvening(String name) {
    return '$name, how did today go? Your summary is ready.';
  }

  @override
  String get notificationsDenied =>
      'Notifications are turned off for MyFoodMind in Android settings.';

  @override
  String get voiceInput => 'Speak';

  @override
  String get voiceStop => 'Stop listening';

  @override
  String get voiceUnavailable =>
      'Voice input needs offline speech recognition on this phone (Google app → Settings → Voice → Offline speech recognition → English). MyFoodMind never sends your voice online.';

  @override
  String youSaid(String text) {
    return 'You said: $text';
  }

  @override
  String aiSaid(String text) {
    return 'MyFoodMind said: $text';
  }

  @override
  String get useFingerprint => 'Use fingerprint';

  @override
  String get fingerprintTitle => 'Unlock with fingerprint';

  @override
  String get fingerprintHint =>
      'Only while this is the only profile on the phone: Android can\'t tell whose fingerprint it is.';

  @override
  String fingerprintReason(String name) {
    return 'Unlock $name\'s profile';
  }

  @override
  String get tryAgain => 'Try again';
}
