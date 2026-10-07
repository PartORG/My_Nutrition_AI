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
  String get tierFree => 'Free';

  @override
  String get tierBasic => 'Basic';

  @override
  String get tierMedium => 'Medium';

  @override
  String get tierPro => 'Pro';

  @override
  String get plansTitle => 'Plans';

  @override
  String get monthly => 'Monthly';

  @override
  String get yearly => 'Yearly';

  @override
  String perMonth(String price) {
    return '$price / month';
  }

  @override
  String perYear(String price) {
    return '$price / year';
  }

  @override
  String trialThen(String price) {
    return '7 days free, then $price';
  }

  @override
  String get subscribe => 'Subscribe';

  @override
  String get upgrade => 'Upgrade';

  @override
  String get switchPlan => 'Switch';

  @override
  String get currentPlan => 'Current plan';

  @override
  String get restorePurchases => 'Restore purchases';

  @override
  String get subscriptionTerms =>
      'Subscriptions renew automatically until cancelled. Cancel anytime in Google Play → Payments & subscriptions. One subscription covers every profile on this phone.';

  @override
  String get devBillingBanner =>
      'Developer mode: no real payment. Pick any plan to try it.';

  @override
  String get devBackToFree => 'Back to Free (developer)';

  @override
  String get purchaseFailed =>
      'The purchase didn\'t go through. Please try again.';

  @override
  String get featBasic1 => 'Unlimited AI chat';

  @override
  String get featBasic2 => 'Weekly and monthly dashboard';

  @override
  String get featBasic3 => 'Micronutrients, streaks, weight trend';

  @override
  String get featMedium1 => 'Everything in Basic';

  @override
  String get featMedium2 => 'Health conditions: diet limits and suggestions';

  @override
  String get featMedium3 => 'Symptom and reading journal, doctor export';

  @override
  String get featPro1 => 'Everything in Medium';

  @override
  String get featPro2 => 'Photo and live camera food recognition';

  @override
  String get featPro3 => 'Logs meals and finds recipes from what you see';

  @override
  String get yourPlan => 'Your plan';

  @override
  String get seePlans => 'See plans';

  @override
  String get periodDay => 'Day';

  @override
  String get periodWeek => 'Week';

  @override
  String get periodMonth => 'Month';

  @override
  String get lockedTitle => 'Weekly and monthly trends are in Basic';

  @override
  String get lockedBody =>
      'See calories per day against your goal, daily averages, micronutrients, your logging streak and your weight trend.';

  @override
  String get caloriesPerDay => 'Calories per day';

  @override
  String goalLine(int kcal) {
    return 'Goal $kcal';
  }

  @override
  String dailyAverage(int days) {
    return 'Daily average ($days days with logs)';
  }

  @override
  String streakDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days-day logging streak',
      one: '1-day logging streak',
      zero: 'No logging streak yet',
    );
    return '$_temp0';
  }

  @override
  String get weightTrend => 'Weight';

  @override
  String get weightTrendEmpty =>
      'Log your weight at least twice to see the trend.';

  @override
  String get logWeight => 'Log weight';

  @override
  String get weightLogged => 'Weight saved';

  @override
  String get plansUnavailable => 'Plans aren\'t available in this build.';

  @override
  String cautionAllergy(String food, String allergen) {
    return 'Contains $food, on your allergy list ($allergen)';
  }

  @override
  String cautionCondition(String food, String condition) {
    return 'Contains $food, a food to avoid with $condition';
  }

  @override
  String get condDiabetesT2 => 'Type 2 diabetes';

  @override
  String get condHypertension => 'High blood pressure';

  @override
  String get condGout => 'Gout';

  @override
  String get condAls => 'ALS';

  @override
  String get condMs => 'Multiple sclerosis';

  @override
  String get healthTitle => 'Health';

  @override
  String get healthMeHint =>
      'Conditions, journal, timeline, report for your doctor';

  @override
  String get conditionsTitle => 'Conditions';

  @override
  String get conditionsHint =>
      'Recipe suggestions skip foods to avoid, and limits lower your daily targets. These are general suggestions, not medical advice: talk to your doctor before changing your diet.';

  @override
  String limitLine(String nutrient, String amount, String condition) {
    return '$nutrient: at most $amount a day ($condition)';
  }

  @override
  String avoidLine(String foods) {
    return 'Foods to avoid: $foods';
  }

  @override
  String limitFrom(String condition) {
    return 'limit for $condition';
  }

  @override
  String get timelineTitle => 'Timeline';

  @override
  String get timelineHint => 'Nutrients, readings and symptoms by date';

  @override
  String get timelineEmpty => 'Nothing recorded in this period.';

  @override
  String get reportButton => 'Report for your doctor';

  @override
  String get reportHint => 'PDF and CSV of what you logged';

  @override
  String get journalTitle => 'Journal';

  @override
  String get journalHint => 'Last 14 days';

  @override
  String get journalEmpty => 'Nothing recorded in the last 14 days.';

  @override
  String get symptom => 'Symptom';

  @override
  String get symptomHint => 'What do you feel? e.g. fatigue';

  @override
  String get severity => 'Severity (optional)';

  @override
  String get severityHint => '1 = mild, 5 = severe';

  @override
  String get glucose => 'Blood glucose';

  @override
  String get bloodPressure => 'Blood pressure';

  @override
  String get systolic => 'Systolic (upper)';

  @override
  String get diastolic => 'Diastolic (lower)';

  @override
  String get deleteEntryTitle => 'Delete this entry?';

  @override
  String get healthLockedTitle => 'Health tracking is part of Medium';

  @override
  String get healthLockedBody =>
      'Medium adds conditions (recipe filtering and daily limits), a symptom and reading journal, timeline charts and a report to share with your doctor.';

  @override
  String conditionsStillApply(String conditions) {
    return 'Your conditions still filter recipes and limit your targets: $conditions';
  }

  @override
  String days(int count) {
    return '$count days';
  }

  @override
  String get perDay => 'per day';

  @override
  String get symptomsTitle => 'Symptoms';

  @override
  String get readingsTitle => 'Readings';

  @override
  String get reportSheetHint =>
      'A PDF to read and a CSV for spreadsheets, with everything you logged. You choose where to send them; the app shares nothing by itself.';

  @override
  String get reportShare => 'Create and share';

  @override
  String get reportSubject => 'MyFoodMind report';

  @override
  String get reportFailed => 'Couldn\'t create the report.';

  @override
  String reportTitle(String name) {
    return 'MyFoodMind report: $name';
  }

  @override
  String reportCreated(String date) {
    return 'created $date';
  }

  @override
  String get reportDisclaimer =>
      'Recorded by the user in the MyFoodMind app. Values are shown as logged; the app does not interpret them and gives no medical advice. Limits come from the conditions the user selected.';

  @override
  String get reportNone => 'None recorded.';

  @override
  String reportDailyNutrition(int days) {
    return 'Daily nutrition ($days days with logs)';
  }

  @override
  String get reportDate => 'Date';

  @override
  String get reportItems => 'Items';

  @override
  String get reportMeasurement => 'Measurement';

  @override
  String get reportValue => 'Value';

  @override
  String get cameraTitle => 'Camera';

  @override
  String get cameraOpen => 'Open camera';

  @override
  String get cameraPhoto => 'Photo';

  @override
  String get cameraLive => 'Live';

  @override
  String get cameraUnavailable =>
      'The camera isn\'t available. Allow camera access for MyFoodMind in Android settings.';

  @override
  String get cameraShoot => 'Take photo';

  @override
  String get cameraNaming => 'Recognizing food…';

  @override
  String get cameraNamingFailed => 'Couldn\'t recognize the food. Try again.';

  @override
  String cameraUseFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Use $count items',
      one: 'Use 1 item',
      zero: 'Continue',
    );
    return '$_temp0';
  }

  @override
  String get reviewTitle => 'Check what was found';

  @override
  String get reviewHint =>
      'Amounts from a photo are estimates (≈). Change or remove anything; nothing is saved until you tap Log.';

  @override
  String get reviewEmpty => 'No food found. Add items by name.';

  @override
  String notInDatabase(String name) {
    return '$name: not in the database, tap edit to pick a food';
  }

  @override
  String get reviewChange => 'Change';

  @override
  String get reviewAdd => 'Add item';

  @override
  String get reviewLog => 'Log this meal';

  @override
  String reviewLogged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items logged',
      one: '1 item logged',
    );
    return '$_temp0';
  }

  @override
  String get reviewCook => 'What can I cook?';

  @override
  String get yourRating => 'Your rating';

  @override
  String get kindRecent => 'Recent';

  @override
  String get recentFoods => 'Recent and frequent';

  @override
  String repeatYesterday(String meal, int kcal) {
    return 'Yesterday\'s $meal · $kcal kcal';
  }

  @override
  String get quickAdd => 'Quick add';

  @override
  String get quickAddName => 'Name (optional)';

  @override
  String get editMeal => 'Edit meal';

  @override
  String get appearance => 'Appearance';

  @override
  String get healthConnect => 'Health Connect';

  @override
  String get appleHealth => 'Apple Health';

  @override
  String get healthSyncHint =>
      'Read your weight (for your goals) and steps. Nothing is written there and nothing leaves your phone.';

  @override
  String get healthSyncDenied =>
      'No access. Allow weight and steps in the health app\'s settings, then try again.';

  @override
  String stepsToday(String steps) {
    return '$steps steps today';
  }

  @override
  String get mealPlan => 'Meal plan';

  @override
  String get planTab => 'Plan';

  @override
  String get planEmpty =>
      'Plan your week: breakfast, lunch and dinner from the recipe database, sized to your calorie goal, without your allergens, and with recipes you rated highly first.';

  @override
  String get planWeek => 'Plan my week';

  @override
  String get planAgain => 'Plan again';

  @override
  String get planSwap => 'Another recipe';

  @override
  String get planCardEmpty => 'Plan your week and get a shopping list';

  @override
  String get makeShoppingList => 'Shopping list';

  @override
  String get shoppingList => 'Shopping';

  @override
  String get shoppingAdd => 'Add an item';

  @override
  String get shoppingEmpty =>
      'Nothing to buy. Make a list from your plan, or add a recipe\'s ingredients from the recipe.';

  @override
  String get clearTicked => 'Clear ticked';

  @override
  String get addToShopping => 'Add to shopping list';

  @override
  String get addedToShopping => 'Added to the shopping list';

  @override
  String waterLine(int ml, int goal) {
    return 'Water $ml / $goal ml';
  }

  @override
  String get waterAddGlass => 'Add a glass (250 ml)';

  @override
  String get waterUndo => 'Undo the last glass';

  @override
  String get waterGoal => 'Daily water goal';

  @override
  String get fasting => 'Fasting';

  @override
  String fastingLine(int h, int m, int target) {
    return 'Fasting $h h $m min of $target h';
  }

  @override
  String get fastStart => 'Start now';

  @override
  String fastSinceMeal(String time) {
    return 'Since last meal ($time)';
  }

  @override
  String get fastEnd => 'End fast';

  @override
  String get fastDone => 'Goal reached. End the fast whenever you eat.';

  @override
  String get fastingSwitch => 'Fasting timer';

  @override
  String get fastingCaution =>
      'Not advised in pregnancy, with an eating disorder, or with diabetes treated with insulin or sulfonylureas. Ask your doctor first.';

  @override
  String get widgetKcalTitle => 'Calories on the home-screen widget';

  @override
  String get widgetKcalHint =>
      'Add the MyFoodMind widget to your home screen. Today\'s calories are then visible there without your PIN.';

  @override
  String get welcomeTitle => 'Log your first meal';

  @override
  String get welcomeBody =>
      'Type or say it in Chat (\"I had 2 eggs and toast\"), search it in Log, or take a photo. Your day fills in here.';

  @override
  String nextMealTitle(String meal) {
    return 'No $meal logged yet';
  }

  @override
  String get nextMealBody =>
      'Log what you had, or get an idea for what to eat.';

  @override
  String get getIdea => 'Get an idea';

  @override
  String get logIt => 'Log it';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get wallpaperColors => 'Wallpaper colours';

  @override
  String get wallpaperColorsHint =>
      'Use your phone\'s colours (Android 12 and newer).';

  @override
  String suggestAte(String food) {
    return 'I ate $food';
  }

  @override
  String suggestIdea(String meal) {
    return 'Something new for $meal';
  }

  @override
  String get suggestLeft => 'What\'s left for today?';

  @override
  String rateStars(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Rate $count stars',
      one: 'Rate 1 star',
    );
    return '$_temp0';
  }

  @override
  String get recipesYouAte => 'Recipes you ate';

  @override
  String get recipesYouAteHint =>
      'Tap one to see it again and rate it. Recipe ideas follow your stars.';

  @override
  String get cookNone => 'No recipe in the database uses these foods.';

  @override
  String get per100Suffix => ' / 100 g';

  @override
  String get aiDownloadTitle => 'Download the AI assistant';

  @override
  String aiDownloadBody(String gb) {
    return 'The chat assistant runs entirely on your phone. Its model ($gb GB) downloads once from Hugging Face; use Wi-Fi. Nothing about you is sent. Logging, recipes and your dashboard already work without it.';
  }

  @override
  String get aiDownloadButton => 'Download';

  @override
  String get aiModelTitle => 'AI model';

  @override
  String aiModelStandard(String gb) {
    return 'Standard · $gb GB';
  }

  @override
  String get aiModelStandardHint =>
      'Faster answers. Works on every supported phone.';

  @override
  String aiModelLarge(String gb) {
    return 'Larger · $gb GB';
  }

  @override
  String get aiModelLargeHint =>
      'Understands more, answers about 2-3x slower. For phones with 8 GB RAM.';

  @override
  String get aiModelSwitch => 'Switch';

  @override
  String get aiModelSwitchBody =>
      'The other model downloads first; the current one is deleted when it\'s done.';

  @override
  String get aiModelInUse => 'In use';

  @override
  String get aiDownloading => 'Downloading';

  @override
  String get aiDownloadFailed =>
      'The download stopped. Check your connection and free space, then try again; it continues where it stopped.';

  @override
  String get privacyPolicy => 'Privacy policy';

  @override
  String get termsOfUse => 'Terms of use';

  @override
  String get licenses => 'Licenses and AI models';
}
