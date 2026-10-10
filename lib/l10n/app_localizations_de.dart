// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'MyFoodMind';

  @override
  String get whoIsEating => 'Wer isst?';

  @override
  String get addProfile => 'Profil hinzufügen';

  @override
  String get profileName => 'Name';

  @override
  String get nameRequired => 'Gib einen Namen ein';

  @override
  String get pinLabel => 'PIN (4–6 Ziffern)';

  @override
  String get pinConfirmLabel => 'PIN wiederholen';

  @override
  String get pinInvalid => 'Verwende 4–6 Ziffern';

  @override
  String get pinMismatch => 'Die PINs stimmen nicht überein';

  @override
  String get pinHint =>
      'Deine PIN schützt dieses Profil auf einem geteilten Handy. Wenn du sie vergisst, kann das Profil nur gelöscht werden.';

  @override
  String get create => 'Erstellen';

  @override
  String get unlock => 'Entsperren';

  @override
  String enterPinFor(String name) {
    return 'PIN für $name';
  }

  @override
  String pinWrong(int left) {
    String _temp0 = intl.Intl.pluralLogic(
      left,
      locale: localeName,
      other: 'Falsche PIN. Noch $left Versuche bis zur Pause.',
      one: 'Falsche PIN. Noch 1 Versuch bis zur Pause.',
    );
    return '$_temp0';
  }

  @override
  String pinLocked(int seconds) {
    return 'Zu viele Versuche. Versuch es in $seconds s erneut.';
  }

  @override
  String get forgotPin => 'PIN vergessen?';

  @override
  String deleteProfileTitle(String name) {
    return '$name löschen?';
  }

  @override
  String get deleteProfileBody =>
      'Eine vergessene PIN lässt sich nicht wiederherstellen. Beim Löschen werden dieses Profil und alle Mahlzeiten, das Tagebuch und der Chatverlauf von diesem Handy entfernt. Das kann nicht rückgängig gemacht werden.';

  @override
  String get delete => 'Löschen';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get lock => 'Sperren';

  @override
  String hello(String name) {
    return 'Hallo, $name';
  }

  @override
  String get deviceUnsupportedTitle => 'Dieses Handy wird nicht unterstützt';

  @override
  String deviceUnsupportedBody(String gb) {
    return 'MyFoodMind führt seine KI vollständig auf deinem Handy aus und braucht mindestens 6 GB RAM. Dieses Handy hat etwa $gb GB.';
  }

  @override
  String get chatHint => 'Frag nach Essen, trag eine Mahlzeit ein…';

  @override
  String get send => 'Senden';

  @override
  String get preparingAi =>
      'Die KI auf dem Gerät wird vorbereitet… Der erste Start dauert etwa eine Minute.';

  @override
  String get confirmSave => 'Speichern';

  @override
  String get confirmDiscard => 'Verwerfen';

  @override
  String get confirmSaved => 'Gespeichert';

  @override
  String get confirmDiscarded => 'Verworfen';

  @override
  String get perServing => 'Pro Portion';

  @override
  String minutesServings(int minutes, int servings) {
    return '$minutes Min. · $servings Portionen';
  }

  @override
  String get notMedicalAdvice =>
      'Allgemeine Informationen aus veröffentlichten Leitlinien, keine medizinische Beratung. Sie ersetzen nicht deine Ärztin, deinen Arzt oder deine Ernährungsberatung: Sprich mit ihnen, bevor du deine Ernährung oder Medikamente änderst.';

  @override
  String get chatDisclaimer =>
      'KI-Antworten können falsch sein und ersetzen keinen Arzt. Ruf im Notfall die örtliche Notrufnummer an.';

  @override
  String get medicalDisclaimerTitle => 'Medizinischer Hinweis';

  @override
  String get medicalDisclaimerBody =>
      'MyFoodMind und sein KI-Assistent geben allgemeine Informationen zu Essen und Ernährung. Die App ist kein Medizinprodukt und dient nicht dazu, Krankheiten zu erkennen, zu behandeln, zu heilen oder ihnen vorzubeugen.\n\nNichts in der App, auch nicht die Antworten des Assistenten, die Grenzwerte für Erkrankungen und die Gesundheitsinformationen, ersetzt den Rat einer Ärztin, eines Arztes, einer Ernährungsfachkraft oder anderer medizinischer Fachleute. Die KI läuft auf deinem Handy und kann Fehler machen.\n\nSprich immer mit deiner Ärztin oder deinem Arzt, bevor du Ernährung, Medikamente oder Behandlung änderst, besonders wenn du eine Erkrankung hast, schwanger bist oder stillst oder eine Essstörung hast oder hattest. Ignoriere nie fachlichen Rat und schiebe ihn nie wegen etwas in dieser App auf.\n\nWenn du glaubst, dass es ein medizinischer Notfall ist, ruf sofort die örtliche Notrufnummer an.';

  @override
  String get crisisTitle => 'Du musst das nicht allein durchstehen';

  @override
  String get crisisBody =>
      'Wenn du dir etwas antun könntest, ruf jetzt deine örtliche Notrufnummer an. Kostenlose, vertrauliche Hilfetelefone in deinem Land findest du auf findahelpline.com.';

  @override
  String get crisisButton => 'Hilfetelefon finden';

  @override
  String limitReached(int count) {
    return 'Du hast die $count kostenlosen KI-Nachrichten für heute verbraucht. Sie werden um Mitternacht zurückgesetzt, oder du chattest mit Basic unbegrenzt.';
  }

  @override
  String get agentError =>
      'Etwas ist schiefgelaufen. Bitte versuch es noch einmal.';

  @override
  String get reportResponse => 'Diese Antwort melden';

  @override
  String get kcal => 'kcal';

  @override
  String get protein => 'Eiweiß';

  @override
  String get fat => 'Fett';

  @override
  String get carbs => 'Kohlenhydrate';

  @override
  String get fiber => 'Ballaststoffe';

  @override
  String get sugar => 'Zucker';

  @override
  String get sodium => 'Natrium';

  @override
  String get recipeIdeas => 'Rezeptideen';

  @override
  String get ingredients => 'Zutaten';

  @override
  String get steps => 'Schritte';

  @override
  String get healthInfo => 'Gesundheitsinformation';

  @override
  String servingsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Portionen',
      one: '1 Portion',
    );
    return '$_temp0';
  }

  @override
  String get iAteThis => 'Das habe ich gegessen';

  @override
  String get aiKnowsTitle => 'Was die KI über dich weiß';

  @override
  String get aiKnowsIntro =>
      'Das ist alles, was dem Assistenten über dich gesagt wird. Es bleibt auf diesem Handy.';

  @override
  String get factsSection => 'Was du ihr erzählt hast';

  @override
  String get factsEmpty =>
      'Noch nichts. Erzähl dem Chat z. B. „Ich habe eine Heißluftfritteuse“.';

  @override
  String get allergiesSection => 'Allergien und Ernährung';

  @override
  String get allergiesEmpty => 'Keine eingetragen.';

  @override
  String get habitsSection =>
      'Gewohnheiten, die sie bemerkt hat (letzte 30 Tage)';

  @override
  String get habitsEmpty => 'Noch nicht genug Mahlzeiten eingetragen.';

  @override
  String get conversationsSection => 'Unterhaltungen';

  @override
  String conversationsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Nachrichten gespeichert.',
      one: '1 Nachricht gespeichert.',
      zero: 'Keine Nachrichten gespeichert.',
    );
    return '$_temp0';
  }

  @override
  String get forgetConversations => 'Frühere Unterhaltungen vergessen';

  @override
  String get forgetConversationsBody =>
      'Löscht deinen Chatverlauf und die Erinnerung der KI daran. Eingetragene Mahlzeiten, Fakten und Allergien bleiben.';

  @override
  String get forget => 'Vergessen';

  @override
  String get edit => 'Bearbeiten';

  @override
  String get tabToday => 'Heute';

  @override
  String get tabChat => 'Chat';

  @override
  String get tabLog => 'Eintragen';

  @override
  String get tabMe => 'Ich';

  @override
  String eatenOfGoal(int goal) {
    return 'von $goal kcal';
  }

  @override
  String kcalLeft(int left) {
    return 'Noch $left kcal';
  }

  @override
  String kcalOver(int over) {
    return '$over kcal zu viel';
  }

  @override
  String overBy(String amount) {
    return '$amount zu viel';
  }

  @override
  String get eatenToday => 'Heute gegessen';

  @override
  String get setGoalsTitle => 'Lege deine Tagesziele fest';

  @override
  String get setGoalsBody =>
      'Erzähl ein wenig über dich, um Ziele für Kalorien und Nährstoffe zu bekommen.';

  @override
  String get setGoalsButton => 'Ziele festlegen';

  @override
  String get todaysMeals => 'Mahlzeiten heute';

  @override
  String get noMealsYet =>
      'Noch nichts eingetragen. Nutze den Tab „Eintragen“ oder erzähl dem Chat, was du gegessen hast.';

  @override
  String get deleteMealTitle => 'Diesen Eintrag löschen?';

  @override
  String get mealBreakfast => 'Frühstück';

  @override
  String get mealLunch => 'Mittagessen';

  @override
  String get mealDinner => 'Abendessen';

  @override
  String get mealSnack => 'Snack';

  @override
  String get searchFood => 'Lebensmittel, Gerichte, Rezepte suchen…';

  @override
  String get kindFood => 'Lebensmittel';

  @override
  String get kindDish => 'Gericht';

  @override
  String get kindRecipe => 'Rezept';

  @override
  String get kindProduct => 'Produkt';

  @override
  String perServing2(int kcal) {
    return '$kcal kcal pro Portion';
  }

  @override
  String per100g(int kcal) {
    return '$kcal kcal pro 100 g';
  }

  @override
  String get servings => 'Portionen';

  @override
  String get grams => 'Gramm';

  @override
  String get logButton => 'Eintragen';

  @override
  String loggedSnack(String label) {
    return '$label eingetragen';
  }

  @override
  String get noResults => 'Kein Treffer in der Lebensmitteldatenbank.';

  @override
  String get goalsTitle => 'Deine Tagesziele';

  @override
  String get goalsIntro =>
      'Damit werden deine Ziele für Kalorien und Nährstoffe berechnet. Bleibt auf diesem Handy.';

  @override
  String get later => 'Später';

  @override
  String get units => 'Einheiten';

  @override
  String get metric => 'Metrisch';

  @override
  String get imperial => 'Imperial';

  @override
  String get sex => 'Geschlecht für die Formel';

  @override
  String get female => 'Weiblich';

  @override
  String get male => 'Männlich';

  @override
  String get other => 'Divers';

  @override
  String get birthYear => 'Geburtsjahr';

  @override
  String get heightCm => 'Größe (cm)';

  @override
  String get heightFt => 'ft';

  @override
  String get heightIn => 'in';

  @override
  String get weightKg => 'Gewicht (kg)';

  @override
  String get weightLb => 'Gewicht (lb)';

  @override
  String get activity => 'Aktivität';

  @override
  String get activitySedentary => 'Sitzend: meist im Sitzen';

  @override
  String get activityLight => 'Leicht: Sport an 1–3 Tagen pro Woche';

  @override
  String get activityModerate => 'Mäßig: Sport an 3–5 Tagen pro Woche';

  @override
  String get activityActive => 'Aktiv: Sport an 6–7 Tagen pro Woche';

  @override
  String get activityVeryActive =>
      'Sehr aktiv: hartes tägliches Training oder körperliche Arbeit';

  @override
  String get goal => 'Ziel';

  @override
  String get goalLose => 'Abnehmen';

  @override
  String get goalMaintain => 'Gewicht halten';

  @override
  String get goalGain => 'Zunehmen';

  @override
  String get invalidNumber => 'Gib eine gültige Zahl ein';

  @override
  String get under18 =>
      'Für Menschen unter 18 gelten diese Formeln nicht. Lege die Ziele unten mit deiner Kinderärztin oder deinem Kinderarzt fest.';

  @override
  String get aboutMe => 'Über mich';

  @override
  String get sexShort => 'Geschlecht';

  @override
  String get height => 'Größe';

  @override
  String get weight => 'Gewicht';

  @override
  String get targetsNone => 'Noch keine Ziele.';

  @override
  String get custom => 'eigenes';

  @override
  String editTarget(String name) {
    return 'Ziel: $name';
  }

  @override
  String get resetTarget => 'Berechneten Wert nutzen';

  @override
  String get editDetails => 'Meine Angaben bearbeiten';

  @override
  String get aiKnowsLoading => 'Verfügbar, sobald die KI geladen ist.';

  @override
  String get switchProfile => 'Sperren und Profil wechseln';

  @override
  String get limitSuffix => 'max.';

  @override
  String get remindersTitle => 'Erinnerungen';

  @override
  String get remindersHint =>
      'Die Zeiten passen sich deinen üblichen Essenszeiten an, sobald du ein paar Mahlzeiten eingetragen hast.';

  @override
  String get reminderBreakfast => 'Frühstück eintragen';

  @override
  String get reminderLunch => 'Mittagessen eintragen';

  @override
  String get reminderDinner => 'Abendessen eintragen';

  @override
  String get reminderEvening => 'Abend-Check';

  @override
  String notifMeal(String name, String meal) {
    return '$name, Zeit, dein $meal einzutragen?';
  }

  @override
  String notifEvening(String name) {
    return '$name, wie war dein Tag? Deine Zusammenfassung ist bereit.';
  }

  @override
  String get notificationsDenied =>
      'Benachrichtigungen für MyFoodMind sind in den Android-Einstellungen ausgeschaltet.';

  @override
  String get voiceInput => 'Sprechen';

  @override
  String get voiceStop => 'Zuhören beenden';

  @override
  String get voiceUnavailable =>
      'Spracheingabe braucht die Offline-Spracherkennung auf diesem Handy (Google-App → Einstellungen → Sprache → Offline-Spracherkennung → Deutsch). MyFoodMind sendet deine Stimme nie ins Internet.';

  @override
  String youSaid(String text) {
    return 'Du hast gesagt: $text';
  }

  @override
  String aiSaid(String text) {
    return 'MyFoodMind hat gesagt: $text';
  }

  @override
  String get useFingerprint => 'Fingerabdruck verwenden';

  @override
  String get fingerprintTitle => 'Mit Fingerabdruck entsperren';

  @override
  String get fingerprintHint =>
      'Nur solange dies das einzige Profil auf dem Handy ist: Android kann nicht erkennen, wessen Fingerabdruck es ist.';

  @override
  String fingerprintReason(String name) {
    return 'Profil von $name entsperren';
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
  String get plansTitle => 'Tarife';

  @override
  String get monthly => 'Monatlich';

  @override
  String get yearly => 'Jährlich';

  @override
  String perMonth(String price) {
    return '$price / Monat';
  }

  @override
  String perYear(String price) {
    return '$price / Jahr';
  }

  @override
  String trialThen(String price) {
    return '7 Tage kostenlos, dann $price';
  }

  @override
  String get subscribe => 'Abonnieren';

  @override
  String get upgrade => 'Upgrade';

  @override
  String get switchPlan => 'Wechseln';

  @override
  String get currentPlan => 'Aktueller Tarif';

  @override
  String get restorePurchases => 'Käufe wiederherstellen';

  @override
  String get subscriptionTerms =>
      'Abos verlängern sich automatisch, bis du sie kündigst. Kündigen jederzeit in Google Play → Zahlungen und Abos. Ein Abo gilt für alle Profile auf diesem Handy.';

  @override
  String get devBillingBanner =>
      'Entwicklermodus: keine echte Zahlung. Wähle einen beliebigen Tarif zum Ausprobieren.';

  @override
  String get devBackToFree => 'Zurück zu Free (Entwickler)';

  @override
  String get purchaseFailed =>
      'Der Kauf hat nicht geklappt. Bitte versuch es noch einmal.';

  @override
  String get featBasic1 => 'Unbegrenzter KI-Chat';

  @override
  String get featBasic2 => 'Wochen- und Monatsübersicht';

  @override
  String get featBasic3 => 'Mikronährstoffe, Serien, Gewichtsverlauf';

  @override
  String get featMedium1 => 'Alles aus Basic';

  @override
  String get featMedium2 => 'Erkrankungen: Ernährungsgrenzen und Vorschläge';

  @override
  String get featMedium3 =>
      'Tagebuch für Symptome und Messwerte, Export für die Ärztin/den Arzt';

  @override
  String get featPro1 => 'Alles aus Medium';

  @override
  String get featPro2 => 'Lebensmittelerkennung per Foto und Live-Kamera';

  @override
  String get featPro3 =>
      'Trägt Mahlzeiten ein und findet Rezepte zu dem, was sie sieht';

  @override
  String get yourPlan => 'Dein Tarif';

  @override
  String get seePlans => 'Tarife ansehen';

  @override
  String get periodDay => 'Tag';

  @override
  String get periodWeek => 'Woche';

  @override
  String get periodMonth => 'Monat';

  @override
  String get lockedTitle => 'Wochen- und Monatstrends gibt es in Basic';

  @override
  String get lockedBody =>
      'Sieh Kalorien pro Tag im Vergleich zu deinem Ziel, Tagesdurchschnitte, Mikronährstoffe, deine Eintragsserie und deinen Gewichtsverlauf.';

  @override
  String get caloriesPerDay => 'Kalorien pro Tag';

  @override
  String goalLine(int kcal) {
    return 'Ziel $kcal';
  }

  @override
  String dailyAverage(int days) {
    return 'Tagesdurchschnitt ($days Tage mit Einträgen)';
  }

  @override
  String streakDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days Tage Eintragsserie',
      one: '1 Tag Eintragsserie',
      zero: 'Noch keine Eintragsserie',
    );
    return '$_temp0';
  }

  @override
  String get weightTrend => 'Gewicht';

  @override
  String get weightTrendEmpty =>
      'Trag dein Gewicht mindestens zweimal ein, um den Verlauf zu sehen.';

  @override
  String get logWeight => 'Gewicht eintragen';

  @override
  String get weightLogged => 'Gewicht gespeichert';

  @override
  String get plansUnavailable => 'Tarife sind in diesem Build nicht verfügbar.';

  @override
  String cautionAllergy(String food, String allergen) {
    return 'Enthält $food, das deine Allergien oder Ernährungsweise ausschließen ($allergen)';
  }

  @override
  String cautionCondition(String food, String condition) {
    return 'Enthält $food, bei $condition zu meiden';
  }

  @override
  String get condDiabetesT2 => 'Typ-2-Diabetes';

  @override
  String get condHypertension => 'Bluthochdruck';

  @override
  String get condGout => 'Gicht';

  @override
  String get condAls => 'ALS';

  @override
  String get condMs => 'Multiple Sklerose';

  @override
  String get healthTitle => 'Gesundheit';

  @override
  String get healthMeHint =>
      'Erkrankungen, Tagebuch, Verlauf, Bericht für deine Ärztin/deinen Arzt';

  @override
  String get conditionsTitle => 'Erkrankungen';

  @override
  String get conditionsHint =>
      'Rezeptvorschläge lassen zu meidende Lebensmittel weg, und Grenzwerte senken deine Tagesziele. Das sind allgemeine Vorschläge, keine medizinische Beratung: Sprich mit deiner Ärztin oder deinem Arzt, bevor du deine Ernährung änderst.';

  @override
  String limitLine(String nutrient, String amount, String condition) {
    return '$nutrient: höchstens $amount pro Tag ($condition)';
  }

  @override
  String avoidLine(String foods) {
    return 'Zu meiden: $foods';
  }

  @override
  String limitFrom(String condition) {
    return 'Grenze wegen $condition';
  }

  @override
  String get timelineTitle => 'Verlauf';

  @override
  String get timelineHint => 'Nährstoffe, Messwerte und Symptome nach Datum';

  @override
  String get timelineEmpty => 'In diesem Zeitraum wurde nichts erfasst.';

  @override
  String get reportButton => 'Bericht für die Ärztin/den Arzt';

  @override
  String get reportHint => 'PDF und CSV deiner Einträge';

  @override
  String get journalTitle => 'Tagebuch';

  @override
  String get journalHint => 'Letzte 14 Tage';

  @override
  String get journalEmpty => 'In den letzten 14 Tagen wurde nichts erfasst.';

  @override
  String get symptom => 'Symptom';

  @override
  String get symptomHint => 'Was spürst du? z. B. Müdigkeit';

  @override
  String get severity => 'Stärke (optional)';

  @override
  String get severityHint => '1 = leicht, 5 = stark';

  @override
  String get glucose => 'Blutzucker';

  @override
  String get bloodPressure => 'Blutdruck';

  @override
  String get systolic => 'Systolisch (oberer Wert)';

  @override
  String get diastolic => 'Diastolisch (unterer Wert)';

  @override
  String get deleteEntryTitle => 'Diesen Eintrag löschen?';

  @override
  String get healthLockedTitle => 'Gesundheits-Tracking gehört zu Medium';

  @override
  String get healthLockedBody =>
      'Medium bringt Erkrankungen (Rezeptfilter und Tagesgrenzen), ein Tagebuch für Symptome und Messwerte, Verlaufsdiagramme und einen Bericht für deine Ärztin oder deinen Arzt.';

  @override
  String conditionsStillApply(String conditions) {
    return 'Deine Erkrankungen filtern weiterhin Rezepte und begrenzen deine Ziele: $conditions';
  }

  @override
  String days(int count) {
    return '$count Tage';
  }

  @override
  String get perDay => 'pro Tag';

  @override
  String get symptomsTitle => 'Symptome';

  @override
  String get readingsTitle => 'Messwerte';

  @override
  String get reportSheetHint =>
      'Ein PDF zum Lesen und eine CSV für Tabellen mit allem, was du eingetragen hast. Du entscheidest, wohin sie gehen; die App teilt nichts von sich aus.';

  @override
  String get reportShare => 'Erstellen und teilen';

  @override
  String get reportSubject => 'MyFoodMind-Bericht';

  @override
  String get reportFailed => 'Der Bericht konnte nicht erstellt werden.';

  @override
  String reportTitle(String name) {
    return 'MyFoodMind-Bericht: $name';
  }

  @override
  String reportCreated(String date) {
    return 'erstellt am $date';
  }

  @override
  String get reportDisclaimer =>
      'Von der Person selbst in der App MyFoodMind erfasst. Die Werte werden wie eingetragen gezeigt; die App deutet sie nicht und gibt keine medizinische Beratung. Grenzwerte stammen aus den gewählten Erkrankungen.';

  @override
  String get reportNone => 'Nichts erfasst.';

  @override
  String reportDailyNutrition(int days) {
    return 'Ernährung pro Tag ($days Tage mit Einträgen)';
  }

  @override
  String get reportDate => 'Datum';

  @override
  String get reportItems => 'Einträge';

  @override
  String get reportMeasurement => 'Messwert';

  @override
  String get reportValue => 'Wert';

  @override
  String get cameraTitle => 'Kamera';

  @override
  String get cameraOpen => 'Kamera öffnen';

  @override
  String get cameraPhoto => 'Foto';

  @override
  String get cameraLive => 'Live';

  @override
  String get cameraUnavailable =>
      'Die Kamera ist nicht verfügbar. Erlaube MyFoodMind in den Android-Einstellungen den Kamerazugriff.';

  @override
  String get cameraShoot => 'Foto aufnehmen';

  @override
  String get cameraNaming => 'Essen wird erkannt…';

  @override
  String get cameraNamingFailed =>
      'KI-Erkennung fehlgeschlagen: stattdessen Schnellerkennung. Prüfe die Einträge.';

  @override
  String cameraUseFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Einträge übernehmen',
      one: '1 Eintrag übernehmen',
      zero: 'Weiter',
    );
    return '$_temp0';
  }

  @override
  String get reviewTitle => 'Prüfe, was erkannt wurde';

  @override
  String get reviewHint =>
      'Mengen aus einem Foto sind Schätzungen (≈). Ändere oder entferne alles; gespeichert wird erst, wenn du auf „Eintragen“ tippst.';

  @override
  String get reviewEmpty =>
      'Kein Essen erkannt. Füge Einträge per Namen hinzu.';

  @override
  String notInDatabase(String name) {
    return '$name: nicht in der Datenbank, tippe auf Bearbeiten, um ein Lebensmittel zu wählen';
  }

  @override
  String get reviewChange => 'Ändern';

  @override
  String get reviewAdd => 'Eintrag hinzufügen';

  @override
  String get reviewLog => 'Mahlzeit eintragen';

  @override
  String reviewLogged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Einträge gespeichert',
      one: '1 Eintrag gespeichert',
    );
    return '$_temp0';
  }

  @override
  String get reviewCook => 'Was kann ich kochen?';

  @override
  String get yourRating => 'Deine Bewertung';

  @override
  String get kindRecent => 'Zuletzt';

  @override
  String get recentFoods => 'Zuletzt und häufig';

  @override
  String repeatYesterday(String meal, int kcal) {
    return '$meal von gestern · $kcal kcal';
  }

  @override
  String get quickAdd => 'Schnell hinzufügen';

  @override
  String get quickAddName => 'Name (optional)';

  @override
  String get editMeal => 'Eintrag bearbeiten';

  @override
  String get appearance => 'Darstellung';

  @override
  String cardLogMeal(String meal) {
    return '$meal eintragen';
  }

  @override
  String get cardSaveRecipe => 'Rezept speichern';

  @override
  String get cardRateRecipe => 'Rezept bewerten';

  @override
  String get cardRemember => 'Merken';

  @override
  String get cardAddAllergy => 'Allergie hinzufügen';

  @override
  String get cardRemoveAllergy => 'Allergie entfernen';

  @override
  String get cardAddDiet => 'Ernährungsweise hinzufügen';

  @override
  String get cardRemoveDiet => 'Ernährungsweise entfernen';

  @override
  String get captionConfirm => 'Prüfe es und tippe auf „Speichern“.';

  @override
  String get captionIdeas =>
      'Hier sind ein paar Ideen. Tippe auf eine, um das Rezept zu sehen.';

  @override
  String captionIdeasAvoiding(String foods) {
    return 'Achtung: Du bist allergisch gegen $foods oder meidest es, deshalb habe ich es weggelassen. Hier sind Rezepte ohne; tippe auf eins, um es zu sehen.';
  }

  @override
  String get captionRecipe => 'Hier ist das Rezept.';

  @override
  String get captionNumbers => 'Hier sind die Werte.';

  @override
  String get captionCamera =>
      'Tippe auf die Schaltfläche, um die Kamera zu öffnen.';

  @override
  String get cardLogSymptom => 'Symptom eintragen';

  @override
  String get cardLogGlucose => 'Blutzucker eintragen';

  @override
  String get cardLogBloodPressure => 'Blutdruck eintragen';

  @override
  String get cardLogWater => 'Wasser eintragen';

  @override
  String get last7Days => 'Letzte 7 Tage';

  @override
  String get weekReviewTitle => 'Deine Woche';

  @override
  String reviewLoggedDays(int days) {
    return 'Du hast an $days von 7 Tagen Essen eingetragen.';
  }

  @override
  String reviewKcal(int avg, int goal) {
    return 'An diesen Tagen: durchschnittlich $avg kcal, Ziel $goal.';
  }

  @override
  String reviewUnder(String nutrient, int days) {
    return '$nutrient an $days Tagen unter 80 % deines Ziels.';
  }

  @override
  String reviewOver(String nutrient, int days) {
    return '$nutrient an $days Tagen über deiner Grenze.';
  }

  @override
  String reviewWater(int avg, int goal) {
    return 'Wasser: $avg ml pro Tag, Ziel $goal ml.';
  }

  @override
  String reviewTop(String food) {
    return 'Am häufigsten: $food.';
  }

  @override
  String get reviewIdeas => 'Ideen für nächste Woche';

  @override
  String reviewAskHigh(String nutrient) {
    return 'Schlag Rezepte mit viel $nutrient vor';
  }

  @override
  String reviewAskLow(String nutrient) {
    return 'Schlag Rezepte mit wenig $nutrient vor';
  }

  @override
  String get calcium => 'Calcium';

  @override
  String get iron => 'Eisen';

  @override
  String get magnesium => 'Magnesium';

  @override
  String get potassium => 'Kalium';

  @override
  String get vitaminC => 'Vitamin C';

  @override
  String get vitaminD => 'Vitamin D';

  @override
  String get vitaminB12 => 'Vitamin B12';

  @override
  String get microsTitle => 'Vitamine und Mineralstoffe';

  @override
  String microsCoverage(int known, int meals) {
    return 'Aus $known von $meals Mahlzeiten mit bekannten Werten; EU-Referenzmengen';
  }

  @override
  String get productsTitle => 'Verpackte Produkte';

  @override
  String get productsNone =>
      'Eingebaut: Produkte von 2019, wenige europäische. Lade alle Produkte von Open Food Facts (alle Länder), um zu finden, was du kaufst. WLAN empfohlen.';

  @override
  String productsHave(String count, String date) {
    return '$count Produkte von Open Food Facts, Stand $date.';
  }

  @override
  String productsDownload(int mb) {
    return 'Herunterladen ($mb MB)';
  }

  @override
  String get productsRemove => 'Entfernen';

  @override
  String get productsHint =>
      'Fehlt ein verpacktes Produkt? Lade alle Produkte unter „Ich“.';

  @override
  String get healthConnect => 'Health Connect';

  @override
  String get appleHealth => 'Apple Health';

  @override
  String get healthSyncHint =>
      'Liest dein Gewicht (für deine Ziele) und deine Schritte. Dort wird nichts geschrieben, und nichts verlässt dein Handy.';

  @override
  String get healthSyncDenied =>
      'Kein Zugriff. Erlaube Gewicht und Schritte in den Einstellungen der Gesundheits-App und versuch es erneut.';

  @override
  String stepsToday(String steps) {
    return '$steps Schritte heute';
  }

  @override
  String get mealPlan => 'Essensplan';

  @override
  String get planTab => 'Plan';

  @override
  String get planEmpty =>
      'Plane deine Woche: Frühstück, Mittag- und Abendessen aus der Rezeptdatenbank, passend zu deinem Kalorienziel, ohne deine Allergene und zuerst mit Rezepten, die du gut bewertet hast.';

  @override
  String get planWeek => 'Meine Woche planen';

  @override
  String get planAgain => 'Neu planen';

  @override
  String get planSwap => 'Anderes Rezept';

  @override
  String get planCardEmpty =>
      'Plane deine Woche und erhalte eine Einkaufsliste';

  @override
  String get makeShoppingList => 'Einkaufsliste';

  @override
  String get shoppingList => 'Einkauf';

  @override
  String get shoppingAdd => 'Eintrag hinzufügen';

  @override
  String get shoppingEmpty =>
      'Nichts zu kaufen. Erstelle eine Liste aus deinem Plan oder füge die Zutaten eines Rezepts im Rezept hinzu.';

  @override
  String get clearTicked => 'Abgehakte entfernen';

  @override
  String get addToShopping => 'Auf die Einkaufsliste';

  @override
  String get addedToShopping => 'Zur Einkaufsliste hinzugefügt';

  @override
  String waterLine(int ml, int goal) {
    return 'Wasser $ml / $goal ml';
  }

  @override
  String get waterAddGlass => 'Ein Glas hinzufügen (250 ml)';

  @override
  String get waterUndo => 'Letztes Glas zurücknehmen';

  @override
  String get waterGoal => 'Tägliches Wasserziel';

  @override
  String get fasting => 'Fasten';

  @override
  String fastingLine(int h, int m, int target) {
    return 'Fasten $h Std. $m Min. von $target Std.';
  }

  @override
  String get fastStart => 'Jetzt starten';

  @override
  String fastSinceMeal(String time) {
    return 'Seit der letzten Mahlzeit ($time)';
  }

  @override
  String get fastEnd => 'Fasten beenden';

  @override
  String get fastDone =>
      'Ziel erreicht. Beende das Fasten, wann immer du isst.';

  @override
  String get fastingSwitch => 'Fasten-Timer';

  @override
  String get fastingCaution =>
      'Nicht empfohlen in der Schwangerschaft, bei einer Essstörung oder bei Diabetes, der mit Insulin oder Sulfonylharnstoffen behandelt wird. Frag zuerst deine Ärztin oder deinen Arzt.';

  @override
  String get widgetKcalTitle => 'Kalorien im Startbildschirm-Widget';

  @override
  String get widgetKcalHint =>
      'Füge das MyFoodMind-Widget zu deinem Startbildschirm hinzu. Die heutigen Kalorien sind dann dort ohne PIN sichtbar.';

  @override
  String get welcomeTitle => 'Trag deine erste Mahlzeit ein';

  @override
  String get welcomeBody =>
      'Schreib oder sag es im Chat („Ich hatte 2 Eier und Toast“), such es unter „Eintragen“ oder mach ein Foto. Dein Tag füllt sich hier.';

  @override
  String nextMealTitle(String meal) {
    return '$meal noch nicht eingetragen';
  }

  @override
  String get nextMealBody =>
      'Trag ein, was du gegessen hast, oder hol dir eine Idee, was du essen kannst.';

  @override
  String get getIdea => 'Idee holen';

  @override
  String get logIt => 'Eintragen';

  @override
  String get language => 'Sprache';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Hell';

  @override
  String get themeDark => 'Dunkel';

  @override
  String get wallpaperColors => 'Hintergrundfarben';

  @override
  String get wallpaperColorsHint =>
      'Die Farben deines Handys verwenden (ab Android 12).';

  @override
  String suggestAte(String food) {
    return 'Ich habe $food gegessen';
  }

  @override
  String suggestIdea(String meal) {
    return 'Etwas Neues zum $meal';
  }

  @override
  String get suggestLeft => 'Was ist für heute noch übrig?';

  @override
  String rateStars(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Mit $count Sternen bewerten',
      one: 'Mit 1 Stern bewerten',
    );
    return '$_temp0';
  }

  @override
  String get recipesYouAte => 'Rezepte, die du gegessen hast';

  @override
  String get recipesYouAteHint =>
      'Tippe eins an, um es wieder zu sehen und zu bewerten. Rezeptideen folgen deinen Sternen.';

  @override
  String get cookNone =>
      'Kein Rezept in der Datenbank verwendet diese Lebensmittel.';

  @override
  String get per100Suffix => ' / 100 g';

  @override
  String get aiDownloadTitle => 'KI-Assistenten herunterladen';

  @override
  String aiDownloadBody(String gb) {
    return 'Der Chat-Assistent läuft vollständig auf deinem Handy. Sein Modell ($gb GB) wird einmalig von Hugging Face geladen; nutze WLAN. Nichts über dich wird gesendet. Eintragen, Rezepte und deine Übersicht funktionieren schon ohne ihn.';
  }

  @override
  String get aiDownloadButton => 'Herunterladen';

  @override
  String get aiModelTitle => 'KI-Modell';

  @override
  String aiModelStandard(String gb) {
    return 'Standard · $gb GB';
  }

  @override
  String get aiModelStandardHint =>
      'Schnellere Antworten. Läuft auf jedem unterstützten Handy.';

  @override
  String aiModelLarge(String gb) {
    return 'Größer · $gb GB';
  }

  @override
  String get aiModelLargeHint =>
      'Versteht mehr, antwortet etwa 2–3-mal langsamer. Für Handys mit 12 GB RAM.';

  @override
  String get aiModelSwitch => 'Wechseln';

  @override
  String get aiModelSwitchBody =>
      'Zuerst wird das andere Modell geladen; das aktuelle wird gelöscht, wenn das fertig ist.';

  @override
  String get aiModelInUse => 'In Verwendung';

  @override
  String get aiDownloading => 'Wird heruntergeladen';

  @override
  String get aiDownloadFailed =>
      'Der Download wurde unterbrochen. Prüfe die Verbindung und den freien Speicher und versuch es erneut; er setzt dort fort, wo er aufgehört hat.';

  @override
  String get downloadNoWifiTitle => 'Kein WLAN';

  @override
  String downloadNoWifiBody(int mb) {
    return 'Du bist nicht mit einem WLAN verbunden. Der Download ist $mb MB groß; über mobile Daten kann er dein Datenvolumen aufbrauchen oder Kosten verursachen.';
  }

  @override
  String get downloadWaitWifi => 'Auf WLAN warten';

  @override
  String get downloadUseMobile => 'Mobile Daten nutzen';

  @override
  String get downloadOnMobile =>
      'Mobile Daten erlaubt: Dieser Download kann dein Datenvolumen verbrauchen.';

  @override
  String get downloadWaitingWifi => 'Wartet auf WLAN';

  @override
  String get downloadWaitingNetwork => 'Wartet auf eine Verbindung';

  @override
  String get downloadRetrying =>
      'Verbindung verloren; es geht weiter, sobald sie wieder da ist';

  @override
  String get downloadPaused => 'Pausiert';

  @override
  String get downloadInstalling => 'Wird installiert …';

  @override
  String get downloadPause => 'Pausieren';

  @override
  String get downloadResume => 'Fortsetzen';

  @override
  String get privacyPolicy => 'Datenschutzerklärung';

  @override
  String get termsOfUse => 'Nutzungsbedingungen';

  @override
  String get licenses => 'Lizenzen und KI-Modelle';

  @override
  String get settingsTitle => 'Einstellungen';

  @override
  String get drawerFood => 'Essen';

  @override
  String get drawerAssistant => 'Assistent';

  @override
  String get shoppingListNav => 'Einkaufsliste';

  @override
  String get healthJournalNav => 'Gesundheitstagebuch und Bericht';

  @override
  String get settingsAi => 'KI und Daten';

  @override
  String get settingsTracking => 'Tracking';

  @override
  String get settingsPrivacy => 'Datenschutz und Sicherheit';

  @override
  String get settingsAbout => 'Über die App';

  @override
  String get settingsDanger => 'Gefahrenbereich';

  @override
  String get deleteThisProfile => 'Dieses Profil löschen';

  @override
  String get deleteThisProfileBody =>
      'Das Profil und alle seine Mahlzeiten, das Tagebuch und der Chatverlauf werden von diesem Telefon gelöscht. Das lässt sich nicht rückgängig machen.';
}
