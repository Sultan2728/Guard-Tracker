# Трекер охраны (Flutter)

Приложение для трёх охранников (посменно) и начальника: охранник включает
слежение на смене, приложение следит за GPS, сравнивает его с зоной
объекта и сообщает начальнику, когда охранник входит в зону / выходит
из неё. Журнал событий с датой и временем виден начальнику.

## Что нужно установить на компьютере

1. **Flutter SDK** — https://docs.flutter.dev/get-started/install
   Проверить: `flutter doctor` (должно быть всё зелёное для Android
   как минимум).
2. **Android Studio** (для сборки Android-версии) или **Xcode** на Mac
   (для iOS).
3. **Node.js** (для Firebase CLI) — https://nodejs.org

## Шаг 1. Распакуйте проект

Распакуйте архив в любую папку, откройте её в терминале.

```bash
flutter pub get
```

## Шаг 2. Настройка Firebase (обязательно)

Приложению нужен Firebase-проект — это бесплатно на нужном вам объёме
(Spark-план хватит для Firestore-хранилища; для push-уведомлений через
Cloud Functions понадобится Blaze-план, но расход там копеечный при
таком малом трафике).

1. Зайдите на https://console.firebase.google.com, создайте новый проект
   (например «guard-tracker»).
2. Включите **Firestore Database** (вкладка Build → Firestore Database →
   Create database, режим "Production").
3. Установите инструменты:
   ```bash
   npm install -g firebase-tools
   dart pub global activate flutterfire_cli
   firebase login
   ```
4. В папке проекта выполните:
   ```bash
   flutterfire configure
   ```
   Выберите ваш Firebase-проект, отметьте платформы Android и/или iOS.
   Команда сама создаст правильный `lib/firebase_options.dart`
   (замените им файл-заглушку) и нужные конфиг-файлы
   (`google-services.json` для Android, `GoogleService-Info.plist`
   для iOS).

## Шаг 3. Правила доступа Firestore

В консоли Firebase → Firestore Database → Rules вставьте (простой вариант,
без авторизации — приложение и так работает только по прямой ссылке/APK,
которую вы распространяете сами; если нужна защита понадёжнее, скажите,
добавлю Firebase Auth):

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if true;
    }
  }
}
```

## Шаг 4. Права на геолокацию (Android)

Откройте `android/app/src/main/AndroidManifest.xml` и добавьте строки
из файла `android_setup/AndroidManifest_additions.xml` (просто
скопируйте разрешения внутрь тега `<manifest>`).

Также в `android/app/build.gradle` убедитесь, что:
```
minSdkVersion 21  (или выше)
compileSdkVersion 34 (или выше)
```

## Шаг 5. Права на геолокацию (iOS, если нужен)

В `ios/Runner/Info.plist` добавьте:
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Приложению нужен доступ к геолокации, чтобы отмечать вход и выход из зоны объекта</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>Приложению нужен постоянный доступ к геолокации, чтобы отслеживать зону объекта во время смены</string>
<key>UIBackgroundModes</key>
<array>
  <string>location</string>
</array>
```

## Шаг 6. Запуск для проверки

Подключите Android-телефон по USB (включите «Отладку по USB» в настройках
разработчика) или запустите эмулятор, затем:

```bash
flutter run
```

## Шаг 7. Сборка установочного файла

**Android (APK для ручной установки на телефоны охранников):**
```bash
flutter build apk --release
```
Файл появится в `build/app/outputs/flutter-apk/app-release.apk` —
перекиньте его на телефон охранника (через кабель, Telegram, облако)
и установите вручную (потребуется разрешить «Установка из неизвестных
источников» в настройках телефона).

**iOS:**
```bash
flutter build ipa
```
Для реальной установки на iPhone (не через TestFlight/App Store)
потребуется Apple Developer аккаунт ($99/год) и профиль подписи —
это ограничение самой Apple, не Flutter.

## Шаг 8 (опционально). Push-уведомления начальнику

Без этого шага приложение уже работает: начальник видит статусы в
реальном времени, пока панель открыта. Чтобы получать именно
push-уведомление (как в мессенджере), даже когда приложение свёрнуто:

```bash
cd functions
npm install
cd ..
firebase deploy --only functions
```

Это требует Blaze-плана Firebase (привязка карты, но при таком
объёме вызовов — единицы в день — вы останетесь в бесплатных лимитах).

В приложении также нужно получить и сохранить FCM-токен телефона
начальника при первом входе — это уже частично подготовлено в
`FirestoreService.saveFcmToken()`, но вызов из экрана `BossScreen`
и обработку разрешений на уведомления (`firebase_messaging`) нужно
добавить — напишите, если хотите, чтобы я доделал этот кусок.

## Структура проекта

```
lib/
  main.dart                    — точка входа, роутинг по сохранённой роли
  models/guard_status.dart     — модели данных (статус охранника, зона)
  services/firestore_service.dart  — вся работа с Firestore
  services/location_service.dart   — GPS, геозона, гистерезис
  screens/role_select_screen.dart  — выбор роли
  screens/guard_screen.dart        — экран охранника
  screens/boss_screen.dart         — экран начальника
functions/index.js             — Cloud Function для push-уведомлений
android_setup/                 — какие строки добавить в AndroidManifest.xml
```
