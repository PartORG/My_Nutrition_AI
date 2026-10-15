// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Ukrainian (`uk`).
class AppLocalizationsUk extends AppLocalizations {
  AppLocalizationsUk([String locale = 'uk']) : super(locale);

  @override
  String get appTitle => 'MyFoodMind';

  @override
  String get addProfile => 'Створити профіль';

  @override
  String get googleWrongAccount =>
      'Це не той обліковий запис Google, з яким створено профіль.';

  @override
  String get signInWithGoogle => 'Увійти через Google';

  @override
  String get continueWithGoogle => 'Продовжити з Google';

  @override
  String get profileName => 'Ім\'я';

  @override
  String get nameRequired => 'Введіть ім\'я';

  @override
  String get pinLabel => 'PIN (4–6 цифр)';

  @override
  String get pinConfirmLabel => 'Повторіть PIN';

  @override
  String get pinInvalid => 'Використайте 4–6 цифр';

  @override
  String get pinMismatch => 'PIN-коди не збігаються';

  @override
  String get pinHint =>
      'PIN відкриває застосунок, коли відбиток не спрацьовує. Якщо ви його забудете, профіль можна буде лише видалити.';

  @override
  String get create => 'Створити';

  @override
  String get unlock => 'Розблокувати';

  @override
  String enterPinFor(String name) {
    return 'PIN для $name';
  }

  @override
  String pinWrong(int left) {
    String _temp0 = intl.Intl.pluralLogic(
      left,
      locale: localeName,
      other: 'Неправильний PIN. Залишилося $left спроби до паузи.',
      many: 'Неправильний PIN. Залишилося $left спроб до паузи.',
      few: 'Неправильний PIN. Залишилося $left спроби до паузи.',
      one: 'Неправильний PIN. Залишилася $left спроба до паузи.',
    );
    return '$_temp0';
  }

  @override
  String pinLocked(int seconds) {
    return 'Забагато спроб. Спробуйте знову через $seconds с.';
  }

  @override
  String get forgotPin => 'Забули PIN?';

  @override
  String deleteProfileTitle(String name) {
    return 'Видалити $name?';
  }

  @override
  String get deleteProfileBody =>
      'Забутий PIN неможливо відновити. Видалення прибере цей профіль і всі його страви, журнал та історію чату з цього телефона. Це не можна скасувати.';

  @override
  String get delete => 'Видалити';

  @override
  String get cancel => 'Скасувати';

  @override
  String get lock => 'Заблокувати';

  @override
  String hello(String name) {
    return 'Привіт, $name';
  }

  @override
  String get deviceUnsupportedTitle => 'Цей телефон не підтримується';

  @override
  String deviceUnsupportedBody(String gb) {
    return 'MyFoodMind запускає ШІ повністю на телефоні й потребує щонайменше 6 ГБ оперативної пам’яті. У цього телефона приблизно $gb ГБ.';
  }

  @override
  String get chatHint => 'Запитайте про їжу, запишіть страву…';

  @override
  String get send => 'Надіслати';

  @override
  String get preparingAi =>
      'Готуємо ШІ на пристрої… Перший запуск триває близько хвилини.';

  @override
  String get confirmSave => 'Зберегти';

  @override
  String get confirmDiscard => 'Відхилити';

  @override
  String get confirmSaved => 'Збережено';

  @override
  String get confirmDiscarded => 'Відхилено';

  @override
  String get perServing => 'На порцію';

  @override
  String minutesServings(int minutes, int servings) {
    return '$minutes хв · порцій: $servings';
  }

  @override
  String get notMedicalAdvice =>
      'Загальна інформація з опублікованих настанов, не медична порада. Вона не замінює лікаря чи дієтолога: порадьтеся з ними, перш ніж змінювати харчування або ліки.';

  @override
  String get chatDisclaimer =>
      'Відповіді ШІ можуть бути хибними й не замінюють лікаря. У надзвичайній ситуації телефонуйте на місцевий номер екстреної допомоги.';

  @override
  String get medicalDisclaimerTitle => 'Медичне застереження';

  @override
  String get medicalDisclaimerBody =>
      'MyFoodMind і його ШІ-помічник надають загальну інформацію про їжу та харчування. Це не медичний виріб, і він не діагностує, не лікує, не виліковує і не запобігає жодним захворюванням.\n\nНіщо в застосунку, зокрема відповіді помічника, обмеження для станів здоров\'я та медична інформація, не замінює поради лікаря, дієтолога чи іншого кваліфікованого фахівця. ШІ працює на вашому телефоні й може помилятися.\n\nЗавжди радьтеся з лікарем, перш ніж змінювати харчування, ліки чи лікування, особливо якщо у вас є захворювання, ви вагітні чи годуєте грудьми або маєте чи мали розлад харчової поведінки. Ніколи не нехтуйте порадою фахівця і не відкладайте звернення до нього через щось у цьому застосунку.\n\nЯкщо вам здається, що це невідкладний медичний стан, негайно телефонуйте на місцевий номер екстреної допомоги.';

  @override
  String get crisisTitle => 'Вам не потрібно проходити через це самотужки';

