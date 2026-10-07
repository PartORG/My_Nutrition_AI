// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'MyFoodMind';

  @override
  String get whoIsEating => 'Qui mange ?';

  @override
  String get addProfile => 'Ajouter un profil';

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
      'Votre code PIN protège ce profil sur un téléphone partagé. Si vous l’oubliez, le profil pourra seulement être supprimé.';

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
    return 'MyFoodMind fait tourner son IA entièrement sur votre téléphone et nécessite au moins 6 Go de RAM. Ce téléphone en a environ $gb Go.';
  }

  @override
  String get chatHint => 'Posez une question, notez un repas…';

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
      'Information générale, pas un avis médical. Parlez-en à votre médecin avant de changer votre alimentation.';

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
  String get allergiesSection => 'Allergies';

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
  String get kindProduct => 'Produit';

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
  String get invalidNumber => 'Saisissez un nombre valide';

  @override
  String get under18 =>
      'Ces formules ne s’appliquent pas avant 18 ans. Fixez les objectifs ci-dessous avec votre pédiatre.';

  @override
  String get targetsTitle => 'Objectifs du jour';

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
  String get aiKnowsLoading => 'Disponible quand l’IA est chargée.';

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
      'Les notifications de MyFoodMind sont désactivées dans les paramètres Android.';

  @override
  String get voiceInput => 'Parler';

  @override
  String get voiceStop => 'Arrêter l’écoute';

  @override
  String get voiceUnavailable =>
      'La saisie vocale nécessite la reconnaissance vocale hors ligne sur ce téléphone (appli Google → Paramètres → Voix → Reconnaissance vocale hors connexion → français). MyFoodMind n’envoie jamais votre voix en ligne.';

  @override
  String youSaid(String text) {
    return 'Vous avez dit : $text';
  }

  @override
  String aiSaid(String text) {
    return 'MyFoodMind a dit : $text';
  }

  @override
  String get useFingerprint => 'Utiliser l’empreinte';

  @override
  String get fingerprintTitle => 'Déverrouiller avec l’empreinte';

  @override
  String get fingerprintHint =>
      'Seulement tant que c’est le seul profil du téléphone : Android ne sait pas à qui appartient l’empreinte.';

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
  String get featBasic2 => 'Tableau de bord hebdomadaire et mensuel';

  @override
  String get featBasic3 => 'Micronutriments, séries, évolution du poids';

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
  String get lockedTitle =>
      'Les tendances hebdomadaires et mensuelles sont dans Basic';

  @override
  String get lockedBody =>
      'Voyez les calories par jour par rapport à votre objectif, les moyennes quotidiennes, les micronutriments, votre série de jours notés et l’évolution de votre poids.';

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
      'Notez votre poids au moins deux fois pour voir l’évolution.';

  @override
  String get logWeight => 'Noter le poids';

  @override
  String get weightLogged => 'Poids enregistré';

  @override
  String get plansUnavailable =>
      'Les formules ne sont pas disponibles dans cette version.';

  @override
  String cautionAllergy(String food, String allergen) {
    return 'Contient $food, sur votre liste d’allergies ($allergen)';
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
  String get reportSubject => 'Rapport MyFoodMind';

  @override
  String get reportFailed => 'Impossible de créer le rapport.';

  @override
  String reportTitle(String name) {
    return 'Rapport MyFoodMind : $name';
  }

  @override
  String reportCreated(String date) {
    return 'créé le $date';
  }

  @override
  String get reportDisclaimer =>
      'Saisi par l’utilisateur dans l’appli MyFoodMind. Les valeurs sont affichées telles que notées ; l’appli ne les interprète pas et ne donne pas d’avis médical. Les limites viennent des maladies choisies par l’utilisateur.';

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
      'La caméra n’est pas disponible. Autorisez l’accès à la caméra pour MyFoodMind dans les paramètres Android.';

  @override
  String get cameraShoot => 'Prendre une photo';

  @override
  String get cameraNaming => 'Reconnaissance des aliments…';

  @override
  String get cameraNamingFailed =>
      'Impossible de reconnaître les aliments. Réessayez.';

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
    return '$name : absent de la base, touchez Modifier pour choisir un aliment';
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
  String get calcium => 'Calcium';

  @override
  String get iron => 'Fer';

  @override
  String get magnesium => 'Magnésium';

  @override
  String get potassium => 'Potassium';

  @override
  String get vitaminC => 'Vitamine C';

  @override
  String get vitaminD => 'Vitamine D';

  @override
  String get vitaminB12 => 'Vitamine B12';

  @override
  String get microsTitle => 'Vitamines et minéraux';

  @override
  String microsCoverage(int known, int meals) {
    return 'Sur $known des $meals repas aux valeurs connues ; apports de référence UE';
  }

  @override
  String get productsTitle => 'Produits emballés';

  @override
  String get productsNone =>
      'Intégrés : produits de 2019, peu de produits européens. Téléchargez tous les produits d’Open Food Facts (tous pays) pour trouver ce que vous achetez. Wi-Fi conseillé.';

  @override
  String productsHave(String count, String date) {
    return '$count produits d’Open Food Facts, mis à jour le $date.';
  }

  @override
  String productsDownload(int mb) {
    return 'Télécharger ($mb Mo)';
  }

  @override
  String get productsRemove => 'Supprimer';

  @override
  String get productsHint =>
      'Un produit emballé manque ? Téléchargez tous les produits dans Moi.';

  @override
  String get healthConnect => 'Health Connect';

  @override
  String get appleHealth => 'Apple Santé';

  @override
  String get healthSyncHint =>
      'Lit votre poids (pour vos objectifs) et vos pas. Rien n’y est écrit et rien ne quitte votre téléphone.';

  @override
  String get healthSyncDenied =>
      'Pas d’accès. Autorisez le poids et les pas dans les réglages de l’appli santé, puis réessayez.';

  @override
  String stepsToday(String steps) {
    return '$steps pas aujourd’hui';
  }

  @override
  String get mealPlan => 'Plan de repas';

  @override
  String get planTab => 'Plan';

  @override
  String get planEmpty =>
      'Planifiez votre semaine : petit-déjeuner, déjeuner et dîner tirés de la base de recettes, adaptés à votre objectif calorique, sans vos allergènes, et d’abord les recettes que vous avez bien notées.';

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
      'Ajoutez le widget MyFoodMind à votre écran d’accueil. Les calories du jour y seront alors visibles sans votre code PIN.';

  @override
  String get welcomeTitle => 'Notez votre premier repas';

  @override
  String get welcomeBody =>
      'Écrivez-le ou dites-le dans le chat (« J’ai mangé 2 œufs et un toast »), cherchez-le dans Noter ou prenez une photo. Votre journée se remplit ici.';

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
      'Comprend mieux, répond environ 2 à 3 fois plus lentement. Pour les téléphones avec 8 Go de RAM.';

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
  String get privacyPolicy => 'Politique de confidentialité';

  @override
  String get termsOfUse => 'Conditions d’utilisation';

  @override
  String get licenses => 'Licences et modèles d’IA';
}
