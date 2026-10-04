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
}