  @override
  String get crisisBody =>
      'Якщо ви можете собі зашкодити, зателефонуйте зараз на місцевий номер екстреної допомоги. Безкоштовні конфіденційні гарячі лінії вашої країни є на findahelpline.com.';

  @override
  String get crisisButton => 'Знайти гарячу лінію';

  @override
  String limitReached(int count) {
    return 'Ви використали сьогоднішні $count безкоштовних повідомлень ШІ. Вони оновлюються опівночі, або отримайте необмежений чат у Basic.';
  }

  @override
  String get agentError => 'Щось пішло не так. Спробуйте ще раз.';

  @override
  String get reportResponse => 'Поскаржитися на відповідь';

  @override
  String get kcal => 'ккал';

  @override
  String get protein => 'Білки';

  @override
  String get fat => 'Жири';

  @override
  String get carbs => 'Вуглеводи';

  @override
  String get fiber => 'Клітковина';

  @override
  String get sugar => 'Цукор';

  @override
  String get sodium => 'Натрій';

  @override
  String get recipeIdeas => 'Ідеї рецептів';

  @override
  String get ingredients => 'Інгредієнти';

  @override
  String get steps => 'Кроки';

  @override
  String get healthInfo => 'Інформація про здоров’я';

  @override
  String servingsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count порції',
      many: '$count порцій',
      few: '$count порції',
      one: '$count порція',
    );
    return '$_temp0';
  }

  @override
  String get iAteThis => 'Я це з’їв(ла)';

  @override
  String get aiKnowsTitle => 'Що ШІ знає про вас';

  @override
  String get aiKnowsIntro =>
      'Це все, що асистент знає про вас. Дані залишаються на цьому телефоні.';

  @override
  String get factsSection => 'Що ви йому розповіли';

  @override
  String get factsEmpty =>
      'Поки нічого. Напишіть у чат, наприклад, «У мене є аерогриль».';

  @override
  String get allergiesSection => 'Алергії та дієта';

  @override
  String get allergiesEmpty => 'Не записано.';

  @override
  String get habitsSection => 'Звички, які він помітив (останні 30 днів)';

  @override
  String get habitsEmpty => 'Поки замало записаних страв.';

  @override
  String get conversationsSection => 'Розмови';

  @override
  String conversationsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Збережено $count повідомлення.',
      many: 'Збережено $count повідомлень.',
      few: 'Збережено $count повідомлення.',
      one: 'Збережено $count повідомлення.',
      zero: 'Повідомлень не збережено.',
    );
    return '$_temp0';
  }

  @override
  String get forgetConversations => 'Забути минулі розмови';

  @override
  String get forgetConversationsBody =>
      'Видаляє історію чату і пам’ять ШІ про неї. Записані страви, факти та алергії залишаються.';

  @override
  String get forget => 'Забути';

  @override
  String get edit => 'Змінити';

  @override
  String get tabToday => 'Сьогодні';

  @override
  String get tabChat => 'Чат';

  @override
  String get tabLog => 'Запис';

  @override
  String get tabMe => 'Я';

  @override
  String eatenOfGoal(int goal) {
    return 'з $goal ккал';
  }

  @override
  String kcalLeft(int left) {
    return 'Залишилось $left ккал';
  }

  @override
  String kcalOver(int over) {
    return 'Перевищено на $over ккал';
  }

  @override
  String overBy(String amount) {
    return 'більше на $amount';
  }

  @override
  String get eatenToday => 'З’їдено сьогодні';

  @override
  String get setGoalsTitle => 'Встановіть денні цілі';

  @override
  String get setGoalsBody =>
      'Розкажіть трохи про себе, щоб отримати цілі щодо калорій і поживних речовин.';

  @override
  String get setGoalsButton => 'Встановити цілі';

  @override
  String get todaysMeals => 'Страви сьогодні';

  @override
  String get noMealsYet =>
      'Поки нічого не записано. Скористайтеся вкладкою «Запис» або напишіть у чат, що ви з’їли.';

  @override
  String get deleteMealTitle => 'Видалити цей запис?';

  @override
  String get mealBreakfast => 'Сніданок';

  @override
  String get mealLunch => 'Обід';

  @override
  String get mealDinner => 'Вечеря';

  @override
  String get mealSnack => 'Перекус';

  @override
  String get searchFood => 'Пошук продуктів, страв, рецептів…';

  @override
  String get kindFood => 'Продукт';

  @override
  String get kindDish => 'Страва';

  @override
  String get kindRecipe => 'Рецепт';

  @override
  String get kindProduct => 'Товар';

  @override
  String perServing2(int kcal) {
    return '$kcal ккал на порцію';
  }

  @override
  String per100g(int kcal) {
    return '$kcal ккал на 100 г';
  }

  @override
  String get servings => 'Порції';

  @override
  String get grams => 'Грами';

  @override
  String get logButton => 'Записати';

  @override
  String loggedSnack(String label) {
    return 'Записано: $label';
  }

  @override
  String get noResults => 'Немає збігів у базі продуктів.';

  @override
  String get goalsTitle => 'Ваші денні цілі';

  @override
  String get goalsIntro =>
      'Потрібно для розрахунку цілей щодо калорій і поживних речовин. Залишається на цьому телефоні.';

  @override
  String get later => 'Пізніше';

  @override
  String get units => 'Одиниці';

  @override
  String get metric => 'Метричні';

  @override
  String get imperial => 'Імперські';

  @override
  String get sex => 'Стать для формули';

  @override
  String get female => 'Жіноча';

  @override
  String get male => 'Чоловіча';

  @override
  String get other => 'Інша';

  @override
  String get birthYear => 'Рік народження';

  @override
  String get heightCm => 'Зріст (см)';

  @override
  String get heightFt => 'фут';

  @override
  String get heightIn => 'дюйм';

  @override
  String get weightKg => 'Вага (кг)';

  @override
  String get weightLb => 'Вага (фунти)';

  @override
  String get activity => 'Активність';

  @override
  String get activitySedentary => 'Сидяча: переважно сиджу';

  @override
  String get activityLight => 'Легка: тренування 1–3 дні на тиждень';

  @override
  String get activityModerate => 'Помірна: тренування 3–5 днів на тиждень';

  @override
  String get activityActive => 'Активна: тренування 6–7 днів на тиждень';

  @override
  String get activityVeryActive =>
      'Дуже активна: щоденні важкі тренування або фізична робота';

  @override
  String get goal => 'Мета';

  @override
  String get goalLose => 'Схуднути';

  @override
  String get goalMaintain => 'Підтримувати вагу';

  @override
  String get goalGain => 'Набрати вагу';

  @override
  String get invalidNumber => 'Введіть правильне число';

  @override
  String get under18 =>
      'Для людей до 18 років ці формули не підходять. Встановіть цілі разом із педіатром нижче.';

  @override
  String get aboutMe => 'Про мене';

  @override
  String get sexShort => 'Стать';

  @override
  String get height => 'Зріст';

  @override
  String get weight => 'Вага';

  @override
  String get targetsNone => 'Цілей поки немає.';

  @override
  String get custom => 'власна';

  @override
  String editTarget(String name) {
    return 'Ціль: $name';
  }

  @override
  String get resetTarget => 'Використати розрахунок';

  @override
  String get editDetails => 'Змінити мої дані';

  @override
  String get aiKnowsLoading => 'Доступно, коли ШІ завантажиться.';

  @override
  String get switchProfile => 'Заблокувати й змінити профіль';

  @override
  String get limitSuffix => 'макс.';

  @override
  String get remindersTitle => 'Нагадування';

  @override
  String get remindersHint =>
      'Час підлаштовується під ваші звичні години їжі, коли ви запишете кілька страв.';

  @override
  String get reminderBreakfast => 'Записати сніданок';

  @override
  String get reminderLunch => 'Записати обід';

  @override
  String get reminderDinner => 'Записати вечерю';

  @override
  String get reminderEvening => 'Вечірній підсумок';

  @override
  String notifMeal(String name, String meal) {
    return '$name, час записати $meal?';
  }

  @override
  String notifEvening(String name) {
    return '$name, як минув день? Ваш підсумок готовий.';
  }

  @override
  String get notificationsDenied =>
      'Сповіщення для MyFoodMind вимкнені в налаштуваннях Android.';

  @override
  String get voiceInput => 'Говорити';

  @override
  String get voiceStop => 'Зупинити запис';

  @override
  String get voiceUnavailable =>
      'Голосове введення потребує офлайн-розпізнавання мовлення на цьому телефоні (додаток Google → Налаштування → Голос → Офлайн-розпізнавання мовлення → українська). MyFoodMind ніколи не надсилає ваш голос в інтернет.';

  @override
  String youSaid(String text) {
    return 'Ви сказали: $text';
  }

  @override
  String aiSaid(String text) {
    return 'MyFoodMind сказав: $text';
  }

  @override
  String get useFingerprint => 'Відбиток пальця';

  @override
  String get fingerprintTitle => 'Розблокування відбитком пальця';

  @override
  String get fingerprintHint => 'Відкривайте відбитком пальця замість PIN.';

  @override
  String fingerprintReason(String name) {
    return 'Розблокувати профіль $name';
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
  String get plansTitle => 'Тарифи';

  @override
  String get monthly => 'Щомісяця';

  @override
  String get yearly => 'Щороку';

  @override
  String perMonth(String price) {
    return '$price / місяць';
  }

  @override
  String perYear(String price) {
    return '$price / рік';
  }

  @override
  String trialThen(String price) {
    return '7 днів безкоштовно, потім $price';
  }

  @override
  String get subscribe => 'Підписатися';

  @override
  String get upgrade => 'Покращити';

  @override
  String get switchPlan => 'Змінити';

  @override
  String get currentPlan => 'Поточний тариф';

  @override
  String get restorePurchases => 'Відновити покупки';

  @override
  String get subscriptionTerms =>
      'Підписки поновлюються автоматично, доки ви їх не скасуєте. Скасувати можна будь-коли в Google Play → Платежі й підписки. Одна підписка діє для всіх профілів на цьому телефоні.';

  @override
  String get devBillingBanner =>
      'Режим розробника: без справжньої оплати. Оберіть будь-який тариф, щоб спробувати.';

  @override
  String get devBackToFree => 'Назад до Free (розробник)';

  @override
  String get purchaseFailed => 'Покупка не вдалася. Спробуйте ще раз.';

  @override
  String get featBasic1 => 'Необмежений чат зі ШІ';

  @override
  String get featBasic3 => 'Нагадування пити воду, серії днів, мікроелементи';

  @override
  String get featMedium1 => 'Усе з Basic';

  @override
  String get featMedium2 =>
      'Стани здоров’я: обмеження та поради щодо харчування';

  @override
  String get featMedium3 => 'Журнал симптомів і показників, звіт для лікаря';

  @override
  String get featPro1 => 'Усе з Medium';

  @override
  String get featPro2 => 'Розпізнавання їжі на фото й у живому режимі камери';

  @override
  String get featPro3 =>
      'Записує страви й знаходить рецепти з того, що бачить камера';

  @override
  String get yourPlan => 'Ваш тариф';

  @override
  String get seePlans => 'Переглянути тарифи';

  @override
  String get periodDay => 'День';

  @override
  String get periodWeek => 'Тиждень';

  @override
  String get periodMonth => 'Місяць';

  @override
  String get lockedTitle => 'Більше з Basic';

  @override
  String get lockedBody =>
      'Серія днів із записами, план харчування на тиждень зі списком покупок, нагадування пити воду та історія за 3 місяці.';

  @override
  String get caloriesPerDay => 'Калорії за день';

  @override
  String goalLine(int kcal) {
    return 'Ціль $kcal';
  }

  @override
  String dailyAverage(int days) {
    return 'Середнє за день ($days дн. із записами)';
  }

  @override
  String streakDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Серія записів: $days дня',
      many: 'Серія записів: $days днів',
      few: 'Серія записів: $days дні',
      one: 'Серія записів: $days день',
      zero: 'Серії записів поки немає',
    );
    return '$_temp0';
  }

  @override
  String get weightTrend => 'Вага';

  @override
  String get weightTrendEmpty =>
      'Запишіть вагу хоча б двічі, щоб побачити динаміку.';

  @override
  String get logWeight => 'Записати вагу';

  @override
  String get weightLogged => 'Вагу збережено';

  @override
  String get plansUnavailable => 'Тарифи недоступні в цій збірці.';

  @override
  String cautionAllergy(String food, String allergen) {
    return 'Містить $food — це виключають ваші алергії чи дієта ($allergen)';
  }

  @override
  String cautionCondition(String food, String condition) {
    return 'Містить $food — продукт, якого слід уникати при стані «$condition»';
  }

  @override
  String get condDiabetesT2 => 'Діабет 2 типу';

  @override
  String get condHypertension => 'Підвищений тиск';

  @override
  String get condGout => 'Подагра';

  @override
  String get condAls => 'БАС';

  @override
  String get condMs => 'Розсіяний склероз';

  @override
  String get healthTitle => 'Здоров’я';

  @override
  String get healthMeHint => 'Стани, журнал, хронологія, звіт для лікаря';

  @override
  String get conditionsTitle => 'Стани здоров’я';

  @override
  String get conditionsHint =>
      'Рецепти без продуктів, яких слід уникати, а обмеження знижують денні цілі. Це загальні поради, не медичні: порадьтеся з лікарем, перш ніж змінювати харчування.';

  @override
  String limitLine(String nutrient, String amount, String condition) {
    return '$nutrient: не більше $amount на день ($condition)';
  }

  @override
  String avoidLine(String foods) {
    return 'Уникати: $foods';
  }

  @override
  String limitFrom(String condition) {
    return 'обмеження через «$condition»';
  }

  @override
  String get timelineTitle => 'Хронологія';

  @override
  String get timelineHint => 'Поживні речовини, показники й симптоми за датами';

  @override
  String get timelineEmpty => 'За цей період нічого не записано.';

  @override
  String get reportButton => 'Звіт для лікаря';

  @override
  String get reportHint => 'PDF і CSV з усіма вашими записами';

  @override
  String get journalTitle => 'Журнал';

  @override
  String get journalHint => 'Останні 14 днів';

  @override
  String get journalEmpty => 'За останні 14 днів нічого не записано.';

  @override
  String get symptom => 'Симптом';

  @override
  String get symptomHint => 'Що ви відчуваєте? Напр., втома';

  @override
  String get severity => 'Тяжкість (необов’язково)';

  @override
  String get severityHint => '1 = легко, 5 = сильно';

  @override
  String get glucose => 'Глюкоза крові';

  @override
  String get bloodPressure => 'Тиск';

  @override
  String get systolic => 'Систолічний (верхній)';

  @override
  String get diastolic => 'Діастолічний (нижній)';

  @override
  String get deleteEntryTitle => 'Видалити цей запис?';

  @override
  String get healthLockedTitle => 'Відстеження здоров’я входить у Medium';

  @override
  String get healthLockedBody =>
      'Medium додає стани здоров’я (фільтр рецептів і денні обмеження), журнал симптомів і показників, графіки й звіт для лікаря.';

  @override
  String conditionsStillApply(String conditions) {
    return 'Ваші стани здоров’я й далі фільтрують рецепти й обмежують цілі: $conditions';
  }

  @override
  String days(int count) {
    return '$count дн.';
  }

  @override
  String get perDay => 'на день';

  @override
  String get symptomsTitle => 'Симптоми';

  @override
  String get readingsTitle => 'Показники';

  @override
  String get reportSheetHint =>
      'PDF для читання і CSV для таблиць з усім, що ви записали. Ви самі обираєте, куди їх надіслати; застосунок нічого не надсилає сам.';

  @override
  String get reportShare => 'Створити й поділитися';

  @override
  String get reportSubject => 'Звіт MyFoodMind';

  @override
  String get reportFailed => 'Не вдалося створити звіт.';

  @override
  String reportTitle(String name) {
    return 'Звіт MyFoodMind: $name';
  }

  @override
  String reportCreated(String date) {
    return 'створено $date';
  }

  @override
  String get reportDisclaimer =>
      'Записано користувачем у застосунку MyFoodMind. Значення показані як записані; застосунок їх не тлумачить і не дає медичних порад. Обмеження походять від станів, які обрав користувач.';

  @override
  String get reportNone => 'Не записано.';

  @override
  String reportDailyNutrition(int days) {
    return 'Харчування за днями ($days дн. із записами)';
  }

  @override
  String get reportDate => 'Дата';

  @override
  String get reportItems => 'Записи';

  @override
  String get reportMeasurement => 'Показник';

  @override
  String get reportValue => 'Значення';

  @override
  String get cameraTitle => 'Камера';

  @override
  String get cameraOpen => 'Відкрити камеру';

  @override
  String get cameraPhoto => 'Фото';

  @override
  String get cameraLive => 'Наживо';

  @override
  String get cameraUnavailable =>
      'Камера недоступна. Дозвольте MyFoodMind доступ до камери в налаштуваннях Android.';

  @override
  String get cameraShoot => 'Зробити фото';

  @override
  String get cameraNaming => 'Розпізнаємо їжу…';

  @override
  String get cameraNamingFailed =>
      'Розпізнавання ШІ не вдалося: показано швидке виявлення. Перевірте продукти.';

  @override
  String cameraUseFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Використати $count позиції',
      many: 'Використати $count позицій',
      few: 'Використати $count позиції',
      one: 'Використати $count позицію',
      zero: 'Продовжити',
    );
    return '$_temp0';
  }

  @override
  String get reviewTitle => 'Перевірте знайдене';

  @override
  String get reviewHint =>
      'Кількість із фото — це оцінка (≈). Змініть або приберіть будь-що; нічого не збережеться, поки ви не натиснете «Записати».';

  @override
  String get reviewEmpty => 'Їжу не знайдено. Додайте позиції за назвою.';

  @override
  String notInDatabase(String name) {
    return '$name: немає в базі, натисніть «змінити», щоб обрати продукт';
  }

  @override
  String get reviewChange => 'Змінити';

  @override
  String get reviewAdd => 'Додати позицію';

  @override
  String get reviewLog => 'Записати страву';

  @override
  String reviewLogged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Записано $count позиції',
      many: 'Записано $count позицій',
      few: 'Записано $count позиції',
      one: 'Записано $count позицію',
    );
    return '$_temp0';
  }

  @override
  String get reviewCook => 'Що можна приготувати?';

  @override
  String get yourRating => 'Ваша оцінка';

  @override
  String get kindRecent => 'Нещодавнє';

  @override
  String get recentFoods => 'Нещодавні й часті';

  @override
  String repeatYesterday(String meal, int kcal) {
    return 'Учорашній $meal · $kcal ккал';
  }

  @override
  String get quickAdd => 'Швидко додати';

  @override
  String get quickAddName => 'Назва (необов’язково)';

  @override
  String get editMeal => 'Змінити запис';

  @override
  String get changeFood => 'Змінити продукт';

  @override
  String get appearance => 'Вигляд';

  @override
  String cardLogMeal(String meal) {
    return 'Записати: $meal';
  }

  @override
  String get cardSaveRecipe => 'Зберегти рецепт';

  @override
  String get cardRateRecipe => 'Оцінити рецепт';

  @override
  String get cardRemember => 'Запам’ятати';

  @override
  String get cardAddAllergy => 'Додати алергію';

  @override
  String get cardRemoveAllergy => 'Прибрати алергію';

  @override
  String get cardAddDiet => 'Додати дієту';

  @override
  String get cardRemoveDiet => 'Прибрати дієту';

  @override
  String get captionConfirm => 'Перевірте й натисніть «Зберегти».';

  @override
  String get captionIdeas => 'Ось кілька ідей. Натисніть, щоб побачити рецепт.';

  @override
  String captionIdeasAvoiding(String foods) {
    return 'Обережно: у вас алергія на $foods або ви цього уникаєте. Ось рецепти без цього; натисніть, щоб переглянути.';
  }

  @override
  String get captionRecipe => 'Ось рецепт.';

  @override
  String get captionNumbers => 'Ось цифри.';

  @override
  String get captionCamera => 'Натисніть кнопку, щоб відкрити камеру.';

  @override
  String get cardLogSymptom => 'Записати симптом';

  @override
  String get cardLogGlucose => 'Записати глюкозу';

  @override
  String get cardLogBloodPressure => 'Записати тиск';

  @override
  String get cardLogWater => 'Записати воду';

  @override
  String get last7Days => 'Останні 7 днів';

  @override
  String get weekReviewTitle => 'Ваш тиждень';

  @override
  String reviewLoggedDays(int days) {
    return 'Ви записували їжу $days з 7 днів.';
  }

  @override
  String reviewKcal(int avg, int goal) {
    return 'У ці дні: у середньому $avg ккал, ціль $goal.';
  }

  @override
  String reviewUnder(String nutrient, int days) {
    return '$nutrient: менше 80 % цілі протягом $days дн.';
  }

  @override
  String reviewOver(String nutrient, int days) {
    return '$nutrient: понад ліміт протягом $days дн.';
  }

  @override
  String reviewWater(int avg, int goal) {
    return 'Вода: $avg мл на день, ціль $goal мл.';
  }

  @override
  String reviewTop(String food) {
    return 'Найчастіше: $food.';
  }

  @override
  String get reviewIdeas => 'Ідеї на наступний тиждень';

  @override
  String reviewAskHigh(String nutrient) {
    return 'Запропонуй рецепти з високим вмістом: $nutrient';
  }

  @override
  String reviewAskLow(String nutrient) {
    return 'Запропонуй рецепти з низьким вмістом: $nutrient';
  }

  @override
  String get calcium => 'Кальцій';

  @override
  String get iron => 'Залізо';

  @override
  String get magnesium => 'Магній';

  @override
  String get potassium => 'Калій';

  @override
  String get vitaminC => 'Вітамін C';

  @override
  String get vitaminD => 'Вітамін D';

  @override
  String get vitaminB12 => 'Вітамін B12';

  @override
  String get microsTitle => 'Вітаміни й мінерали';

  @override
  String microsCoverage(int known, int meals) {
    return 'З $known з $meals страв із відомими значеннями; референтні норми ЄС';
  }

  @override
  String get productsTitle => 'Упаковані товари';

  @override
  String get productsNone =>
      'Вбудовано: товари з 2019 року, мало європейських. Завантажте всі товари Open Food Facts (усі країни), щоб знаходити те, що ви купуєте. Краще через Wi-Fi.';

  @override
  String productsHave(String count, String date) {
    return '$count товарів з Open Food Facts, оновлено $date.';
  }

  @override
  String productsDownload(int mb) {
    return 'Завантажити ($mb МБ)';
  }

  @override
  String get productsRemove => 'Видалити';

  @override
  String get productsHint =>
      'Не знаходите упакований товар? Завантажте всі товари у вкладці «Я».';

  @override
  String get healthConnect => 'Health Connect';

  @override
  String get appleHealth => 'Apple Health';

  @override
  String get healthSyncHint =>
      'Читати вагу (для ваших цілей) і кроки. Туди нічого не записується, і ніщо не залишає телефон.';

  @override
  String get healthSyncDenied =>
      'Немає доступу. Дозвольте вагу й кроки в налаштуваннях застосунку здоров’я та спробуйте ще раз.';

  @override
  String stepsToday(String steps) {
    return '$steps кроків сьогодні';
  }

  @override
  String get mealPlan => 'План харчування';

  @override
  String get planTab => 'План';

  @override
  String get planEmpty =>
      'Сплануйте тиждень: сніданок, обід і вечеря з бази рецептів, під вашу ціль калорій, без ваших алергенів і спершу з рецептами, які ви високо оцінили.';

  @override
  String get planWeek => 'Спланувати тиждень';

  @override
  String get planAgain => 'Спланувати знову';

  @override
  String get planSwap => 'Інший рецепт';

  @override
  String get planCardEmpty => 'Сплануйте тиждень і отримайте список покупок';

  @override
  String get makeShoppingList => 'Список покупок';

  @override
  String get shoppingList => 'Покупки';

  @override
  String get shoppingAdd => 'Додати позицію';

  @override
  String get shoppingEmpty =>
      'Нічого купувати. Складіть список із плану або додайте інгредієнти з рецепта.';

  @override
  String get clearTicked => 'Прибрати відмічене';

  @override
  String get addToShopping => 'До списку покупок';

  @override
  String get addedToShopping => 'Додано до списку покупок';

  @override
  String waterLine(int ml, int goal) {
    return 'Вода $ml / $goal мл';
  }

  @override
  String get waterAddGlass => 'Додати склянку (250 мл)';

  @override
  String get waterUndo => 'Скасувати останню склянку';

  @override
  String get waterGoal => 'Денна норма води';

  @override
  String get fasting => 'Голодування';

  @override
  String fastingLine(int h, int m, int target) {
    return 'Голодування $h год $m хв із $target год';
  }

  @override
  String get fastStart => 'Почати зараз';

  @override
  String fastSinceMeal(String time) {
    return 'Від останньої їжі ($time)';
  }

  @override
  String get fastEnd => 'Завершити';

  @override
  String get fastDone => 'Мету досягнуто. Завершіть, коли поїсте.';

  @override
  String get fastingSwitch => 'Таймер голодування';

  @override
  String get fastingCaution =>
      'Не рекомендовано під час вагітності, при розладах харчової поведінки або при діабеті, що лікується інсуліном чи сульфонілсечовиною. Спершу порадьтеся з лікарем.';

  @override
  String get widgetKcalTitle => 'Калорії на віджеті головного екрана';

  @override
  String get widgetKcalHint =>
      'Додайте віджет MyFoodMind на головний екран. Тоді калорії за сьогодні буде видно там без PIN-коду.';

  @override
  String get welcomeTitle => 'Запишіть першу страву';

  @override
  String get welcomeBody =>
      'Напишіть або скажіть у чаті («Я з’їв 2 яйця й тост»), знайдіть у «Записі» або сфотографуйте. Тут з’явиться ваш день.';

  @override
  String nextMealTitle(String meal) {
    return 'Ще не записано: $meal';
  }

  @override
  String get nextMealBody =>
      'Запишіть, що ви з’їли, або отримайте ідею, що поїсти.';

  @override
  String get getIdea => 'Отримати ідею';

  @override
  String get logIt => 'Записати';

  @override
  String get language => 'Мова';

  @override
  String get themeSystem => 'Системна';

  @override
  String get themeLight => 'Світла';

  @override
  String get themeDark => 'Темна';

  @override
  String get wallpaperColors => 'Кольори шпалер';

  @override
  String get wallpaperColorsHint =>
      'Використовувати кольори телефона (Android 12 і новіші).';

  @override
  String suggestAte(String food) {
    return 'Я з’їв $food';
  }

  @override
  String suggestIdea(String meal) {
    return 'Щось нове на $meal';
  }

  @override
  String get suggestLeft => 'Скільки залишилось на сьогодні?';

  @override
  String rateStars(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Оцінити на $count зірки',
      many: 'Оцінити на $count зірок',
      few: 'Оцінити на $count зірки',
      one: 'Оцінити на $count зірку',
    );
    return '$_temp0';
  }

  @override
  String get recipesYouAte => 'Рецепти, які ви їли';

  @override
  String get recipesYouAteHint =>
      'Натисніть, щоб переглянути й оцінити. Ідеї рецептів ураховують ваші оцінки.';

  @override
  String get cookNone => 'Жоден рецепт у базі не використовує ці продукти.';

  @override
  String get per100Suffix => ' / 100 г';

  @override
  String get aiDownloadTitle => 'Завантажте ШІ-асистента';

  @override
  String aiDownloadBody(String gb) {
    return 'Чат-асистент працює повністю на вашому телефоні. Його модель ($gb ГБ) завантажується один раз із Hugging Face; використовуйте Wi-Fi. Нічого про вас не надсилається. Записи, рецепти й статистика вже працюють без неї.';
  }

  @override
  String get aiDownloadButton => 'Завантажити';

  @override
  String get aiModelTitle => 'Модель ШІ';

  @override
  String aiModelStandard(String gb) {
    return 'Стандартна · $gb ГБ';
  }

  @override
  String get aiModelStandardHint =>
      'Швидші відповіді. Працює на всіх підтримуваних телефонах.';

  @override
  String aiModelLarge(String gb) {
    return 'Більша · $gb ГБ';
  }

  @override
  String get aiModelLargeHint =>
      'Розуміє більше, відповідає приблизно у 2–3 рази повільніше. Для телефонів із 12 ГБ RAM.';

  @override
  String get aiModelSwitch => 'Змінити';

  @override
  String get aiModelSwitchBody =>
      'Спершу завантажиться інша модель; поточна видалиться, коли завантаження завершиться.';

  @override
  String get aiModelInUse => 'Використовується';

  @override
  String get aiDownloading => 'Завантаження';

  @override
  String get aiDownloadFailed =>
      'Завантаження зупинилося. Перевірте з’єднання й вільне місце та спробуйте знову; воно продовжиться з того ж місця.';

  @override
  String get downloadNoWifiTitle => 'Немає Wi-Fi';

  @override
  String downloadNoWifiBody(int mb) {
    return 'Ви не підключені до Wi-Fi. Це завантаження — $mb МБ; через мобільний інтернет воно може вичерпати ваш пакет даних або коштувати грошей.';
  }

  @override
  String get downloadWaitWifi => 'Чекати на Wi-Fi';

  @override
  String get downloadUseMobile => 'Мобільний інтернет';

  @override
  String get downloadOnMobile =>
      'Мобільний інтернет дозволено: це завантаження може витрачати ваш пакет даних.';

  @override
  String get downloadWaitingWifi => 'Очікування Wi-Fi';

  @override
  String get downloadWaitingNetwork => 'Очікування з’єднання';

  @override
  String get downloadRetrying =>
      'З’єднання втрачено; продовжиться, щойно воно повернеться';

  @override
  String get downloadPaused => 'Призупинено';

  @override
  String get downloadInstalling => 'Встановлення…';

  @override
  String get downloadPause => 'Пауза';

  @override
  String get downloadResume => 'Продовжити';

  @override
  String get privacyPolicy => 'Політика конфіденційності';

  @override
  String get termsOfUse => 'Умови використання';

  @override
  String get licenses => 'Ліцензії та моделі ШІ';

  @override
  String get settingsTitle => 'Налаштування';

  @override
  String get drawerFood => 'Їжа';

  @override
  String get drawerAssistant => 'Асистент';

  @override
  String get shoppingListNav => 'Список покупок';

  @override
  String get healthJournalNav => 'Щоденник здоров’я і звіт';

  @override
  String get settingsAi => 'ШІ та дані';

  @override
  String get settingsTracking => 'Відстеження';

  @override
  String get settingsPrivacy => 'Приватність і безпека';

  @override
  String get settingsAbout => 'Про застосунок';

  @override
  String get settingsDanger => 'Небезпечна зона';

  @override
  String get deleteThisProfile => 'Видалити цей профіль';

  @override
  String get deleteThisProfileBody =>
      'Профіль і всі його страви, щоденник та історію чату буде видалено з цього телефона. Це не можна скасувати.';

  @override
  String get featBasic2 => 'План харчування і список покупок';

  @override
  String get featBasic4 => 'Історія за 3 місяці';

  @override
  String get featMedium4 => 'Історія за 8 місяців';

  @override
  String get featPro4 => 'Річна статистика та історія за 12 місяців';

  @override
  String get periodYear => 'Рік';

  @override
  String get yearLockedTitle => 'Річний огляд доступний у Pro';

  @override
  String get yearLockedBody =>
      'Дванадцять місяців одним поглядом: калорії за місяць, календар записів, середні значення поживних речовин із найкращим і найгіршим місяцем, вага та що ви їли найчастіше.';

  @override
  String get yearCalories => 'Калорії на день, середнє за місяць';

  @override
  String get yearCalendar => 'Календар записів';

  @override
  String yearLoggedDays(int days, int best) {
    return 'Днів із записами: $days · найдовша серія: $best дн.';
  }

  @override
  String get yearNutrients => 'Середнє на день за рік';

  @override
  String yearBestWorst(String nutrient, String best, String worst) {
    return '$nutrient: найкращий місяць — $best, найгірший — $worst';
  }

  @override
  String get yearTopFoods => 'Найчастіше';

  @override
  String get calendarOnGoal => 'У межах 10% від цілі';

  @override
  String get calendarNear => 'У межах 25%';

  @override
  String get calendarFar => 'Далі від цілі';

  @override
  String get calendarNotLogged => 'Без записів';

  @override
  String get historyTitle => 'Історія';

  @override
  String lastDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Останні $count днів',
      few: 'Останні $count дні',
      one: 'Останній $count день',
    );
    return '$_temp0';
  }

  @override
  String get pickDates => 'Вибрати дати';

  @override
  String get recipesOnly => 'Лише рецепти';

  @override
  String get historyEmpty => 'За ці дні нічого не записано.';

  @override
  String historyLockedTitle(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Історія показує останні $days днів',
      few: 'Історія показує останні $days дні',
      one: 'Історія показує останній $days день',
    );
    return '$_temp0';
  }

  @override
  String get historyLockedBody =>
      'Старіші записи залишаються на телефоні. Basic показує 3 місяці, Medium — 8, Pro — 12.';

  @override
  String get planLockedTitle => 'План харчування доступний у Basic';

  @override
  String get planLockedBody =>
      'Плануйте тиждень із рецептів, що підходять вашим цілям і алергенам, і перетворюйте план на список покупок.';

  @override
  String get reminderWater => 'Пити воду';

  @override
  String reminderWaterHint(int count, String from, String to) {
    return '$count на день, $from–$to: по склянці, щоб досягти цілі з води';
  }

  @override
  String get reminderWaterLocked => 'Нагадування пити воду доступні в Basic';

  @override
  String notifWater(String name) {
    return '$name, час випити склянку води.';
  }

  @override
  String get machineTranslated => 'Назви інгредієнтів перекладено автоматично';

  @override
  String get translateSteps => 'Перекласти кроки';

  @override
  String get machineTranslatedSteps =>
      'Кроки перекладено автоматично на телефоні';

  @override
  String get showOriginal => 'Показати оригінал';

  @override
  String get showTranslation => 'Показати переклад';

  @override
  String get translateBusy => 'Асистент зайнятий. Спробуйте за мить.';

  @override
  String get translateFailed =>
      'Не вдалося перекласти кроки. Спробуйте ще раз.';

  @override
  String get translateNeedsAi =>
      'Для перекладу потрібна модель ШІ (див. вкладку «Чат»).';
}
