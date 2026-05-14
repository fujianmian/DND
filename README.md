# dnd_auto_app

A new Flutter project.

## Calendar Google Sign-In setup

Google Calendar sign-in on Android needs two OAuth clients in Google Cloud:

- Create an Android OAuth client using this app's `applicationId` and the
  signing certificate SHA-1.
- Create a Web application OAuth client and use that Web client ID as
  `GOOGLE_SERVER_CLIENT_ID`. Do not use the Android OAuth client ID for this
  value.

Pass the Web client ID at run/build time:

```sh
flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=xxx.apps.googleusercontent.com
flutter build apk --debug --dart-define=GOOGLE_SERVER_CLIENT_ID=xxx.apps.googleusercontent.com
```

For local development, `.env` may also define `GOOGLE_SERVER_CLIENT_ID`, but
`--dart-define` takes precedence and avoids committing real client IDs.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
