// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'My Nutrition AI';

  @override
  String get addProfile => 'Créer un profil';

  @override
  String get googleWrongAccount =>
      'Ce n’est pas le compte Google avec lequel ce profil a été créé.';

  @override
  String get signInWithGoogle => 'Se connecter avec Google';

  @override
  String get continueWithGoogle => 'Continuer avec Google';

  @override
  String get profileName => 'Prénom';

  @override
  String get nameRequired => 'Saisissez un prénom';

  @override
  String get pinLabel => 'Code PIN (4 à 6 chiffres)';

  @override
  String get pinConfirmLabel => 'Répétez le code PIN';

  @override
  String get pinInvalid => 'Utilisez 4 à 6 chiffres';

  @override
  String get pinMismatch => 'Les codes PIN ne correspondent pas';

  @override
  String get pinHint =>
      'Votre code PIN déverrouille l’app quand l’empreinte ne fonctionne pas. Si vous l’oubliez, le profil pourra seulement être supprimé.';

  @override
  String get create => 'Créer';

  @override
  String get unlock => 'Déverrouiller';

  @override
  String enterPinFor(String name) {
    return 'Code PIN de $name';
  }

  @override
  String pinWrong(int left) {
    String _temp0 = intl.Intl.pluralLogic(
      left,
      locale: localeName,
      other: 'Code PIN incorrect. Encore $left essais avant une pause.',
      one: 'Code PIN incorrect. Encore 1 essai avant une pause.',
    );
    return '$_temp0';
  }

  @override
  String pinLocked(int seconds) {
    return 'Trop d’essais. Réessayez dans $seconds s.';
  }

  @override
  String get forgotPin => 'Code PIN oublié ?';

  @override
  String deleteProfileTitle(String name) {
    return 'Supprimer $name ?';
  }

  @override
  String get deleteProfileBody =>
      'Un code PIN oublié ne peut pas être récupéré. La suppression retire ce profil ainsi que tous ses repas, son journal et l’historique du chat de ce téléphone. C’est définitif.';

  @override
  String get delete => 'Supprimer';

  @override
  String get cancel => 'Annuler';

  @override
  String get lock => 'Verrouiller';

  @override
  String hello(String name) {
    return 'Bonjour, $name';
  }

  @override
  String get deviceUnsupportedTitle => 'Ce téléphone n’est pas pris en charge';

  @override
  String deviceUnsupportedBody(String gb) {
    return 'My Nutrition AI fait tourner son IA entièrement sur votre téléphone et nécessite au moins 6 Go de RAM. Ce téléphone en a environ $gb Go.';
  }

  @override
  String get chatHint => 'Posez une question, notez un repas…';

  @override
  String get chatEmpty =>
      'Bonjour, je suis Eva ! Dites-moi ce que vous avez mangé, posez-moi vos questions sur les aliments et les recettes, ou envoyez une photo de votre repas.';

  @override
  String get send => 'Envoyer';

  @override
  String get preparingAi =>
      'Préparation de l’IA sur l’appareil… Le premier démarrage prend environ une minute.';

  @override
  String get confirmSave => 'Enregistrer';

  @override
  String get confirmDiscard => 'Ignorer';

  @override
  String get confirmSaved => 'Enregistré';

  @override
  String get confirmDiscarded => 'Ignoré';

  @override
  String get perServing => 'Par portion';

  @override
  String minutesServings(int minutes, int servings) {
    return '$minutes min · $servings portions';
  }

  @override
  String get notMedicalAdvice =>
      'Information générale tirée de recommandations publiées, pas un avis médical. Elle ne remplace pas votre médecin ou diététicien : parlez-leur avant de changer votre alimentation ou vos médicaments.';

  @override
  String get chatDisclaimer =>
      'Les réponses de l’IA peuvent être fausses et ne remplacent pas un médecin. En cas d’urgence, appelez le numéro d’urgence local.';

  @override
  String get medicalDisclaimerTitle => 'Avertissement médical';

  @override
  String get medicalDisclaimerBody =>
      'My Nutrition AI et son assistant IA donnent des informations générales sur l’alimentation et la nutrition. L’appli n’est pas un dispositif médical et ne diagnostique, ne traite, ne guérit ni ne prévient aucune maladie.\n\nRien dans l’appli, y compris les réponses de l’assistant, les limites liées aux maladies et les informations de santé, ne remplace l’avis d’un médecin, d’un diététicien ou d’un autre professionnel de santé qualifié. L’IA fonctionne sur votre téléphone et peut se tromper.\n\nParlez toujours à votre médecin avant de changer votre alimentation, vos médicaments ou votre traitement, surtout si vous avez une maladie, êtes enceinte ou allaitez, ou avez ou avez eu un trouble du comportement alimentaire. N’ignorez jamais un avis professionnel et ne tardez jamais à le demander à cause de cette appli.\n\nSi vous pensez qu’il s’agit d’une urgence médicale, appelez immédiatement le numéro d’urgence local.';

  @override
  String get crisisTitle => 'Vous n’avez pas à traverser cela seul·e';

  @override
  String get crisisBody =>
      'Si vous risquez de vous faire du mal, appelez maintenant votre numéro d’urgence local. Des lignes d’écoute gratuites et confidentielles de votre pays sont listées sur findahelpline.com.';

  @override
  String get crisisButton => 'Trouver une ligne d’écoute';

  @override
  String limitReached(int count) {
    return 'Vous avez utilisé les $count messages IA gratuits d’aujourd’hui. Ils se renouvellent à minuit, ou passez au chat illimité avec Basic.';
  }

  @override
  String get agentError => 'Un problème est survenu. Veuillez réessayer.';

  @override
  String get reportResponse => 'Signaler cette réponse';

  @override
  String get kcal => 'kcal';

  @override
  String get protein => 'Protéines';

  @override
  String get fat => 'Lipides';

  @override
  String get carbs => 'Glucides';

  @override
  String get fiber => 'Fibres';

  @override
  String get sugar => 'Sucres';

  @override
  String get sodium => 'Sodium';

  @override
  String get recipeIdeas => 'Idées de recettes';

  @override
  String get ingredients => 'Ingrédients';

  @override
  String get steps => 'Étapes';

  @override
  String get healthInfo => 'Information santé';

  @override
  String servingsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count portions',
      one: '1 portion',
    );
    return '$_temp0';
  }

  @override
  String get iAteThis => 'J’ai mangé ça';

  @override
  String get aiKnowsTitle => 'Ce que l’IA sait de vous';

  @override
  String get aiKnowsIntro =>
      'Voici tout ce qui est dit à l’assistant à votre sujet. Cela reste sur ce téléphone.';

  @override
  String get factsSection => 'Ce que vous lui avez dit';

  @override
  String get factsEmpty =>
      'Rien pour l’instant. Dites au chat par exemple « J’ai une friteuse à air ».';

  @override
  String get allergiesSection => 'Allergies et régime';

  @override
  String get allergiesEmpty => 'Aucune enregistrée.';

  @override
  String get habitsSection => 'Habitudes remarquées (30 derniers jours)';

  @override
  String get habitsEmpty => 'Pas encore assez de repas notés.';

  @override
  String get conversationsSection => 'Conversations';

  @override
  String conversationsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messages enregistrés.',
      one: '1 message enregistré.',
      zero: 'Aucun message enregistré.',
    );
    return '$_temp0';
  }

  @override
  String get forgetConversations => 'Oublier les conversations passées';

  @override
  String get forgetConversationsBody =>
      'Supprime votre historique de chat et la mémoire que l’IA en a. Les repas notés, les informations et les allergies restent.';

  @override
  String get forget => 'Oublier';

  @override
  String get edit => 'Modifier';

  @override
  String get tabToday => 'Aujourd’hui';

  @override
  String get tabChat => 'Chat';

  @override
  String get tabLog => 'Noter';

  @override
  String get tabMe => 'Moi';

  @override
  String eatenOfGoal(int goal) {
    return 'sur $goal kcal';
  }

  @override
  String kcalLeft(int left) {
    return 'Encore $left kcal';
  }

  @override
  String kcalOver(int over) {
    return '$over kcal de trop';
  }

  @override
  String overBy(String amount) {
    return '$amount de trop';
  }

  @override
  String get eatenToday => 'Mangé aujourd’hui';

  @override
  String get setGoalsTitle => 'Fixez vos objectifs du jour';

  @override
  String get setGoalsBody =>
      'Parlez-nous un peu de vous pour obtenir des objectifs de calories et de nutriments.';

  @override
  String get setGoalsButton => 'Fixer les objectifs';

  @override
  String get todaysMeals => 'Repas du jour';

  @override
  String get noMealsYet =>
      'Rien de noté pour l’instant. Utilisez l’onglet Noter ou dites au chat ce que vous avez mangé.';

  @override
  String get deleteMealTitle => 'Supprimer cette entrée ?';

  @override
  String get mealBreakfast => 'Petit-déjeuner';

  @override
  String get mealLunch => 'Déjeuner';

  @override
  String get mealDinner => 'Dîner';

  @override
  String get mealSnack => 'Collation';

  @override
  String get searchFood => 'Chercher aliments, plats, recettes…';

  @override
  String get kindFood => 'Aliment';

  @override
  String get kindDish => 'Plat';

  @override
  String get kindRecipe => 'Recette';

  @override
  String perServing2(int kcal) {
    return '$kcal kcal par portion';
  }

  @override
  String per100g(int kcal) {
    return '$kcal kcal pour 100 g';
  }

  @override
  String get servings => 'Portions';

  @override
  String get grams => 'Grammes';

  @override
  String get logButton => 'Noter';

  @override
  String loggedSnack(String label) {
    return '$label noté';
  }

  @override
  String get noResults => 'Aucun résultat dans la base d’aliments.';

  @override
  String get goalsTitle => 'Vos objectifs du jour';

  @override
  String get goalsIntro =>
      'Sert à calculer vos objectifs de calories et de nutriments. Reste sur ce téléphone.';

  @override
  String get later => 'Plus tard';

  @override
  String get units => 'Unités';

  @override
  String get metric => 'Métriques';

  @override
  String get imperial => 'Impériales';

  @override
  String get sex => 'Sexe utilisé pour la formule';

  @override
  String get female => 'Femme';

  @override
  String get male => 'Homme';

  @override
  String get other => 'Autre';

  @override
  String get birthYear => 'Année de naissance';

  @override
  String get heightCm => 'Taille (cm)';

  @override
  String get heightFt => 'ft';

  @override
  String get heightIn => 'in';

  @override
  String get weightKg => 'Poids (kg)';

  @override
  String get weightLb => 'Poids (lb)';

  @override
  String get activity => 'Activité';

  @override
  String get activitySedentary => 'Sédentaire : surtout assis·e';

  @override
  String get activityLight => 'Légère : sport 1 à 3 jours par semaine';

  @override
  String get activityModerate => 'Modérée : sport 3 à 5 jours par semaine';

  @override
  String get activityActive => 'Active : sport 6 à 7 jours par semaine';

  @override
  String get activityVeryActive =>
      'Très active : entraînement intense quotidien ou travail physique';

  @override
  String get goal => 'Objectif';

  @override
  String get goalLose => 'Perdre du poids';

  @override
  String get goalMaintain => 'Maintenir';

  @override
  String get goalGain => 'Prendre du poids';

  @override
  String get birthMonth => 'Mois de naissance';

  @override
  String get chooseMonth => 'Choisissez un mois';

  @override
  String get underweightNoLose =>
      'Votre IMC est inférieur à 18,5 : perdre du poids n’est pas sûr, vos objectifs restent au maintien du poids. Parlez-en à un médecin si vous voulez le changer.';

  @override
  String get invalidNumber => 'Saisissez un nombre valide';

  @override
  String get under18 =>
      'Ces formules ne s’appliquent pas avant 18 ans. Fixez les objectifs ci-dessous avec votre pédiatre.';

  @override
  String get aboutMe => 'À propos de moi';

  @override
  String get sexShort => 'Sexe';

  @override
  String get height => 'Taille';

  @override
  String get weight => 'Poids';

  @override
  String get targetsNone => 'Pas encore d’objectifs.';

  @override
  String get custom => 'personnalisé';

  @override
  String editTarget(String name) {
    return 'Objectif : $name';
  }

  @override
  String get resetTarget => 'Utiliser le calcul';

  @override
  String get editDetails => 'Modifier mes informations';

  @override
  String get switchProfile => 'Verrouiller et changer de profil';

  @override
  String get limitSuffix => 'max.';

  @override
  String get remindersTitle => 'Rappels';

  @override
  String get remindersHint =>
      'Les heures suivent vos horaires de repas habituels une fois quelques repas notés.';

  @override
  String get reminderBreakfast => 'Noter le petit-déjeuner';

  @override
  String get reminderLunch => 'Noter le déjeuner';

  @override
  String get reminderDinner => 'Noter le dîner';

  @override
  String get reminderEvening => 'Bilan du soir';

  @override
  String notifMeal(String name, String meal) {
    return '$name, c’est le moment de noter votre $meal ?';
  }

  @override
  String notifEvening(String name) {
    return '$name, comment s’est passée la journée ? Votre bilan est prêt.';
  }

  @override
  String get notificationsDenied =>
      'Les notifications de My Nutrition AI sont désactivées dans les paramètres Android.';

  @override
  String get voiceInput => 'Parler';

  @override
  String get voiceStop => 'Arrêter l’écoute';

  @override
  String get voiceUnavailable =>
      'La saisie vocale nécessite la reconnaissance vocale hors ligne sur ce téléphone (appli Google → Paramètres → Voix → Reconnaissance vocale hors connexion → français). My Nutrition AI n’envoie jamais votre voix en ligne.';

  @override
  String youSaid(String text) {
    return 'Vous avez dit : $text';
  }

  @override
  String aiSaid(String text) {
    return 'My Nutrition AI a dit : $text';
  }

  @override
  String get useFingerprint => 'Utiliser l’empreinte';

  @override
  String get fingerprintTitle => 'Déverrouiller avec l’empreinte';

  @override
  String get fingerprintHint =>
      'Déverrouiller avec l’empreinte au lieu du code PIN.';

  @override
  String fingerprintReason(String name) {
    return 'Déverrouiller le profil de $name';
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
  String get plansTitle => 'Formules';

  @override
  String get monthly => 'Mensuel';

  @override
  String get yearly => 'Annuel';

  @override
  String perMonth(String price) {
    return '$price / mois';
  }

  @override
  String perYear(String price) {
    return '$price / an';
  }

  @override
  String trialThen(String price) {
    return '7 jours gratuits, puis $price';
  }

  @override
  String get subscribe => 'S’abonner';

  @override
  String get upgrade => 'Passer à la formule supérieure';

  @override
  String get switchPlan => 'Changer';

  @override
  String get currentPlan => 'Formule actuelle';

  @override
  String get restorePurchases => 'Restaurer les achats';

  @override
  String get subscriptionTerms =>
      'Les abonnements se renouvellent automatiquement jusqu’à leur résiliation. Résiliez à tout moment dans Google Play → Paiements et abonnements. Un abonnement couvre tous les profils de ce téléphone.';

  @override
  String get devBillingBanner =>
      'Mode développeur : aucun vrai paiement. Choisissez une formule pour l’essayer.';

  @override
  String get devBackToFree => 'Revenir à Free (développeur)';

  @override
  String get purchaseFailed => 'L’achat n’a pas abouti. Veuillez réessayer.';

  @override
  String get featBasic1 => 'Chat IA illimité';

  @override
  String get featBasic3 => 'Rappels pour boire, séries, micronutriments';

  @override
  String get featMedium1 => 'Tout Basic';

  @override
  String get featMedium2 => 'Maladies : limites et suggestions alimentaires';

  @override
  String get featMedium3 =>
      'Journal des symptômes et mesures, export pour le médecin';

  @override
  String get featPro1 => 'Tout Medium';

  @override
  String get featPro2 =>
      'Reconnaissance des aliments par photo et caméra en direct';

  @override
  String get featPro3 =>
      'Note les repas et trouve des recettes à partir de ce qu’elle voit';

  @override
  String get yourPlan => 'Votre formule';

  @override
  String get seePlans => 'Voir les formules';

  @override
  String get periodDay => 'Jour';

  @override
  String get periodWeek => 'Semaine';

  @override
  String get periodMonth => 'Mois';

  @override
  String get lockedTitle => 'Plus avec Basic';

  @override
  String get lockedBody =>
      'Votre série de jours notés, un plan de repas de la semaine avec liste de courses, des rappels pour boire et 3 mois d’historique.';

  @override
  String get caloriesPerDay => 'Calories par jour';

  @override
  String goalLine(int kcal) {
    return 'Objectif $kcal';
  }

  @override
  String dailyAverage(int days) {
    return 'Moyenne par jour ($days jours notés)';
  }

  @override
  String streakDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Série de $days jours',
      one: 'Série de 1 jour',
      zero: 'Pas encore de série',
    );
    return '$_temp0';
  }

  @override
  String get weightTrend => 'Poids';

  @override
  String get weightTrendEmpty =>
      'Notez votre poids sur deux jours différents pour voir la tendance.';

  @override
  String get logWeight => 'Noter le poids';

  @override
  String get weightLogged => 'Poids enregistré';

  @override
  String get plansUnavailable =>
      'Les formules ne sont pas disponibles dans cette version.';

  @override
  String cautionAllergy(String food, String allergen) {
    return 'Contient $food, exclu par vos allergies ou votre régime ($allergen)';
  }

  @override
  String cautionCondition(String food, String condition) {
    return 'Contient $food, à éviter avec : $condition';
  }

  @override
  String get condDiabetesT2 => 'Diabète de type 2';

  @override
  String get condHypertension => 'Hypertension';

  @override
  String get condGout => 'Goutte';

  @override
  String get condAls => 'SLA';

  @override
  String get condMs => 'Sclérose en plaques';

  @override
  String get healthTitle => 'Santé';

  @override
  String get healthMeHint =>
      'Maladies, journal, chronologie, rapport pour votre médecin';

  @override
  String get conditionsTitle => 'Maladies';

  @override
  String get conditionsHint =>
      'Les suggestions de recettes évitent les aliments à éviter, et les limites abaissent vos objectifs du jour. Ce sont des suggestions générales, pas un avis médical : parlez-en à votre médecin avant de changer votre alimentation.';

  @override
  String limitLine(String nutrient, String amount, String condition) {
    return '$nutrient : au plus $amount par jour ($condition)';
  }

  @override
  String avoidLine(String foods) {
    return 'Aliments à éviter : $foods';
  }

  @override
  String limitFrom(String condition) {
    return 'limite liée à : $condition';
  }

  @override
  String get timelineTitle => 'Chronologie';

  @override
  String get timelineHint => 'Nutriments, mesures et symptômes par date';

  @override
  String get timelineEmpty => 'Rien d’enregistré sur cette période.';

  @override
  String get reportButton => 'Rapport pour votre médecin';

  @override
  String get reportHint => 'PDF et CSV de ce que vous avez noté';

  @override
  String get journalTitle => 'Journal';

  @override
  String get journalHint => '14 derniers jours';

  @override
  String get journalEmpty => 'Rien d’enregistré ces 14 derniers jours.';

  @override
  String get symptom => 'Symptôme';

  @override
  String get symptomHint => 'Que ressentez-vous ? ex. fatigue';

  @override
  String get severity => 'Intensité (facultatif)';

  @override
  String get severityHint => '1 = légère, 5 = forte';

  @override
  String get glucose => 'Glycémie';

  @override
  String get bloodPressure => 'Tension artérielle';

  @override
  String get systolic => 'Systolique (haute)';

  @override
  String get diastolic => 'Diastolique (basse)';

  @override
  String get deleteEntryTitle => 'Supprimer cette entrée ?';

  @override
  String get healthLockedTitle => 'Le suivi santé fait partie de Medium';

  @override
  String get healthLockedBody =>
      'Medium ajoute les maladies (filtre des recettes et limites du jour), un journal des symptômes et mesures, des graphiques et un rapport à partager avec votre médecin.';

  @override
  String conditionsStillApply(String conditions) {
    return 'Vos maladies continuent de filtrer les recettes et de limiter vos objectifs : $conditions';
  }

  @override
  String days(int count) {
    return '$count jours';
  }

  @override
  String get perDay => 'par jour';

  @override
  String get symptomsTitle => 'Symptômes';

  @override
  String get readingsTitle => 'Mesures';

  @override
  String get reportSheetHint =>
      'Un PDF à lire et un CSV pour tableur, avec tout ce que vous avez noté. Vous choisissez où les envoyer ; l’appli ne partage rien d’elle-même.';

  @override
  String get reportShare => 'Créer et partager';

  @override
  String get reportSubject => 'Rapport My Nutrition AI';

  @override
  String get reportFailed => 'Impossible de créer le rapport.';

  @override
  String reportTitle(String name) {
    return 'Rapport My Nutrition AI : $name';
  }

  @override
  String reportCreated(String date) {
    return 'créé le $date';
  }

  @override
  String get reportDisclaimer =>
      'Saisi par l’utilisateur dans l’appli My Nutrition AI. Les valeurs sont affichées telles que notées ; l’appli ne les interprète pas et ne donne pas d’avis médical. Les limites viennent des maladies choisies par l’utilisateur.';

  @override
  String get reportNone => 'Rien d’enregistré.';

  @override
  String reportDailyNutrition(int days) {
    return 'Nutrition par jour ($days jours notés)';
  }

  @override
  String get reportDate => 'Date';

  @override
  String get reportItems => 'Éléments';

  @override
  String get reportMeasurement => 'Mesure';

  @override
  String get reportValue => 'Valeur';

  @override
  String get cameraTitle => 'Caméra';

  @override
  String get cameraOpen => 'Ouvrir la caméra';

  @override
  String get cameraPhoto => 'Photo';

  @override
  String get cameraLive => 'Direct';

  @override
  String get cameraUnavailable =>
      'La caméra n’est pas disponible. Fermez les autres applis qui l’utilisent et réessayez.';

  @override
  String get cameraShoot => 'Prendre une photo';

  @override
  String get cameraNaming => 'Reconnaissance des aliments…';

  @override
  String get cameraNamingFailed =>
      'La reconnaissance IA a échoué : détection rapide à la place. Vérifiez les aliments.';

  @override
  String cameraUseFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Utiliser $count éléments',
      one: 'Utiliser 1 élément',
      zero: 'Continuer',
    );
    return '$_temp0';
  }

  @override
  String get reviewTitle => 'Vérifiez ce qui a été trouvé';

  @override
  String get reviewHint =>
      'Les quantités issues d’une photo sont des estimations (≈). Modifiez ou retirez ce que vous voulez ; rien n’est enregistré avant d’appuyer sur Noter.';

  @override
  String get reviewEmpty =>
      'Aucun aliment trouvé. Ajoutez des éléments par leur nom.';

  @override
  String notInDatabase(String name) {
    return '$name : absent de la base. Touchez Modifier pour choisir un aliment.';
  }

  @override
  String get reviewChange => 'Modifier';

  @override
  String get reviewAdd => 'Ajouter un élément';

  @override
  String get reviewLog => 'Noter ce repas';

  @override
  String reviewLogged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count éléments notés',
      one: '1 élément noté',
    );
    return '$_temp0';
  }

  @override
  String get reviewCook => 'Que puis-je cuisiner ?';

  @override
  String get yourRating => 'Votre note';

  @override
  String get kindRecent => 'Récent';

  @override
  String get recentFoods => 'Récents et fréquents';

  @override
  String repeatYesterday(String meal, int kcal) {
    return '$meal d’hier · $kcal kcal';
  }

  @override
  String get quickAdd => 'Ajout rapide';

  @override
  String get quickAddName => 'Nom (facultatif)';

  @override
  String get editMeal => 'Modifier l’entrée';

  @override
  String get changeFood => 'Changer d’aliment';

  @override
  String get appearance => 'Apparence';

  @override
  String cardLogMeal(String meal) {
    return 'Noter : $meal';
  }

  @override
  String get cardSaveRecipe => 'Enregistrer la recette';

  @override
  String get cardRateRecipe => 'Noter la recette';

  @override
  String get cardRemember => 'Retenir';

  @override
  String get cardAddAllergy => 'Ajouter une allergie';

  @override
  String get cardRemoveAllergy => 'Retirer une allergie';

  @override
  String get cardAddDiet => 'Ajouter un régime';

  @override
  String get cardRemoveDiet => 'Retirer un régime';

  @override
  String get captionConfirm => 'Vérifiez puis touchez « Enregistrer ».';

  @override
  String get captionIdeas =>
      'Voici quelques idées. Touchez-en une pour voir la recette.';

  @override
  String captionIdeasAvoiding(String foods) {
    return 'Attention : vous êtes allergique à $foods ou l’évitez, je l’ai donc laissé de côté. Voici des recettes sans ; touchez-en une pour la voir.';
  }

  @override
  String get captionRecipe => 'Voici la recette.';

  @override
  String get captionNumbers => 'Voici les valeurs.';

  @override
  String get captionCamera => 'Touchez le bouton pour ouvrir l’appareil photo.';

  @override
  String get photoAttach => 'Photo de votre repas';

  @override
  String get captionPhoto => 'Voici ce que je vois sur votre photo.';

  @override
  String get photoCardHint =>
      'Vérifiez chaque aliment et chaque quantité, corrigez mes erreurs, puis choisissez le repas et enregistrez.';

  @override
  String photoNotMatched(String names) {
    return 'Absent de la liste d’aliments : $names. Ajoutez-les avec « Ajouter un élément ».';
  }

  @override
  String get cardLogSymptom => 'Noter un symptôme';

  @override
  String get cardLogGlucose => 'Noter la glycémie';

  @override
  String get cardLogBloodPressure => 'Noter la tension';

  @override
  String get cardLogWater => 'Noter l’eau';

  @override
  String get last7Days => '7 derniers jours';

  @override
  String get weekReviewTitle => 'Votre semaine';

  @override
  String reviewLoggedDays(int days) {
    return 'Vous avez noté vos repas $days jours sur 7.';
  }

  @override
  String reviewKcal(int avg, int goal) {
    return 'Ces jours-là : $avg kcal en moyenne, objectif $goal.';
  }

  @override
  String reviewUnder(String nutrient, int days) {
    return '$nutrient sous 80 % de votre objectif $days jours.';
  }

  @override
  String reviewOver(String nutrient, int days) {
    return '$nutrient au-dessus de votre limite $days jours.';
  }

  @override
  String reviewWater(int avg, int goal) {
    return 'Eau : $avg ml par jour, objectif $goal ml.';
  }

  @override
  String reviewTop(String food) {
    return 'Le plus noté : $food.';
  }

  @override
  String get reviewIdeas => 'Idées pour la semaine prochaine';

  @override
  String reviewAskHigh(String nutrient) {
    return 'Propose des recettes riches en $nutrient';
  }

  @override
  String reviewAskLow(String nutrient) {
    return 'Propose des recettes pauvres en $nutrient';
  }

  @override
  String get microsTitle => 'Vitamines et minéraux';

  @override
  String get dataTitle => 'Données alimentaires';

  @override
  String dataBody(int mb) {
    return 'My Nutrition AI garde ses tables d’aliments, ses recettes et sa recherche sur votre téléphone : rien de ce que vous mangez n’en sort. Téléchargez-les une fois ($mb Mo) ; vous pouvez quitter l’app pendant ce temps. Wi-Fi conseillé.';
  }

  @override
  String downloadSize(int mb) {
    return 'Télécharger ($mb Mo)';
  }

  @override
  String get healthConnect => 'Health Connect';

  @override
  String get appleHealth => 'Apple Santé';

  @override
  String get healthSyncHint =>
      'Lit votre poids (pour vos objectifs), vos pas et vos calories brûlées (affichés dans Aujourd’hui). Rien n’y est écrit et rien ne quitte votre téléphone. Désactivez pour déconnecter.';

  @override
  String get healthSyncDenied =>
      'Pas d’accès. Autorisez le poids, les pas et les calories actives dans les réglages de l’appli santé, puis réessayez.';

  @override
  String stepsToday(String steps) {
    return '$steps pas aujourd’hui';
  }

  @override
  String get mealPlan => 'Plan de repas';

  @override
  String get planTab => 'Plan';

  @override
  String get planWeek => 'Planifier ma semaine';

  @override
  String get planAgain => 'Replanifier';

  @override
  String get planSwap => 'Autre recette';

  @override
  String get planCardEmpty =>
      'Planifiez votre semaine et obtenez une liste de courses';

  @override
  String get makeShoppingList => 'Liste de courses';

  @override
  String get shoppingList => 'Courses';

  @override
  String get shoppingAdd => 'Ajouter un article';

  @override
  String get shoppingEmpty =>
      'Rien à acheter. Créez une liste depuis votre plan ou ajoutez les ingrédients d’une recette depuis la recette.';

  @override
  String get clearTicked => 'Retirer les cochés';

  @override
  String get addToShopping => 'Ajouter à la liste de courses';

  @override
  String get addedToShopping => 'Ajouté à la liste de courses';

  @override
  String waterLine(int ml, int goal) {
    return 'Eau $ml / $goal ml';
  }

  @override
  String get waterAddGlass => 'Ajouter un verre (250 ml)';

  @override
  String get waterUndo => 'Annuler le dernier verre';

  @override
  String get waterGoal => 'Objectif d’eau par jour';

  @override
  String get fasting => 'Jeûne';

  @override
  String fastingLine(int h, int m, int target) {
    return 'Jeûne $h h $m min sur $target h';
  }

  @override
  String get fastStart => 'Commencer';

  @override
  String fastSinceMeal(String time) {
    return 'Depuis le dernier repas ($time)';
  }

  @override
  String get fastEnd => 'Terminer le jeûne';

  @override
  String get fastDone =>
      'Objectif atteint. Terminez le jeûne quand vous mangez.';

  @override
  String get fastingSwitch => 'Minuteur de jeûne';

  @override
  String get fastingCaution =>
      'Déconseillé pendant la grossesse, en cas de trouble alimentaire ou de diabète traité par insuline ou sulfamides. Demandez d’abord à votre médecin.';

  @override
  String get widgetKcalTitle => 'Calories sur le widget d’accueil';

  @override
  String get widgetKcalHint =>
      'Ajoutez le widget My Nutrition AI à votre écran d’accueil. Les calories du jour y seront alors visibles sans votre code PIN.';

  @override
  String get welcomeTitle => 'Notez votre premier repas';

  @override
  String nextMealTitle(String meal) {
    return 'Pas encore noté : $meal';
  }

  @override
  String get nextMealBody =>
      'Notez ce que vous avez mangé, ou trouvez une idée de repas.';

  @override
  String get getIdea => 'Trouver une idée';

  @override
  String get logIt => 'Noter';

  @override
  String get language => 'Langue';

  @override
  String get themeSystem => 'Système';

  @override
  String get themeLight => 'Clair';

  @override
  String get themeDark => 'Sombre';

  @override
  String get wallpaperColors => 'Couleurs du fond d’écran';

  @override
  String get wallpaperColorsHint =>
      'Utiliser les couleurs de votre téléphone (Android 12 et plus).';

  @override
  String suggestAte(String food) {
    return 'J’ai mangé $food';
  }

  @override
  String suggestIdea(String meal) {
    return 'Quelque chose de nouveau pour le $meal';
  }

  @override
  String get suggestLeft => 'Que me reste-t-il pour aujourd’hui ?';

  @override
  String rateStars(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Donner $count étoiles',
      one: 'Donner 1 étoile',
    );
    return '$_temp0';
  }

  @override
  String get recipesYouAte => 'Recettes que vous avez mangées';

  @override
  String get recipesYouAteHint =>
      'Touchez-en une pour la revoir et la noter. Les idées de recettes suivent vos étoiles.';

  @override
  String get cookNone => 'Aucune recette de la base n’utilise ces aliments.';

  @override
  String get per100Suffix => ' / 100 g';

  @override
  String get aiDownloadTitle => 'Télécharger l’assistant IA';

  @override
  String aiDownloadBody(String gb) {
    return 'L’assistant de chat fonctionne entièrement sur votre téléphone. Son modèle ($gb Go) se télécharge une seule fois depuis Hugging Face ; utilisez le Wi-Fi. Rien ne vous concernant n’est envoyé. Noter, les recettes et votre tableau de bord fonctionnent déjà sans lui.';
  }

  @override
  String get aiDownloadButton => 'Télécharger';

  @override
  String get aiModelTitle => 'Modèle d’IA';

  @override
  String aiModelStandard(String gb) {
    return 'Standard · $gb Go';
  }

  @override
  String get aiModelStandardHint =>
      'Réponses plus rapides. Fonctionne sur tous les téléphones compatibles.';

  @override
  String aiModelLarge(String gb) {
    return 'Plus grand · $gb Go';
  }

  @override
  String get aiModelLargeHint =>
      'Comprend mieux et reconnaît mieux les aliments sur les photos ; répond environ 2 à 3 fois plus lentement. Pour les téléphones avec 12 Go de RAM.';

  @override
  String get aiModelSwitch => 'Changer';

  @override
  String get aiModelSwitchBody =>
      'L’autre modèle se télécharge d’abord ; l’actuel est supprimé une fois terminé.';

  @override
  String get aiModelInUse => 'Utilisé';

  @override
  String get aiDownloading => 'Téléchargement';

  @override
  String get aiDownloadFailed =>
      'Le téléchargement s’est arrêté. Vérifiez la connexion et l’espace libre, puis réessayez ; il reprendra là où il s’est arrêté.';

  @override
  String get downloadNoWifiTitle => 'Pas de Wi-Fi';

  @override
  String downloadNoWifiBody(int mb) {
    return 'Vous n’êtes pas connecté au Wi-Fi. Ce téléchargement fait $mb Mo ; en données mobiles, il peut épuiser votre forfait ou vous coûter de l’argent.';
  }

  @override
  String get downloadWaitWifi => 'Attendre le Wi-Fi';

  @override
  String get downloadUseMobile => 'Utiliser les données mobiles';

  @override
  String get downloadOnMobile =>
      'Données mobiles autorisées : ce téléchargement peut consommer votre forfait.';

  @override
  String get downloadWaitingWifi => 'En attente du Wi-Fi';

  @override
  String get downloadWaitingNetwork => 'En attente d’une connexion';

  @override
  String get downloadRetrying =>
      'Connexion perdue ; il reprendra dès son retour';

  @override
  String get downloadPaused => 'En pause';

  @override
  String get downloadInstalling => 'Installation…';

  @override
  String get downloadPause => 'Pause';

  @override
  String get downloadResume => 'Reprendre';

  @override
  String get privacyPolicy => 'Politique de confidentialité';

  @override
  String get termsOfUse => 'Conditions d’utilisation';

  @override
  String get licenses => 'Licences et modèles d’IA';

  @override
  String get settingsTitle => 'Paramètres';

  @override
  String get drawerFood => 'Alimentation';

  @override
  String get drawerAssistant => 'Assistant';

  @override
  String get shoppingListNav => 'Liste de courses';

  @override
  String get healthJournalNav => 'Journal de santé et rapport';

  @override
  String get settingsAi => 'IA et données';

  @override
  String get settingsTracking => 'Suivi';

  @override
  String get settingsPrivacy => 'Confidentialité et sécurité';

  @override
  String get settingsAbout => 'À propos';

  @override
  String get settingsDanger => 'Zone de danger';

  @override
  String get deleteThisProfile => 'Supprimer ce profil';

  @override
  String get deleteThisProfileBody =>
      'Le profil et tous ses repas, son journal et son historique de chat seront supprimés de ce téléphone. Action irréversible.';

  @override
  String get featBasic2 => 'Plan de repas et liste de courses';

  @override
  String get featBasic4 => '3 mois d’historique';

  @override
  String get featMedium4 => '8 mois d’historique';

  @override
  String get featPro4 => 'Tableau de bord annuel et 12 mois d’historique';

  @override
  String get periodYear => 'Année';

  @override
  String get yearLockedTitle => 'La vue Année est dans Pro';

  @override
  String get yearLockedBody =>
      'Douze mois en un coup d’œil : calories par mois, calendrier des saisies, moyennes nutritionnelles avec vos meilleurs et pires mois, votre poids et ce que vous avez mangé le plus.';

  @override
  String get yearCalories => 'Calories par jour, moyenne mensuelle';

  @override
  String get yearCalendar => 'Calendrier des saisies';

  @override
  String yearLoggedDays(int days, int best) {
    return '$days jours notés · meilleure série $best jours';
  }

  @override
  String get yearNutrients => 'Moyennes quotidiennes de l’année';

  @override
  String yearBestWorst(String nutrient, String best, String worst) {
    return '$nutrient : meilleur mois $best, pire $worst';
  }

  @override
  String get yearTopFoods => 'Mangé le plus souvent';

  @override
  String get calendarOnGoal => 'À 10 % de l’objectif';

  @override
  String get calendarNear => 'À 25 %';

  @override
  String get calendarFar => 'Plus loin';

  @override
  String get calendarNotLogged => 'Non noté';

  @override
  String get historyTitle => 'Historique';

  @override
  String lastDays(int count) {
    return '$count derniers jours';
  }

  @override
  String get pickDates => 'Choisir des dates';

  @override
  String get historyEmpty => 'Rien de noté ces jours-là.';

  @override
  String historyLockedTitle(int days) {
    return 'L’historique montre les $days derniers jours';
  }

  @override
  String get historyLockedBody =>
      'Les repas plus anciens restent sur votre téléphone. Basic montre 3 mois, Medium 8 et Pro 12.';

  @override
  String get planLockedTitle => 'Le plan de repas est dans Basic';

  @override
  String get planLockedBody =>
      'Planifiez votre semaine avec des recettes adaptées à vos objectifs et allergènes, et transformez-la en liste de courses.';

  @override
  String get reminderWater => 'Boire de l’eau';

  @override
  String reminderWaterHint(int count, String from, String to) {
    return '$count par jour, $from–$to : un verre à chaque fois pour atteindre votre objectif d’eau';
  }

  @override
  String get reminderWaterLocked => 'Les rappels pour boire sont dans Basic';

  @override
  String notifWater(String name) {
    return '$name, c’est l’heure d’un verre d’eau.';
  }

  @override
  String get machineTranslated =>
      'Noms des ingrédients traduits automatiquement';

  @override
  String get translateSteps => 'Traduire les étapes';

  @override
  String get machineTranslatedSteps =>
      'Étapes traduites automatiquement sur votre téléphone';

  @override
  String get showOriginal => 'Voir l’original';

  @override
  String get showTranslation => 'Voir la traduction';

  @override
  String get translateBusy =>
      'L’assistant est occupé. Réessayez dans un instant.';

  @override
  String get translateFailed =>
      'Impossible de traduire les étapes. Veuillez réessayer.';

  @override
  String get translateNeedsAi =>
      'La traduction nécessite le modèle d’IA (voir l’onglet Chat).';

  @override
  String get tabPlan => 'Plan';

  @override
  String get trendWeight => 'Poids tendance';

  @override
  String weightChangeIn(String change, int days) {
    return '$change en $days jours';
  }

  @override
  String rangeMonths(int n) {
    return '$n m';
  }

  @override
  String get rangeYear => '1 an';

  @override
  String get legendScale => 'Balance';

  @override
  String get legendTrend => 'Tendance';

  @override
  String perWeek(String unit) {
    return '$unit par semaine';
  }

  @override
  String get latestScale => 'Dernière pesée';

  @override
  String get weightTrendNote =>
      'La tendance lisse les variations d’eau quotidiennes : un matin plus lourd n’est pas pris pour un vrai changement.';

  @override
  String weightChartLabel(int n, String from, String to) {
    return 'Poids, $n pesées, tendance de $from à $to';
  }

  @override
  String get addShort => '+ Ajouter';

  @override
  String get calories => 'Calories';

  @override
  String get cook => 'Cuisiner';

  @override
  String get eatenWord => 'Mangé';

  @override
  String get leftWord => 'Reste';

  @override
  String get kcalLeftShort => 'kcal restantes';

  @override
  String get kcalOverShort => 'kcal en trop';

  @override
  String get fastNotRunning => 'Pas de jeûne';

  @override
  String get fromYourPlan => 'de votre plan';

  @override
  String get glassAdded => 'Verre d’eau ajouté';

  @override
  String get undo => 'Annuler';

  @override
  String get water => 'Eau';

  @override
  String get litreUnit => 'L';

  @override
  String get yourWeek => 'Votre semaine';

  @override
  String get yourMonth => 'Votre mois';

  @override
  String get yourYear => 'Votre année';

  @override
  String addToMeal(String meal) {
    return 'Ajouter : $meal';
  }

  @override
  String fastGoalHours(int hours) {
    return 'objectif $hours h';
  }

  @override
  String fitsLeft(String amount) {
    return 'tient dans vos $amount restantes';
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
  String get kindAll => 'Tout';

  @override
  String get lessServing => 'Une demi-portion de moins';

  @override
  String get moreServing => 'Une demi-portion de plus';

  @override
  String get logFoodTitle => 'Noter un repas';

  @override
  String get snapPhoto => 'Prendre une photo';

  @override
  String servingsAmount(String amount) {
    return '$amount × portion';
  }

  @override
  String yesterdaysMeal(String meal) {
    return 'Hier : $meal';
  }

  @override
  String get assistantTitle => 'Assistant';

  @override
  String get openRecipe => 'Ouvrir la recette';

  @override
  String get runsOnPhone => 'Tourne sur ce téléphone · rien n’en sort';

  @override
  String gramsProtein(int n) {
    return '$n g de protéines';
  }

  @override
  String messagesLeft(int n, int total) {
    return '$n sur $total restants aujourd’hui';
  }

  @override
  String get addedToPlan => 'Ajouté à votre plan';

  @override
  String get addToPlan => 'Ajouter au plan';

  @override
  String get addToShoppingShort => '+ Aux courses';

  @override
  String get aisleProduce => 'Fruits et légumes';

  @override
  String get aisleMeatFish => 'Viande et poisson';

  @override
  String get aisleDairyEggs => 'Produits laitiers et œufs';

  @override
  String get aisleBakery => 'Boulangerie';

  @override
  String get aislePantry => 'Épicerie';

  @override
  String get aisleSpices => 'Épices';

  @override
  String get aisleFrozen => 'Surgelés';

  @override
  String get aisleDrinks => 'Boissons';

  @override
  String get aisleOther => 'Autres';

  @override
  String get back => 'Retour';

  @override
  String get boxEmpty =>
      'Rien ici pour l’instant. Enregistrez une recette avec son signet, ou cherchez ci-dessus.';

  @override
  String get boxFootnote =>
      'Les recettes avec vos allergènes n’apparaissent jamais ici. Les idées suivent vos étoiles.';

  @override
  String get close => 'Fermer';

  @override
  String get doneCooking => 'Terminé';

  @override
  String get fewerServings => 'Moins de portions';

  @override
  String get moreServings => 'Plus de portions';

  @override
  String get findRecipes => 'Trouver des recettes';

  @override
  String get forThisStep => 'Pour cette étape';

  @override
  String get fridgeHint => 'ex. œufs, épinards, feta';

  @override
  String get logServing => 'Noter une portion';

  @override
  String get nextStep => 'Étape suivante';

  @override
  String get noSteps => 'Cette recette n’a pas d’étapes.';

  @override
  String get recipesTitle => 'Recettes';

  @override
  String get removeSaved => 'Retirer des favoris';

  @override
  String get savedLabel => 'Enregistrée';

  @override
  String get searchRecipes => 'Chercher parmi 166 000 recettes…';

  @override
  String get servingsLabel => 'Portions';

  @override
  String get servingsHint => 'Quantités et valeurs s’ajustent';

  @override
  String get shelfCooked => 'Cuisinées';

  @override
  String get shelfLoved => '4★ et plus';

  @override
  String get shelfQuick => '≤ 30 min';

  @override
  String get startCooking => 'Commencer';

  @override
  String get thisWeek => 'Cette semaine';

  @override
  String get timerDone => 'C’est l’heure';

  @override
  String get whatCanICook => 'Que cuisiner ?';

  @override
  String get whatCanICookBody =>
      'Dites ou photographiez ce qu’il y a dans le frigo';

  @override
  String allergensLeftOut(String list) {
    return '$list sont exclus : ils figurent sur votre liste d’allergies.';
  }

  @override
  String clearTickedN(int n) {
    return 'Effacer les cochés ($n)';
  }

  @override
  String cookedTimes(int n) {
    return 'cuisinée $n×';
  }

  @override
  String cookSubtitle(int servings) {
    return 'L’écran reste allumé · $servings portions';
  }

  @override
  String forRecipe(String title) {
    return 'Pour : $title';
  }

  @override
  String ideasFor(String list) {
    return 'Idées pour : $list';
  }

  @override
  String itemsLeft(int n, int total) {
    return '$n sur $total restants';
  }

  @override
  String plannedFor(String day) {
    return 'Prévu pour $day';
  }

  @override
  String planOfKcal(int n, int total) {
    return '$n sur $total kcal';
  }

  @override
  String roomForSnack(int kcal) {
    return 'De la place pour une collation de $kcal kcal.';
  }

  @override
  String shelfSaved(int n) {
    return 'Enregistrées · $n';
  }

  @override
  String shoppingTabCount(int n) {
    return 'Courses · $n';
  }

  @override
  String startTimer(String time) {
    return 'Minuteur $time';
  }

  @override
  String stepOf(int step, int steps) {
    return 'Étape $step sur $steps';
  }

  @override
  String timerRunning(String time) {
    return '$time · touchez pour arrêter';
  }

  @override
  String youRated(int stars) {
    return 'votre note $stars';
  }

  @override
  String get changePin => 'Modifier le code PIN';

  @override
  String get currentPin => 'Code PIN actuel';

  @override
  String get pinChanged => 'Code PIN modifié';

  @override
  String get dailyTargets => 'Objectifs du jour';

  @override
  String get tapToOverride => 'Touchez pour modifier';

  @override
  String get googleAccount => 'Compte Google';

  @override
  String get googleNotLinked => 'Non lié : code PIN et empreinte uniquement';

  @override
  String googleLinked(String email) {
    return '$email · nom uniquement';
  }

  @override
  String get historyAndYear => 'Historique et vue annuelle';

  @override
  String get limitShort => 'max.';

  @override
  String get link => 'Lier';

  @override
  String get unlink => 'Délier';

  @override
  String get lookAndLanguage => 'Apparence et langue';

  @override
  String get onDeviceAiAndData => 'IA sur l’appareil et données';

  @override
  String get savedRecipesTitle => 'Recettes enregistrées';

  @override
  String bornIn(int year) {
    return 'né·e en $year';
  }

  @override
  String planChip(String tier) {
    return 'Offre $tier · Voir les offres';
  }

  @override
  String get addAllergyTitle => 'Ajouter une allergie ou un régime';

  @override
  String get addAllergyHint => 'ex. arachides, gluten, végétarien';

  @override
  String allergyUnknown(String text) {
    return '« $text » n’est pas un allergène ou un régime que l’app sait filtrer. Essayez arachides, fruits à coque, lait, œuf, gluten, crustacés, poisson, soja, sésame, végétarien, végan ou pescétarien.';
  }

  @override
  String get continueButton => 'Continuer';

  @override
  String get dataLocked => 'Vos données sont verrouillées sur ce téléphone.';

  @override
  String get firstRunNext =>
      'Ensuite : un code PIN ou l’empreinte, puis vos objectifs.';

  @override
  String get googleOnlyName => 'Google ne remplit que votre nom.';

  @override
  String get lockItTitle => 'Rien qu’à vous';

  @override
  String get nameExample => 'ex. Sam';

  @override
  String get recordsNotInterprets =>
      'L’app enregistre ce que vous saisissez et ne l’interprète jamais. Informations générales issues de recommandations publiées, pas un avis médical.';

  @override
  String get recordTitle => 'Noter';

  @override
  String get reportHintShort => 'PDF et CSV de vos saisies';

  @override
  String get startTrial => 'Commencer l’essai gratuit de 7 jours';

  @override
  String get touchSensor => 'Touchez le capteur pour déverrouiller';

  @override
  String get trialBadge => '7 JOURS OFFERTS';

  @override
  String get usePin => 'Utiliser le code PIN';

  @override
  String get welcomeHeadline => 'Bien manger, en toute discrétion';

  @override
  String get welcomeIntro =>
      'Un assistant nutrition IA qui tourne sur ce téléphone. Pas d’IA dans le cloud, pas d’analytics.';

  @override
  String get welcomePointPrivate =>
      'Vos repas et vos échanges ne quittent jamais le téléphone';

  @override
  String get welcomePointData => '55 000 aliments et 166 000 recettes intégrés';

  @override
  String get welcomePointAllergens => 'Allergènes filtrés de chaque recette';

  @override
  String get yourName => 'Votre prénom';

  @override
  String currentTier(String tier) {
    return 'Actuel : $tier';
  }

  @override
  String severityN(int n) {
    return 'intensité $n';
  }

  @override
  String welcomeBack(String name) {
    return 'Bon retour, $name';
  }

  @override
  String get bestStreak => 'meilleure série';

  @override
  String get daysLogged => 'jours notés';

  @override
  String avgValue(String value) {
    return 'moy. $value';
  }

  @override
  String dayLine(String amount, int n) {
    return '$amount kcal · $n repas';
  }

  @override
  String sinceMonth(String month) {
    return 'depuis $month';
  }

  @override
  String streakShort(int n) {
    return 'série de $n jours';
  }

  @override
  String get estimatedTotal => 'Total estimé';

  @override
  String logThisMeal(String meal) {
    return 'Noter : $meal';
  }

  @override
  String activeKcalBurned(String kcal) {
    return '$kcal kcal brûlées';
  }

  @override
  String get weightUpdatedToday => 'Poids du jour mis à jour.';

  @override
  String get historyMeals => 'Repas';

  @override
  String get historyRecipes => 'Recettes cuisinées';

  @override
  String get historyRecipesEmpty =>
      'Aucune recette ces jours-là. Quand vous notez une recette (« J’ai mangé ça »), elle apparaît ici.';

  @override
  String lastCooked(String date) {
    return 'dernière fois $date';
  }

  @override
  String get removeItem => 'Retirer';

  @override
  String seenAs(String name) {
    return 'vu : $name';
  }

  @override
  String get confirmUndone => 'Annulé';

  @override
  String get editOnToday => 'Modifier dans Aujourd’hui';

  @override
  String get thinking => 'Réflexion…';

  @override
  String get searchInsteadInLog => 'Chercher plutôt dans Noter';

  @override
  String get burntWord => 'Brûlées';

  @override
  String get aiCardTitle => 'Obtenir l’assistant IA';

  @override
  String get aiCardBody =>
      'Décrivez vos repas avec vos mots et posez vos questions. Il tourne sur ce téléphone : un seul téléchargement (quelques Go, Wi-Fi conseillé). La recherche et l’ajout rapide marchent sans lui.';

  @override
  String get welcomeLog =>
      'Cherchez-le dans Noter, ou ajoutez vite les calories.';

  @override
  String get welcomeChat =>
      'Ou écrivez-le ou dites-le dans le Chat (« J’ai mangé 2 œufs et un toast »).';

  @override
  String get welcomePhoto => 'Ou prenez votre assiette en photo.';

  @override
  String get welcomeEnd => 'Votre journée se remplit ici.';

  @override
  String microsLowest(String name, String amount) {
    return 'Le plus bas : $name · $amount';
  }

  @override
  String get healthSheetReads =>
      'Lit votre poids, vos pas et vos calories actives. Rien n’y est écrit et rien ne quitte votre téléphone.';

  @override
  String lastSynced(String time) {
    return 'Dernière synchro à $time';
  }

  @override
  String get syncNow => 'Synchroniser';

  @override
  String get disconnect => 'Déconnecter';

  @override
  String healthSyncedWeights(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nouveaux poids',
      one: '1 nouveau poids',
      zero: 'Les poids sont à jour',
    );
    return '$_temp0';
  }

  @override
  String get cameraPermissionOff =>
      'L’accès à la caméra est désactivé. Autorisez-le dans les réglages de l’appli pour photographier votre repas.';

  @override
  String get openSettings => 'Ouvrir les réglages';

  @override
  String get tryAgain => 'Réessayer';

  @override
  String get cameraChoosePhoto => 'Choisir une photo';

  @override
  String get cameraGalleryNeedsAi =>
      'Une photo de la galerie nécessite l’assistant IA. Téléchargez-le dans le Chat.';

  @override
  String get mealsTitle => 'Repas';

  @override
  String mealsLogged(int n) {
    return '$n sur 4 notés';
  }

  @override
  String suggestedAmount(String amount) {
    return 'Suggéré ~$amount';
  }

  @override
  String get rateWhatYouAte => 'Notez ce que vous avez mangé';

  @override
  String get rateButton => 'Noter';

  @override
  String get leftToday => 'Reste aujourd’hui';

  @override
  String get drawerGo => 'Aller à';

  @override
  String get drawerTrack => 'Suivi';

  @override
  String get meOverline => 'Profil et objectifs';

  @override
  String goalIs(String goal) {
    return 'Objectif : $goal';
  }

  @override
  String get energy => 'Énergie';

  @override
  String get bornLabel => 'Naissance';

  @override
  String get planHeroTitle => 'Toute votre semaine, planifiée en un geste';

  @override
  String get planHeroBody =>
      'Petit-déjeuner, déjeuner et dîner parmi 166 000 recettes.';

  @override
  String planSized(String amount) {
    return 'Adapté à votre objectif de $amount';
  }

  @override
  String get planNoAllergens => 'Sans vos allergènes';

  @override
  String get planStarsFirst => 'Vos recettes 4★+ d’abord';

  @override
  String get fillsAfterPlanning => 'Se remplit après la planification';

  @override
  String get allergenFreeForYou => 'Sans allergènes pour vous';

  @override
  String ideasForMeal(String meal) {
    return 'Des idées pour le $meal';
  }

  @override
  String amountLeftApprox(String amount) {
    return '~$amount restantes';
  }

  @override
  String get highProtein => 'Riche en protéines';

  @override
  String get avatarTitle => 'Votre image';

  @override
  String get avatarEditHint => 'Photo ou icône, couleur, forme';

  @override
  String get avatarTabPicture => 'Image';

  @override
  String get avatarTabColour => 'Couleur';

  @override
  String get avatarTabShape => 'Forme';

  @override
  String get avatarPhotoCovers =>
      'Votre photo est affichée. Retirez-la pour choisir une icône, sa couleur et son fond.';

  @override
  String get avatarWoman => 'Femme';

  @override
  String get avatarMan => 'Homme';

  @override
  String get avatarNeutral => 'Neutre';

  @override
  String get avatarPhoto => 'Choisir une photo';

  @override
  String get avatarRemovePhoto => 'Retirer la photo';

  @override
  String get avatarColor => 'Couleur de fond';

  @override
  String avatarIconN(int n) {
    return 'Icône $n';
  }

  @override
  String get avatarBackground => 'Fond';

  @override
  String get avatarShape => 'Forme';

  @override
  String get avatarOutline => 'Contour';

  @override
  String avatarStyleName(String style) {
    String _temp0 = intl.Intl.selectLogic(style, {
      'solid': 'Uni',
      'gradient': 'Dégradé',
      'soft': 'Doux',
      'other': '$style',
    });
    return '$_temp0';
  }

  @override
  String avatarShapeName(String shape) {
    String _temp0 = intl.Intl.selectLogic(shape, {
      'circle': 'Cercle',
      'rounded': 'Arrondi',
      'hexagon': 'Hexagone',
      'flower': 'Fleur',
      'other': '$shape',
    });
    return '$_temp0';
  }

  @override
  String avatarRingName(String ring) {
    String _temp0 = intl.Intl.selectLogic(ring, {
      'none': 'Aucun',
      'thin': 'Fin',
      'thick': 'Épais',
      'other': '$ring',
    });
    return '$_temp0';
  }

  @override
  String get voiceTitle => 'Voix';

  @override
  String get voiceRepliesHint =>
      'Quand vous parlez à l’assistant, il répond aussi à voix haute, avec les voix installées sur votre téléphone ; rien ne quitte votre téléphone.';

  @override
  String get voiceRepliesSwitch => 'Lire les réponses à voix haute';

  @override
  String get voiceWoman => 'Voix de femme';

  @override
  String get voiceMan => 'Voix d’homme';

  @override
  String get voiceTest => 'Écouter un exemple';

  @override
  String get voiceSample =>
      'Bonjour ! Dites-moi ce que vous avez mangé, et je le note pour vous.';

  @override
  String get listening => 'J’écoute… touchez le micro pour arrêter';

  @override
  String get transcribing => 'J’écris ce que vous avez dit…';

  @override
  String get voiceNothingHeard =>
      'Rien entendu. Réessayez, un peu plus près du téléphone.';

  @override
  String get micDenied =>
      'Le micro est désactivé pour cette appli. Activez-le dans les paramètres Android pour parler à l’assistant.';

  @override
  String get reviewCheck => 'À vérifier : l’IA n’est pas sûre';

  @override
  String get reviewAddFat => 'Cuit avec de l’huile ou du beurre ?';

  @override
  String get reviewAddFatHint =>
      'C’est souvent le cas pour les plats frits ou rôtis, et une photo ne le montre pas. Ajoute une cuillère à soupe d’huile, modifiable.';

  @override
  String get aiModelRecommended => 'Recommandé';

  @override
  String nutrientName(String key) {
    String _temp0 = intl.Intl.selectLogic(key, {
      'starch_g': 'Amidon',
      'alcohol_g': 'Alcool',
      'water_g': 'Eau',
      'saturated_fat_g': 'Acides gras saturés',
      'mono_fat_g': 'Acides gras mono-insaturés',
      'poly_fat_g': 'Acides gras polyinsaturés',
      'trans_fat_g': 'Acides gras trans',
      'omega3_g': 'Oméga-3',
      'omega6_g': 'Oméga-6',
      'cholesterol_mg': 'Cholestérol',
      'sucrose_g': 'Saccharose',
      'glucose_g': 'Glucose',
      'fructose_g': 'Fructose',
      'lactose_g': 'Lactose',
      'added_sugar_g': 'Sucres ajoutés',
      'potassium_mg': 'Potassium',
      'calcium_mg': 'Calcium',
      'magnesium_mg': 'Magnésium',
      'phosphorus_mg': 'Phosphore',
      'iron_mg': 'Fer',
      'zinc_mg': 'Zinc',
      'copper_mg': 'Cuivre',
      'manganese_mg': 'Manganèse',
      'selenium_ug': 'Sélénium',
      'iodine_ug': 'Iode',
      'vitamin_a_ug': 'Vitamine A',
      'beta_carotene_ug': 'Bêta-carotène',
      'vitamin_d_ug': 'Vitamine D',
      'vitamin_e_mg': 'Vitamine E',
      'vitamin_k_ug': 'Vitamine K',
      'vitamin_c_mg': 'Vitamine C',
      'vitamin_b1_mg': 'Thiamine (B1)',
      'vitamin_b2_mg': 'Riboflavine (B2)',
      'vitamin_b3_mg': 'Niacine (B3)',
      'vitamin_b5_mg': 'Acide pantothénique (B5)',
      'vitamin_b6_mg': 'Vitamine B6',
      'vitamin_b7_ug': 'Biotine (B7)',
      'folate_ug': 'Folates',
      'vitamin_b12_ug': 'Vitamine B12',
      'choline_mg': 'Choline',
      'histidine_g': 'Histidine',
      'isoleucine_g': 'Isoleucine',
      'leucine_g': 'Leucine',
      'lysine_g': 'Lysine',
      'methionine_g': 'Méthionine',
      'phenylalanine_g': 'Phénylalanine',
      'threonine_g': 'Thréonine',
      'tryptophan_g': 'Tryptophane',
      'valine_g': 'Valine',
      'other': '$key',
    });
    return '$_temp0';
  }

  @override
  String nutrientGroup(String group) {
    String _temp0 = intl.Intl.selectLogic(group, {
      'macro': 'Macronutriments',
      'fat': 'Lipides',
      'sugar': 'Sucres',
      'mineral': 'Minéraux',
      'vitamin': 'Vitamines',
      'amino': 'Acides aminés essentiels',
      'other': '$group',
    });
    return '$_temp0';
  }

  @override
  String get lifeStage => 'Enceinte ou allaitante ?';

  @override
  String get lifeStageNone => 'Non';

  @override
  String get lifeStagePregnant => 'Enceinte';

  @override
  String get lifeStageBreastfeeding => 'Allaitante';

  @override
  String get trimester => 'Trimestre';

  @override
  String get pregnantNoLose =>
      'Perdre du poids n’est pas conseillé pendant la grossesse : vos objectifs restent au maintien du poids, plus ce dont le bébé a besoin à partir du 2e trimestre. Parlez-en à votre médecin.';

  @override
  String get babyAge => 'Âge du bébé';

  @override
  String get babyAge0to6 => '0–6 mois';

  @override
  String get babyAge7to12 => '7–12 mois';

  @override
  String get allNutrientsTitle => 'Tous les nutriments';

  @override
  String get moreNutrients => 'Plus : sucres simples, acides aminés';

  @override
  String get fewerNutrients => 'Moins';

  @override
  String get panelNote =>
      '≈ estimé d’après des aliments similaires · ≥ certains aliments ne l’indiquent pas · Objectifs en vitamines et minéraux, limites : apports de référence NASEM';

  @override
  String get microsLocked =>
      'Vitamines et minéraux du jour face à vos apports de référence, avec Basic.';

  @override
  String chipLow(String names) {
    return 'Peu : $names';
  }

  @override
  String chipOver(String names) {
    return 'Au-dessus de la limite : $names';
  }

  @override
  String upperLimitValue(String amount) {
    return 'limite supérieure $amount';
  }

  @override
  String get patternsTitle => 'Tendances';

  @override
  String get patternsNone =>
      'Rien ne ressort encore. Les tendances demandent au moins une semaine de saisies.';

  @override
  String get captionPatterns => 'Ce que montrent vos saisies :';

  @override
  String patternLogging(String n, String days) {
    return 'Jours notés en entier : $n sur les $days derniers. Les autres tendances ne comptent que ceux-là.';
  }

  @override
  String patternSkipped(String meal, String n, String days) {
    return '$meal sauté $n jours sur $days';
  }

  @override
  String patternLate(String time, String n, String days) {
    return 'Repas après $time $n jours sur $days';
  }

  @override
  String patternWeekend(String weekend, String weekday, String change) {
    return 'Week-end $weekend kcal par jour, semaine $weekday kcal ($change)';
  }

  @override
  String patternGap(String nutrient, String n, String days) {
    return '$nutrient sous 80 % de l’objectif $n jours sur $days';
  }

  @override
  String patternWeight(String change, String kcal) {
    return 'Tendance du poids $change kg par semaine, en moyenne $kcal kcal par jour';
  }

  @override
  String patternSymptom(
    String symptom,
    String food,
    String n,
    String times,
    String hours,
  ) {
    return '$symptom noté dans les $hours h après $food : $n fois sur $times. Un décompte, pas une cause : vous pourriez en parler à un médecin.';
  }

  @override
  String get answerChecking => 'vérification…';

  @override
  String get answerUnverified =>
      'Je n’ai pas pu vérifier cette réponse, elle est donc masquée. Essayez de reformuler.';
}
