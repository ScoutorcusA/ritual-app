# Ritual

Ritual is a private, mindful food photo journal built with Flutter for Android. It focuses on noticing meals and feelings rather than calories or targets.

## Included

- Camera-first meal capture for breakfast, lunch, dinner, and snacks
- App-private photo storage (photos are not added to Android Gallery)
- Optional feelings, a short reflection, and current coordinates
- Journal timeline and filterable photo gallery
- Editable and deletable entries
- Current and best daily streaks
- Local SQLite storage with Android backup disabled
- No account, cloud service, ads, or analytics SDK

## Run locally

```sh
flutter pub get
flutter run
```

Run checks with:

```sh
flutter analyze
flutter test
flutter build apk --release
```

Uninstalling Ritual removes its database and stored photos. Location is optional and is only requested when **Add current location** is tapped.
