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
  String get addProfile => 'Create profile';

  @override
  String get googleWrongAccount =>
      'That isn’t the Google account this profile was created with.';

  @override
  String get signInWithGoogle => 'Sign in with Google';

  @override
  String get continueWithGoogle => 'Continue with Google';

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
      'Your PIN unlocks the app when the fingerprint can’t. If you forget it, the profile can only be deleted.';

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
      'General information from published guidelines, not medical advice. It doesn\'t replace your doctor or dietitian: talk to them before changing your diet or medicines.';

  @override
  String get chatDisclaimer =>
      'AI answers can be wrong and don\'t replace a doctor. In an emergency, call your local emergency number.';

  @override
  String get medicalDisclaimerTitle => 'Medical disclaimer';

  @override
  String get medicalDisclaimerBody =>
      'MyFoodMind and its AI assistant give general information about food and nutrition. They are not a medical device and do not diagnose, treat, cure or prevent any disease.\n\nNothing in the app, including the assistant\'s answers, condition limits and health information, replaces advice from a doctor, dietitian or other qualified health professional. The AI runs on your phone and can make mistakes.\n\nAlways talk to your doctor before changing your diet, medicines or treatment, especially if you have a medical condition, are pregnant or breastfeeding, or have or had an eating disorder. Never ignore professional advice or delay seeking it because of something in this app.\n\nIf you think you may have a medical emergency, call your local emergency number right away.';

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
  String get allergiesSection => 'Allergies and diet';

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
  String get aboutMe => 'About me';

  @override
  String get sexShort => 'Sex';

  @override
  String get height => 'Height';

  @override
  String get weight => 'Weight';

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
      'Unlock with your fingerprint instead of the PIN.';

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
  String get featBasic3 => 'Water reminders, logging streak, micronutrients';

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
  String get lockedTitle => 'More with Basic';

  @override
  String get lockedBody =>
      'Your logging streak, a weekly meal plan with a shopping list, water reminders and 3 months of history.';

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
      'Log your weight on two different days to see the trend.';

  @override
  String get logWeight => 'Log weight';

  @override
  String get weightLogged => 'Weight saved';

  @override
  String get plansUnavailable => 'Plans aren\'t available in this build.';

  @override
  String cautionAllergy(String food, String allergen) {
    return 'Contains $food, which your allergies or diet exclude ($allergen)';
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
      'The camera isn\'t available right now. Close other apps that use it and try again.';

  @override
  String get cameraShoot => 'Take photo';

  @override
  String get cameraNaming => 'Recognizing food…';

  @override
  String get cameraNamingFailed =>
      'AI recognition failed: showing quick detection instead. Check the items.';

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
    return '$name: not in the database. Tap Change to pick a food.';
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
  String get changeFood => 'Change food';

  @override
  String get appearance => 'Appearance';

  @override
  String cardLogMeal(String meal) {
    return 'Log $meal';
  }

  @override
  String get cardSaveRecipe => 'Save recipe';

  @override
  String get cardRateRecipe => 'Rate recipe';

  @override
  String get cardRemember => 'Remember';

  @override
  String get cardAddAllergy => 'Add allergy';

  @override
  String get cardRemoveAllergy => 'Remove allergy';

  @override
  String get cardAddDiet => 'Add diet';

  @override
  String get cardRemoveDiet => 'Remove diet';

  @override
  String get captionConfirm => 'Check it and tap Save.';

  @override
  String get captionIdeas => 'Here are some ideas. Tap one to see the recipe.';

  @override
  String captionIdeasAvoiding(String foods) {
    return 'Careful: you\'re allergic to or avoid $foods, so I left it out. Here are recipes without it; tap one to see it.';
  }

  @override
  String get captionRecipe => 'Here\'s the recipe.';

  @override
  String get captionNumbers => 'Here are the numbers.';

  @override
  String get captionCamera => 'Tap the button to open the camera.';

  @override
  String get cardLogSymptom => 'Log symptom';

  @override
  String get cardLogGlucose => 'Log blood glucose';

  @override
  String get cardLogBloodPressure => 'Log blood pressure';

  @override
  String get cardLogWater => 'Log water';

  @override
  String get last7Days => 'Last 7 days';

  @override
  String get weekReviewTitle => 'Your week';

  @override
  String reviewLoggedDays(int days) {
    return 'You logged food on $days of 7 days.';
  }

  @override
  String reviewKcal(int avg, int goal) {
    return 'On those days: $avg kcal on average, goal $goal.';
  }

  @override
  String reviewUnder(String nutrient, int days) {
    return '$nutrient under 80 % of your goal on $days days.';
  }

  @override
  String reviewOver(String nutrient, int days) {
    return '$nutrient over your limit on $days days.';
  }

  @override
  String reviewWater(int avg, int goal) {
    return 'Water: $avg ml a day, goal $goal ml.';
  }

  @override
  String reviewTop(String food) {
    return 'Logged most: $food.';
  }

  @override
  String get reviewIdeas => 'Ideas for next week';

  @override
  String reviewAskHigh(String nutrient) {
    return 'Suggest recipes high in $nutrient';
  }

  @override
  String reviewAskLow(String nutrient) {
    return 'Suggest recipes low in $nutrient';
  }

  @override
  String get calcium => 'Calcium';

  @override
  String get iron => 'Iron';

  @override
  String get magnesium => 'Magnesium';

  @override
  String get potassium => 'Potassium';

  @override
  String get vitaminC => 'Vitamin C';

  @override
  String get vitaminD => 'Vitamin D';

  @override
  String get vitaminB12 => 'Vitamin B12';

  @override
  String get microsTitle => 'Vitamins and minerals';

  @override
  String microsCoverage(int known, int meals) {
    return 'From $known of $meals meals with known values; EU reference intakes';
  }

  @override
  String get productsTitle => 'Packaged products';

  @override
  String get productsNone =>
      'Built in: products from 2019, few European ones. Download every product in Open Food Facts (all countries) to find what you buy. Wi-Fi recommended.';

  @override
  String productsHave(String count, String date) {
    return '$count products from Open Food Facts, updated $date.';
  }

  @override
  String productsDownload(int mb) {
    return 'Download ($mb MB)';
  }

  @override
  String get productsRemove => 'Remove';

  @override
  String get productsHint =>
      'Missing a packaged product? Download all products in Me.';

  @override
  String get healthConnect => 'Health Connect';

  @override
  String get appleHealth => 'Apple Health';

  @override
  String get healthSyncHint =>
      'Reads your weight (for your goals), steps and active calories (shown on Today). Nothing is written there and nothing leaves your phone. Turn off to disconnect.';

  @override
  String get healthSyncDenied =>
      'No access. Allow weight, steps and active calories in the health app\'s settings, then try again.';

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
  String get language => 'Language';

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
      'Understands more, answers about 2-3x slower. For phones with 12 GB RAM.';

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
  String get downloadNoWifiTitle => 'Not on Wi-Fi';

  @override
  String downloadNoWifiBody(int mb) {
    return 'You are not connected to Wi-Fi. This download is $mb MB; over mobile data it can use up your data plan or cost money.';
  }

  @override
  String get downloadWaitWifi => 'Wait for Wi-Fi';

  @override
  String get downloadUseMobile => 'Use mobile data';

  @override
  String get downloadOnMobile =>
      'Mobile data allowed: this download can use your data plan.';

  @override
  String get downloadWaitingWifi => 'Waiting for Wi-Fi';

  @override
  String get downloadWaitingNetwork => 'Waiting for a connection';

  @override
  String get downloadRetrying =>
      'Connection lost; it continues when it\'s back';

  @override
  String get downloadPaused => 'Paused';

  @override
  String get downloadInstalling => 'Installing…';

  @override
  String get downloadPause => 'Pause';

  @override
  String get downloadResume => 'Resume';

  @override
  String get privacyPolicy => 'Privacy policy';

  @override
  String get termsOfUse => 'Terms of use';

  @override
  String get licenses => 'Licenses and AI models';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get drawerFood => 'Food';

  @override
  String get drawerAssistant => 'Assistant';

  @override
  String get shoppingListNav => 'Shopping list';

  @override
  String get healthJournalNav => 'Health journal and report';

  @override
  String get settingsAi => 'AI and data';

  @override
  String get settingsTracking => 'Tracking';

  @override
  String get settingsPrivacy => 'Privacy and security';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsDanger => 'Danger zone';

  @override
  String get deleteThisProfile => 'Delete this profile';

  @override
  String get deleteThisProfileBody =>
      'This removes the profile and all its meals, journal and chat history from this phone. This can\'t be undone.';

  @override
  String get featBasic2 => 'Meal plan and shopping list';

  @override
  String get featBasic4 => '3 months of history';

  @override
  String get featMedium4 => '8 months of history';

  @override
  String get featPro4 => 'Year dashboard and 12 months of history';

  @override
  String get periodYear => 'Year';

  @override
  String get yearLockedTitle => 'The Year view is in Pro';

  @override
  String get yearLockedBody =>
      'Twelve months at a glance: calories per month, a logging calendar, nutrient averages with your best and worst months, your weight and what you ate most.';

  @override
  String get yearCalories => 'Calories per day, monthly average';

  @override
  String get yearCalendar => 'Logging calendar';

  @override
  String yearLoggedDays(int days, int best) {
    return '$days days logged · best streak $best days';
  }

  @override
  String get yearNutrients => 'Daily averages this year';

  @override
  String yearBestWorst(String nutrient, String best, String worst) {
    return '$nutrient: best month $best, worst $worst';
  }

  @override
  String get yearTopFoods => 'Eaten most';

  @override
  String get calendarOnGoal => 'Within 10% of goal';

  @override
  String get calendarNear => 'Within 25%';

  @override
  String get calendarFar => 'Further off';

  @override
  String get calendarNotLogged => 'Not logged';

  @override
  String get historyTitle => 'History';

  @override
  String lastDays(int count) {
    return 'Last $count days';
  }

  @override
  String get pickDates => 'Pick dates';

  @override
  String get historyEmpty => 'Nothing logged on these days.';

  @override
  String historyLockedTitle(int days) {
    return 'History shows the last $days days';
  }

  @override
  String get historyLockedBody =>
      'Older meals stay on your phone. Basic shows 3 months, Medium 8 and Pro 12.';

  @override
  String get planLockedTitle => 'The meal plan is in Basic';

  @override
  String get planLockedBody =>
      'Plan your week from recipes that fit your goals and allergens, and turn it into a shopping list.';

  @override
  String get reminderWater => 'Drink water';

  @override
  String reminderWaterHint(int count, String from, String to) {
    return '$count a day, $from–$to: one glass each to reach your water goal';
  }

  @override
  String get reminderWaterLocked => 'Water reminders are in Basic';

  @override
  String notifWater(String name) {
    return '$name, time for a glass of water.';
  }

  @override
  String get machineTranslated => 'Ingredient names machine-translated';

  @override
  String get translateSteps => 'Translate steps';

  @override
  String get machineTranslatedSteps => 'Steps machine-translated on your phone';

  @override
  String get showOriginal => 'Show original';

  @override
  String get showTranslation => 'Show translation';

  @override
  String get translateBusy => 'The assistant is busy. Try again in a moment.';

  @override
  String get translateFailed =>
      'Couldn\'t translate the steps. Please try again.';

  @override
  String get translateNeedsAi =>
      'Translating needs the AI model (see the Chat tab).';

  @override
  String get tabPlan => 'Plan';

  @override
  String get trendWeight => 'Trend weight';

  @override
  String weightChangeIn(String change, int days) {
    return '$change in $days days';
  }

  @override
  String rangeMonths(int n) {
    return '${n}M';
  }

  @override
  String get rangeYear => '1Y';

  @override
  String get legendScale => 'Scale';

  @override
  String get legendTrend => 'Trend';

  @override
  String perWeek(String unit) {
    return '$unit per week';
  }

  @override
  String get latestScale => 'Latest on the scale';

  @override
  String get weightTrendNote =>
      'The trend smooths out daily water swings, so one heavy morning is not mistaken for a real change.';

  @override
  String weightChartLabel(int n, String from, String to) {
    return 'Weight, $n readings, trend from $from to $to';
  }

  @override
  String get addShort => '+ Add';

  @override
  String get calories => 'Calories';

  @override
  String get cook => 'Cook';

  @override
  String get eatenWord => 'Eaten';

  @override
  String get leftWord => 'Left';

  @override
  String get kcalLeftShort => 'kcal left';

  @override
  String get kcalOverShort => 'kcal over';

  @override
  String get fastNotRunning => 'Not fasting';

  @override
  String get fromYourPlan => 'from your plan';

  @override
  String get glassAdded => 'Glass of water added';

  @override
  String get undo => 'Undo';

  @override
  String get water => 'Water';

  @override
  String get litreUnit => 'L';

  @override
  String get yourWeek => 'Your week';

  @override
  String get yourMonth => 'Your month';

  @override
  String get yourYear => 'Your year';

  @override
  String addToMeal(String meal) {
    return 'Add to $meal';
  }

  @override
  String fastGoalHours(int hours) {
    return '$hours h goal';
  }

  @override
  String fitsLeft(String amount) {
    return 'fits your $amount left';
  }

  @override
  String hoursMinutes(int h, int m) {
    return '$h h $m min';
  }

  @override
  String minutesShort(int minutes) {
    return '$minutes min';
  }

  @override
  String get kindAll => 'All';

  @override
  String get lessServing => 'Half a serving less';

  @override
  String get moreServing => 'Half a serving more';

  @override
  String get logFoodTitle => 'Log food';

  @override
  String get snapPhoto => 'Snap a photo';

  @override
  String servingsAmount(String amount) {
    return '$amount × serving';
  }

  @override
  String yesterdaysMeal(String meal) {
    return 'Yesterday\'s $meal';
  }

  @override
  String get assistantTitle => 'Assistant';

  @override
  String get openRecipe => 'Open recipe';

  @override
  String get runsOnPhone => 'Runs on this phone · nothing leaves it';

  @override
  String gramsProtein(int n) {
    return '$n g protein';
  }

  @override
  String messagesLeft(int n, int total) {
    return '$n of $total left today';
  }

  @override
  String get addedToPlan => 'Added to your plan';

  @override
  String get addToPlan => 'Add to plan';

  @override
  String get addToShoppingShort => '+ Add to shopping';

  @override
  String get aisleProduce => 'Fruit and vegetables';

  @override
  String get aisleMeatFish => 'Meat and fish';

  @override
  String get aisleDairyEggs => 'Dairy and eggs';

  @override
  String get aisleBakery => 'Bakery';

  @override
  String get aislePantry => 'Pantry';

  @override
  String get aisleSpices => 'Spices';

  @override
  String get aisleFrozen => 'Frozen';

  @override
  String get aisleDrinks => 'Drinks';

  @override
  String get aisleOther => 'Other';

  @override
  String get back => 'Back';

  @override
  String get badgeMorning => 'AM';

  @override
  String get badgeNoon => 'NOON';

  @override
  String get badgeEvening => 'PM';

  @override
  String get boxEmpty =>
      'Nothing here yet. Save a recipe with its bookmark, or search above.';

  @override
  String get boxFootnote =>
      'Recipes with your allergens never appear here. Ideas follow your stars.';

  @override
  String get close => 'Close';

  @override
  String get doneCooking => 'Done';

  @override
  String get fewerServings => 'Fewer servings';

  @override
  String get moreServings => 'More servings';

  @override
  String get findRecipes => 'Find recipes';

  @override
  String get forThisStep => 'For this step';

  @override
  String get fridgeHint => 'e.g. eggs, spinach, feta';

  @override
  String get logServing => 'Log a serving';

  @override
  String get nextStep => 'Next step';

  @override
  String get noSteps => 'This recipe has no steps.';

  @override
  String get recipesTitle => 'Recipes';

  @override
  String get removeSaved => 'Remove from saved';

  @override
  String get savedLabel => 'Saved';

  @override
  String get searchRecipes => 'Search 166,000 recipes…';

  @override
  String get servingsLabel => 'Servings';

  @override
  String get servingsHint => 'Amounts and nutrition update';

  @override
  String get shelfCooked => 'Cooked';

  @override
  String get shelfLoved => '4★ and up';

  @override
  String get shelfQuick => '≤ 30 min';

  @override
  String get startCooking => 'Start cooking';

  @override
  String get thisWeek => 'This week';

  @override
  String get timerDone => 'Time\'s up';

  @override
  String get whatCanICook => 'What can I cook?';

  @override
  String get whatCanICookBody => 'Say or snap what\'s in your fridge';

  @override
  String allergensLeftOut(String list) {
    return '$list are left out: they\'re on your allergy list.';
  }

  @override
  String clearTickedN(int n) {
    return 'Clear ticked ($n)';
  }

  @override
  String cookedTimes(int n) {
    return 'cooked $n×';
  }

  @override
  String cookSubtitle(int servings) {
    return 'Screen stays on · $servings servings';
  }

  @override
  String forRecipe(String title) {
    return 'For: $title';
  }

  @override
  String ideasFor(String list) {
    return 'Ideas for: $list';
  }

  @override
  String itemsLeft(int n, int total) {
    return '$n of $total left';
  }

  @override
  String plannedFor(String day) {
    return 'Planned for $day';
  }

  @override
  String planOfKcal(int n, int total) {
    return '$n of $total kcal';
  }

  @override
  String roomForSnack(int kcal) {
    return 'Room for a $kcal kcal snack.';
  }

  @override
  String shelfSaved(int n) {
    return 'Saved · $n';
  }

  @override
  String shoppingTabCount(int n) {
    return 'Shopping · $n';
  }

  @override
  String startTimer(String time) {
    return 'Start $time timer';
  }

  @override
  String stepOf(int step, int steps) {
    return 'Step $step of $steps';
  }

  @override
  String timerRunning(String time) {
    return '$time · tap to stop';
  }

  @override
  String youRated(int stars) {
    return 'you rated $stars';
  }

  @override
  String get changePin => 'Change PIN';

  @override
  String get currentPin => 'Current PIN';

  @override
  String get pinChanged => 'PIN changed';

  @override
  String get dailyTargets => 'Daily targets';

  @override
  String get tapToOverride => 'Tap to override';

  @override
  String get googleAccount => 'Google account';

  @override
  String get googleNotLinked => 'Not linked: PIN and fingerprint only';

  @override
  String googleLinked(String email) {
    return '$email · name only';
  }

  @override
  String get historyAndYear => 'History and Year view';

  @override
  String get limitShort => 'max';

  @override
  String get link => 'Link';

  @override
  String get unlink => 'Unlink';

  @override
  String get lookAndLanguage => 'Look and language';

  @override
  String get onDeviceAiAndData => 'On-device AI and data';

  @override
  String get savedRecipesTitle => 'Saved recipes';

  @override
  String bornIn(int year) {
    return 'born $year';
  }

  @override
  String planChip(String tier) {
    return '$tier plan · See plans';
  }

  @override
  String get addAllergyTitle => 'Add an allergy or diet';

  @override
  String get addAllergyHint => 'e.g. peanuts, gluten, vegetarian';

  @override
  String allergyUnknown(String text) {
    return '\"$text\" isn\'t an allergen or diet the app can filter. Try peanuts, tree nuts, milk, egg, gluten, shellfish, fish, soy, sesame, vegetarian, vegan or pescatarian.';
  }

  @override
  String get continueButton => 'Continue';

  @override
  String get dataLocked => 'Your data is locked on this phone.';

  @override
  String get firstRunNext => 'Next: a PIN or fingerprint, then your goals.';

  @override
  String get googleOnlyName => 'Google only fills in your name.';

  @override
  String get lockItTitle => 'Lock it to you';

  @override
  String get nameExample => 'e.g. Sam';

  @override
  String get recordsNotInterprets =>
      'The app records what you enter and never interprets it. General information from published guidelines, not medical advice.';

  @override
  String get recordTitle => 'Record';

  @override
  String get reportHintShort => 'PDF and CSV of what you logged';

  @override
  String get startTrial => 'Start 7-day free trial';

  @override
  String get touchSensor => 'Touch the sensor to unlock';

  @override
  String get trialBadge => '7 DAYS FREE';

  @override
  String get usePin => 'Use PIN';

  @override
  String get welcomeHeadline => 'Eat well, privately';

  @override
  String get welcomeIntro =>
      'An AI nutrition assistant that runs on this phone. No cloud AI, no analytics.';

  @override
  String get welcomePointPrivate =>
      'Your meals and chats never leave the phone';

  @override
  String get welcomePointData => '55,000 foods and 166,000 recipes built in';

  @override
  String get welcomePointAllergens => 'Allergens filtered out of every recipe';

  @override
  String get yourName => 'Your name';

  @override
  String currentTier(String tier) {
    return 'Current: $tier';
  }

  @override
  String severityN(int n) {
    return 'severity $n';
  }

  @override
  String welcomeBack(String name) {
    return 'Welcome back, $name';
  }

  @override
  String get bestStreak => 'best streak';

  @override
  String get daysLogged => 'days logged';

  @override
  String avgValue(String value) {
    return 'avg $value';
  }

  @override
  String dayLine(String amount, int n) {
    return '$amount kcal · $n meals';
  }

  @override
  String sinceMonth(String month) {
    return 'since $month';
  }

  @override
  String streakShort(int n) {
    return '$n-day streak';
  }

  @override
  String get estimatedTotal => 'Estimated total';

  @override
  String logThisMeal(String meal) {
    return 'Log this $meal';
  }

  @override
  String activeKcalBurned(String kcal) {
    return '$kcal kcal burnt';
  }

  @override
  String get weightUpdatedToday => 'Today\'s weight updated.';

  @override
  String get historyMeals => 'Meals';

  @override
  String get historyRecipes => 'Recipes cooked';

  @override
  String get historyRecipesEmpty =>
      'No recipes on these days. When you log a recipe (“I ate this”), it shows up here.';

  @override
  String lastCooked(String date) {
    return 'last $date';
  }

  @override
  String get removeItem => 'Remove';

  @override
  String seenAs(String name) {
    return 'seen: $name';
  }

  @override
  String get confirmUndone => 'Undone';

  @override
  String get editOnToday => 'Edit on Today';

  @override
  String get thinking => 'Thinking…';

  @override
  String get searchInsteadInLog => 'Search foods in Log instead';

  @override
  String get burntWord => 'Burnt';

  @override
  String get aiCardTitle => 'Get the AI assistant';

  @override
  String get aiCardBody =>
      'Describe meals in your own words and ask about food. It runs on this phone: one download (a few GB, Wi-Fi recommended). Search and quick add work without it.';

  @override
  String get welcomeLog => 'Search it in Log, or quick-add the calories.';

  @override
  String get welcomeChat =>
      'Or type or say it in Chat (\"I had 2 eggs and toast\").';

  @override
  String get welcomePhoto => 'Or take a photo of your plate.';

  @override
  String get welcomeEnd => 'Your day fills in here.';

  @override
  String microsLowest(String name, String amount) {
    return 'Lowest: $name · $amount';
  }

  @override
  String get healthSheetReads =>
      'Reads your weight, steps and active calories. Nothing is written there and nothing leaves your phone.';

  @override
  String lastSynced(String time) {
    return 'Last synced at $time';
  }

  @override
  String get syncNow => 'Sync now';

  @override
  String get disconnect => 'Disconnect';

  @override
  String healthSyncedWeights(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new weights',
      one: '1 new weight',
      zero: 'Weights are up to date',
    );
    return '$_temp0';
  }

  @override
  String get cameraPermissionOff =>
      'Camera access is off. Allow it in the app\'s settings to photograph your meal.';

  @override
  String get openSettings => 'Open settings';

  @override
  String get tryAgain => 'Try again';

  @override
  String get cameraChoosePhoto => 'Choose photo';

  @override
  String get cameraGalleryNeedsAi =>
      'A photo from the gallery needs the AI assistant. Download it in Chat.';
}
