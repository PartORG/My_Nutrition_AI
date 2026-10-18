// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'My Nutrition AI';

  @override
  String get addProfile => 'Profil erstellen';

  @override
  String get googleWrongAccount =>
      'Das ist nicht das Google-Konto, mit dem dieses Profil erstellt wurde.';

  @override
  String get signInWithGoogle => 'Mit Google anmelden';

  @override
  String get continueWithGoogle => 'Weiter mit Google';

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
      'Deine PIN entsperrt die App, wenn der Fingerabdruck nicht klappt. Wenn du sie vergisst, kann das Profil nur gelöscht werden.';

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
    return 'My Nutrition AI führt seine KI vollständig auf deinem Handy aus und braucht mindestens 6 GB RAM. Dieses Handy hat etwa $gb GB.';
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
      'My Nutrition AI und sein KI-Assistent geben allgemeine Informationen zu Essen und Ernährung. Die App ist kein Medizinprodukt und dient nicht dazu, Krankheiten zu erkennen, zu behandeln, zu heilen oder ihnen vorzubeugen.\n\nNichts in der App, auch nicht die Antworten des Assistenten, die Grenzwerte für Erkrankungen und die Gesundheitsinformationen, ersetzt den Rat einer Ärztin, eines Arztes, einer Ernährungsfachkraft oder anderer medizinischer Fachleute. Die KI läuft auf deinem Handy und kann Fehler machen.\n\nSprich immer mit deiner Ärztin oder deinem Arzt, bevor du Ernährung, Medikamente oder Behandlung änderst, besonders wenn du eine Erkrankung hast, schwanger bist oder stillst oder eine Essstörung hast oder hattest. Ignoriere nie fachlichen Rat und schiebe ihn nie wegen etwas in dieser App auf.\n\nWenn du glaubst, dass es ein medizinischer Notfall ist, ruf sofort die örtliche Notrufnummer an.';

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
      'Benachrichtigungen für My Nutrition AI sind in den Android-Einstellungen ausgeschaltet.';

  @override
  String get voiceInput => 'Sprechen';

  @override
  String get voiceStop => 'Zuhören beenden';

  @override
  String get voiceUnavailable =>
      'Spracheingabe braucht die Offline-Spracherkennung auf diesem Handy (Google-App → Einstellungen → Sprache → Offline-Spracherkennung → Deutsch). My Nutrition AI sendet deine Stimme nie ins Internet.';

  @override
  String youSaid(String text) {
    return 'Du hast gesagt: $text';
  }

  @override
  String aiSaid(String text) {
    return 'My Nutrition AI hat gesagt: $text';
  }

  @override
  String get useFingerprint => 'Fingerabdruck verwenden';

  @override
  String get fingerprintTitle => 'Mit Fingerabdruck entsperren';

  @override
  String get fingerprintHint =>
      'Mit dem Fingerabdruck statt der PIN entsperren.';

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
  String get featBasic3 => 'Trink-Erinnerungen, Serien, Mikronährstoffe';

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
  String get lockedTitle => 'Mehr mit Basic';

  @override
  String get lockedBody =>
      'Deine Eintragsserie, ein Wochen-Essensplan mit Einkaufsliste, Trink-Erinnerungen und 3 Monate Verlauf.';

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
      'Trag dein Gewicht an zwei verschiedenen Tagen ein, um den Trend zu sehen.';

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
  String get reportSubject => 'My Nutrition AI-Bericht';

  @override
  String get reportFailed => 'Der Bericht konnte nicht erstellt werden.';

  @override
  String reportTitle(String name) {
    return 'My Nutrition AI-Bericht: $name';
  }

  @override
  String reportCreated(String date) {
    return 'erstellt am $date';
  }

  @override
  String get reportDisclaimer =>
      'Von der Person selbst in der App My Nutrition AI erfasst. Die Werte werden wie eingetragen gezeigt; die App deutet sie nicht und gibt keine medizinische Beratung. Grenzwerte stammen aus den gewählten Erkrankungen.';

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
      'Die Kamera ist gerade nicht verfügbar. Schließ andere Apps, die sie nutzen, und versuch es erneut.';

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
    return '$name: nicht in der Datenbank. Tippe auf Ändern, um ein Lebensmittel zu wählen.';
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
  String get changeFood => 'Lebensmittel ändern';

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
      'Liest dein Gewicht (für deine Ziele), deine Schritte und verbrannten Kalorien (unter Heute). Dort wird nichts geschrieben, und nichts verlässt dein Handy. Ausschalten trennt die Verbindung.';

  @override
  String get healthSyncDenied =>
      'Kein Zugriff. Erlaube Gewicht, Schritte und aktive Kalorien in den Einstellungen der Gesundheits-App und versuch es erneut.';

  @override
  String stepsToday(String steps) {
    return '$steps Schritte heute';
  }

  @override
  String get mealPlan => 'Essensplan';

  @override
  String get planTab => 'Plan';

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
      'Füge das My Nutrition AI-Widget zu deinem Startbildschirm hinzu. Die heutigen Kalorien sind dann dort ohne PIN sichtbar.';

  @override
  String get welcomeTitle => 'Trag deine erste Mahlzeit ein';

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
      'Versteht mehr und erkennt Essen auf Fotos besser; antwortet etwa 2–3-mal langsamer. Für Handys mit 12 GB RAM.';

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

  @override
  String get featBasic2 => 'Essensplan und Einkaufsliste';

  @override
  String get featBasic4 => '3 Monate Verlauf';

  @override
  String get featMedium4 => '8 Monate Verlauf';

  @override
  String get featPro4 => 'Jahresübersicht und 12 Monate Verlauf';

  @override
  String get periodYear => 'Jahr';

  @override
  String get yearLockedTitle => 'Die Jahresansicht gibt es in Pro';

  @override
  String get yearLockedBody =>
      'Zwölf Monate auf einen Blick: Kalorien pro Monat, ein Eintragskalender, Nährstoff-Durchschnitte mit deinem besten und schlechtesten Monat, dein Gewicht und was du am häufigsten gegessen hast.';

  @override
  String get yearCalories => 'Kalorien pro Tag, Monatsdurchschnitt';

  @override
  String get yearCalendar => 'Eintragskalender';

  @override
  String yearLoggedDays(int days, int best) {
    return '$days Tage eingetragen · längste Serie $best Tage';
  }

  @override
  String get yearNutrients => 'Tagesdurchschnitte im Jahr';

  @override
  String yearBestWorst(String nutrient, String best, String worst) {
    return '$nutrient: bester Monat $best, schlechtester $worst';
  }

  @override
  String get yearTopFoods => 'Am häufigsten gegessen';

  @override
  String get calendarOnGoal => 'Bis 10 % vom Ziel';

  @override
  String get calendarNear => 'Bis 25 %';

  @override
  String get calendarFar => 'Weiter weg';

  @override
  String get calendarNotLogged => 'Nicht eingetragen';

  @override
  String get historyTitle => 'Verlauf';

  @override
  String lastDays(int count) {
    return 'Letzte $count Tage';
  }

  @override
  String get pickDates => 'Daten wählen';

  @override
  String get historyEmpty => 'An diesen Tagen ist nichts eingetragen.';

  @override
  String historyLockedTitle(int days) {
    return 'Der Verlauf zeigt die letzten $days Tage';
  }

  @override
  String get historyLockedBody =>
      'Ältere Mahlzeiten bleiben auf deinem Handy. Basic zeigt 3 Monate, Medium 8 und Pro 12.';

  @override
  String get planLockedTitle => 'Den Essensplan gibt es in Basic';

  @override
  String get planLockedBody =>
      'Plane deine Woche mit Rezepten, die zu deinen Zielen und Allergenen passen, und mach daraus eine Einkaufsliste.';

  @override
  String get reminderWater => 'Wasser trinken';

  @override
  String reminderWaterHint(int count, String from, String to) {
    return '$count pro Tag, $from–$to: je ein Glas, um dein Wasserziel zu erreichen';
  }

  @override
  String get reminderWaterLocked => 'Trink-Erinnerungen gibt es in Basic';

  @override
  String notifWater(String name) {
    return '$name, Zeit für ein Glas Wasser.';
  }

  @override
  String get machineTranslated => 'Zutatennamen maschinell übersetzt';

  @override
  String get translateSteps => 'Schritte übersetzen';

  @override
  String get machineTranslatedSteps =>
      'Schritte auf deinem Handy maschinell übersetzt';

  @override
  String get showOriginal => 'Original zeigen';

  @override
  String get showTranslation => 'Übersetzung zeigen';

  @override
  String get translateBusy =>
      'Der Assistent ist beschäftigt. Versuch es gleich noch einmal.';

  @override
  String get translateFailed =>
      'Die Schritte konnten nicht übersetzt werden. Bitte versuch es erneut.';

  @override
  String get translateNeedsAi =>
      'Zum Übersetzen braucht es das KI-Modell (siehe Tab „Chat“).';

  @override
  String get tabPlan => 'Plan';

  @override
  String get trendWeight => 'Trendgewicht';

  @override
  String weightChangeIn(String change, int days) {
    return '$change in $days Tagen';
  }

  @override
  String rangeMonths(int n) {
    return '$n M';
  }

  @override
  String get rangeYear => '1 J';

  @override
  String get legendScale => 'Waage';

  @override
  String get legendTrend => 'Trend';

  @override
  String perWeek(String unit) {
    return '$unit pro Woche';
  }

  @override
  String get latestScale => 'Zuletzt gewogen';

  @override
  String get weightTrendNote =>
      'Der Trend glättet tägliche Wasserschwankungen, damit ein schwerer Morgen nicht als echte Veränderung gilt.';

  @override
  String weightChartLabel(int n, String from, String to) {
    return 'Gewicht, $n Messungen, Trend von $from auf $to';
  }

  @override
  String get addShort => '+ Hinzufügen';

  @override
  String get calories => 'Kalorien';

  @override
  String get cook => 'Kochen';

  @override
  String get eatenWord => 'Gegessen';

  @override
  String get leftWord => 'Übrig';

  @override
  String get kcalLeftShort => 'kcal übrig';

  @override
  String get kcalOverShort => 'kcal zu viel';

  @override
  String get fastNotRunning => 'Kein Fasten';

  @override
  String get fromYourPlan => 'aus deinem Plan';

  @override
  String get glassAdded => 'Glas Wasser hinzugefügt';

  @override
  String get undo => 'Rückgängig';

  @override
  String get water => 'Wasser';

  @override
  String get litreUnit => 'l';

  @override
  String get yourWeek => 'Deine Woche';

  @override
  String get yourMonth => 'Dein Monat';

  @override
  String get yourYear => 'Dein Jahr';

  @override
  String addToMeal(String meal) {
    return 'Zu $meal hinzufügen';
  }

  @override
  String fastGoalHours(int hours) {
    return 'Ziel $hours h';
  }

  @override
  String fitsLeft(String amount) {
    return 'passt in deine $amount übrig';
  }

  @override
  String hoursMinutes(int h, int m) {
    return '$h h $m min';
  }

  @override
  String minutesShort(int minutes) {
    return '$minutes Min.';
  }

  @override
  String get kindAll => 'Alle';

  @override
  String get lessServing => 'Eine halbe Portion weniger';

  @override
  String get moreServing => 'Eine halbe Portion mehr';

  @override
  String get logFoodTitle => 'Essen eintragen';

  @override
  String get snapPhoto => 'Foto machen';

  @override
  String servingsAmount(String amount) {
    return '$amount × Portion';
  }

  @override
  String yesterdaysMeal(String meal) {
    return 'Gestern: $meal';
  }

  @override
  String get assistantTitle => 'Assistent';

  @override
  String get openRecipe => 'Rezept öffnen';

  @override
  String get runsOnPhone => 'Läuft auf diesem Handy · nichts verlässt es';

  @override
  String gramsProtein(int n) {
    return '$n g Eiweiß';
  }

  @override
  String messagesLeft(int n, int total) {
    return '$n von $total übrig heute';
  }

  @override
  String get addedToPlan => 'Zum Plan hinzugefügt';

  @override
  String get addToPlan => 'Zum Plan hinzufügen';

  @override
  String get addToShoppingShort => '+ Auf die Einkaufsliste';

  @override
  String get aisleProduce => 'Obst und Gemüse';

  @override
  String get aisleMeatFish => 'Fleisch und Fisch';

  @override
  String get aisleDairyEggs => 'Milchprodukte und Eier';

  @override
  String get aisleBakery => 'Backwaren';

  @override
  String get aislePantry => 'Vorrat';

  @override
  String get aisleSpices => 'Gewürze';

  @override
  String get aisleFrozen => 'Tiefkühl';

  @override
  String get aisleDrinks => 'Getränke';

  @override
  String get aisleOther => 'Sonstiges';

  @override
  String get back => 'Zurück';

  @override
  String get boxEmpty =>
      'Noch nichts hier. Speichere ein Rezept mit dem Lesezeichen oder suche oben.';

  @override
  String get boxFootnote =>
      'Rezepte mit deinen Allergenen erscheinen hier nie. Ideen folgen deinen Sternen.';

  @override
  String get close => 'Schließen';

  @override
  String get doneCooking => 'Fertig';

  @override
  String get fewerServings => 'Weniger Portionen';

  @override
  String get moreServings => 'Mehr Portionen';

  @override
  String get findRecipes => 'Rezepte finden';

  @override
  String get forThisStep => 'Für diesen Schritt';

  @override
  String get fridgeHint => 'z. B. Eier, Spinat, Feta';

  @override
  String get logServing => 'Portion eintragen';

  @override
  String get nextStep => 'Nächster Schritt';

  @override
  String get noSteps => 'Dieses Rezept hat keine Schritte.';

  @override
  String get recipesTitle => 'Rezepte';

  @override
  String get removeSaved => 'Aus Gespeicherten entfernen';

  @override
  String get savedLabel => 'Gespeichert';

  @override
  String get searchRecipes => '166.000 Rezepte durchsuchen…';

  @override
  String get servingsLabel => 'Portionen';

  @override
  String get servingsHint => 'Mengen und Nährwerte passen sich an';

  @override
  String get shelfCooked => 'Gekocht';

  @override
  String get shelfLoved => 'Ab 4★';

  @override
  String get shelfQuick => '≤ 30 Min.';

  @override
  String get startCooking => 'Kochen starten';

  @override
  String get thisWeek => 'Diese Woche';

  @override
  String get timerDone => 'Zeit ist um';

  @override
  String get whatCanICook => 'Was kann ich kochen?';

  @override
  String get whatCanICookBody =>
      'Sag oder fotografiere, was im Kühlschrank ist';

  @override
  String allergensLeftOut(String list) {
    return '$list sind ausgeschlossen: sie stehen auf deiner Allergieliste.';
  }

  @override
  String clearTickedN(int n) {
    return 'Abgehakte entfernen ($n)';
  }

  @override
  String cookedTimes(int n) {
    return '$n× gekocht';
  }

  @override
  String cookSubtitle(int servings) {
    return 'Bildschirm bleibt an · $servings Portionen';
  }

  @override
  String forRecipe(String title) {
    return 'Für: $title';
  }

  @override
  String ideasFor(String list) {
    return 'Ideen für: $list';
  }

  @override
  String itemsLeft(int n, int total) {
    return '$n von $total offen';
  }

  @override
  String plannedFor(String day) {
    return 'Geplant für $day';
  }

  @override
  String planOfKcal(int n, int total) {
    return '$n von $total kcal';
  }

  @override
  String roomForSnack(int kcal) {
    return 'Platz für einen Snack mit $kcal kcal.';
  }

  @override
  String shelfSaved(int n) {
    return 'Gespeichert · $n';
  }

  @override
  String shoppingTabCount(int n) {
    return 'Einkauf · $n';
  }

  @override
  String startTimer(String time) {
    return 'Timer $time starten';
  }

  @override
  String stepOf(int step, int steps) {
    return 'Schritt $step von $steps';
  }

  @override
  String timerRunning(String time) {
    return '$time · tippen zum Stoppen';
  }

  @override
  String youRated(int stars) {
    return 'deine Bewertung $stars';
  }

  @override
  String get changePin => 'PIN ändern';

  @override
  String get currentPin => 'Aktuelle PIN';

  @override
  String get pinChanged => 'PIN geändert';

  @override
  String get dailyTargets => 'Tagesziele';

  @override
  String get tapToOverride => 'Tippen zum Ändern';

  @override
  String get googleAccount => 'Google-Konto';

  @override
  String get googleNotLinked => 'Nicht verknüpft: nur PIN und Fingerabdruck';

  @override
  String googleLinked(String email) {
    return '$email · nur der Name';
  }

  @override
  String get historyAndYear => 'Verlauf und Jahresansicht';

  @override
  String get limitShort => 'max.';

  @override
  String get link => 'Verknüpfen';

  @override
  String get unlink => 'Trennen';

  @override
  String get lookAndLanguage => 'Aussehen und Sprache';

  @override
  String get onDeviceAiAndData => 'KI auf dem Gerät und Daten';

  @override
  String get savedRecipesTitle => 'Gespeicherte Rezepte';

  @override
  String bornIn(int year) {
    return 'geboren $year';
  }

  @override
  String planChip(String tier) {
    return '$tier-Tarif · Tarife';
  }

  @override
  String get addAllergyTitle => 'Allergie oder Ernährungsweise hinzufügen';

  @override
  String get addAllergyHint => 'z. B. Erdnüsse, Gluten, vegetarisch';

  @override
  String allergyUnknown(String text) {
    return '„$text“ ist kein Allergen und keine Ernährungsweise, die die App filtern kann. Versuche Erdnüsse, Nüsse, Milch, Ei, Gluten, Schalentiere, Fisch, Soja, Sesam, vegetarisch, vegan oder pescetarisch.';
  }

  @override
  String get continueButton => 'Weiter';

  @override
  String get dataLocked => 'Deine Daten sind auf diesem Handy gesperrt.';

  @override
  String get firstRunNext =>
      'Als Nächstes: PIN oder Fingerabdruck, dann deine Ziele.';

  @override
  String get googleOnlyName => 'Google trägt nur deinen Namen ein.';

  @override
  String get lockItTitle => 'Nur für dich';

  @override
  String get nameExample => 'z. B. Sam';

  @override
  String get recordsNotInterprets =>
      'Die App speichert, was du einträgst, und deutet es nie. Allgemeine Informationen aus veröffentlichten Leitlinien, keine medizinische Beratung.';

  @override
  String get recordTitle => 'Eintragen';

  @override
  String get reportHintShort => 'PDF und CSV deiner Einträge';

  @override
  String get startTrial => '7 Tage gratis testen';

  @override
  String get touchSensor => 'Sensor berühren zum Entsperren';

  @override
  String get trialBadge => '7 TAGE GRATIS';

  @override
  String get usePin => 'PIN verwenden';

  @override
  String get welcomeHeadline => 'Gut essen, privat';

  @override
  String get welcomeIntro =>
      'Ein KI-Ernährungsassistent, der auf diesem Handy läuft. Keine Cloud-KI, keine Analyse.';

  @override
  String get welcomePointPrivate =>
      'Deine Mahlzeiten und Chats verlassen das Handy nie';

  @override
  String get welcomePointData =>
      '55.000 Lebensmittel und 166.000 Rezepte eingebaut';

  @override
  String get welcomePointAllergens =>
      'Allergene aus jedem Rezept herausgefiltert';

  @override
  String get yourName => 'Dein Name';

  @override
  String currentTier(String tier) {
    return 'Aktuell: $tier';
  }

  @override
  String severityN(int n) {
    return 'Stärke $n';
  }

  @override
  String welcomeBack(String name) {
    return 'Willkommen zurück, $name';
  }

  @override
  String get bestStreak => 'beste Serie';

  @override
  String get daysLogged => 'Tage eingetragen';

  @override
  String avgValue(String value) {
    return 'Ø $value';
  }

  @override
  String dayLine(String amount, int n) {
    return '$amount kcal · $n Einträge';
  }

  @override
  String sinceMonth(String month) {
    return 'seit $month';
  }

  @override
  String streakShort(int n) {
    return '$n-Tage-Serie';
  }

  @override
  String get estimatedTotal => 'Geschätzt gesamt';

  @override
  String logThisMeal(String meal) {
    return '$meal eintragen';
  }

  @override
  String activeKcalBurned(String kcal) {
    return '$kcal kcal verbrannt';
  }

  @override
  String get weightUpdatedToday => 'Heutiges Gewicht aktualisiert.';

  @override
  String get historyMeals => 'Mahlzeiten';

  @override
  String get historyRecipes => 'Gekochte Rezepte';

  @override
  String get historyRecipesEmpty =>
      'An diesen Tagen keine Rezepte. Wenn du ein Rezept einträgst („Das habe ich gegessen“), erscheint es hier.';

  @override
  String lastCooked(String date) {
    return 'zuletzt $date';
  }

  @override
  String get removeItem => 'Entfernen';

  @override
  String seenAs(String name) {
    return 'erkannt: $name';
  }

  @override
  String get confirmUndone => 'Rückgängig gemacht';

  @override
  String get editOnToday => 'Unter Heute bearbeiten';

  @override
  String get thinking => 'Denkt nach…';

  @override
  String get searchInsteadInLog => 'Stattdessen unter Eintragen suchen';

  @override
  String get burntWord => 'Verbrannt';

  @override
  String get aiCardTitle => 'Den KI-Assistenten holen';

  @override
  String get aiCardBody =>
      'Beschreib Mahlzeiten in deinen Worten und frag nach Essen. Er läuft auf diesem Handy: ein Download (einige GB, WLAN empfohlen). Suche und Schnell hinzufügen gehen auch ohne ihn.';

  @override
  String get welcomeLog =>
      'Such es unter Eintragen oder füg die Kalorien schnell hinzu.';

  @override
  String get welcomeChat =>
      'Oder schreib oder sag es im Chat („Ich hatte 2 Eier und Toast“).';

  @override
  String get welcomePhoto => 'Oder fotografier deinen Teller.';

  @override
  String get welcomeEnd => 'Dein Tag füllt sich hier.';

  @override
  String microsLowest(String name, String amount) {
    return 'Am niedrigsten: $name · $amount';
  }

  @override
  String get healthSheetReads =>
      'Liest dein Gewicht, deine Schritte und aktiven Kalorien. Dort wird nichts geschrieben, und nichts verlässt dein Handy.';

  @override
  String lastSynced(String time) {
    return 'Zuletzt synchronisiert um $time';
  }

  @override
  String get syncNow => 'Jetzt synchronisieren';

  @override
  String get disconnect => 'Trennen';

  @override
  String healthSyncedWeights(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count neue Gewichte',
      one: '1 neues Gewicht',
      zero: 'Gewichte sind aktuell',
    );
    return '$_temp0';
  }

  @override
  String get cameraPermissionOff =>
      'Der Kamerazugriff ist aus. Erlaube ihn in den App-Einstellungen, um deine Mahlzeit zu fotografieren.';

  @override
  String get openSettings => 'Einstellungen öffnen';

  @override
  String get tryAgain => 'Erneut versuchen';

  @override
  String get cameraChoosePhoto => 'Foto auswählen';

  @override
  String get cameraGalleryNeedsAi =>
      'Ein Foto aus der Galerie braucht den KI-Assistenten. Lade ihn im Chat herunter.';

  @override
  String get mealsTitle => 'Mahlzeiten';

  @override
  String mealsLogged(int n) {
    return '$n von 4 eingetragen';
  }

  @override
  String suggestedAmount(String amount) {
    return 'Empfohlen ~$amount';
  }

  @override
  String get rateWhatYouAte => 'Bewerte, was du gegessen hast';

  @override
  String get rateButton => 'Bewerten';

  @override
  String get leftToday => 'Heute übrig';

  @override
  String get drawerTrack => 'Tracking';

  @override
  String get meOverline => 'Profil & Ziele';

  @override
  String goalIs(String goal) {
    return 'Ziel: $goal';
  }

  @override
  String get energy => 'Energie';

  @override
  String get bornLabel => 'Geboren';

  @override
  String get planHeroTitle => 'Deine ganze Woche, mit einem Tipp geplant';

  @override
  String get planHeroBody =>
      'Frühstück, Mittag- und Abendessen aus 166.000 Rezepten.';

  @override
  String planSized(String amount) {
    return 'Passend zu deinem Ziel von $amount';
  }

  @override
  String get planNoAllergens => 'Ohne deine Allergene';

  @override
  String get planStarsFirst => 'Deine 4★+-Rezepte zuerst';

  @override
  String get fillsAfterPlanning => 'Füllt sich nach dem Planen';

  @override
  String get allergenFreeForYou => 'Allergenfrei für dich';

  @override
  String ideasForMeal(String meal) {
    return 'Ideen fürs $meal';
  }

  @override
  String amountLeftApprox(String amount) {
    return '~$amount übrig';
  }

  @override
  String get microsLocked =>
      'Vitamine und Mineralstoffe des Tages im Vergleich zu den EU-Referenzwerten – mit Basic.';

  @override
  String get highProtein => 'Proteinreich';

  @override
  String get avatarTitle => 'Dein Bild';

  @override
  String get avatarHint =>
      'Erscheint im Chat und auf dem Entsperrbildschirm. Du kannst es in den Einstellungen ändern oder ein Foto nehmen.';

  @override
  String get avatarWoman => 'Frau';

  @override
  String get avatarMan => 'Mann';

  @override
  String get avatarNeutral => 'Neutral';

  @override
  String get avatarPhoto => 'Foto wählen';

  @override
  String get avatarRemovePhoto => 'Foto entfernen';

  @override
  String get avatarColor => 'Hintergrundfarbe';

  @override
  String get voiceTitle => 'Stimme';

  @override
  String get voiceRepliesHint =>
      'Wenn du mit dem Assistenten sprichst, antwortet er auch laut. Er nutzt die auf deinem Handy installierten Stimmen; nichts verlässt dein Handy.';

  @override
  String get voiceRepliesSwitch => 'Antworten vorlesen';

  @override
  String get voiceWoman => 'Frauenstimme';

  @override
  String get voiceMan => 'Männerstimme';

  @override
  String get voiceTest => 'Probe anhören';

  @override
  String get voiceSample =>
      'Hallo! Sag mir, was du gegessen hast, und ich trage es für dich ein.';

  @override
  String get listening => 'Ich höre zu… tippe aufs Mikrofon zum Beenden';

  @override
  String get transcribing => 'Schreibe auf, was du gesagt hast…';

  @override
  String get voiceNothingHeard =>
      'Nichts gehört. Versuch es noch einmal, etwas näher am Handy.';

  @override
  String get micDenied =>
      'Das Mikrofon ist für diese App ausgeschaltet. Schalte es in den Android-Einstellungen ein, um mit dem Assistenten zu sprechen.';

  @override
  String get reviewCheck => 'Prüfen: Die KI ist unsicher';

  @override
  String get reviewAddFat => 'Mit Öl oder Butter zubereitet?';

  @override
  String get reviewAddFatHint =>
      'Gebratenes oder Geröstetes meist schon, und ein Foto zeigt es nicht. Fügt einen Esslöffel Öl hinzu, den du ändern kannst.';

  @override
  String get aiModelRecommended => 'Empfohlen';
}
