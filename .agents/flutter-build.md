---
name: flutter-build
description: Build and run the SDA Flutter application
---

# Flutter Build & Run

Run the SDA Flutter application for a target platform.

## Steps
1. `cd SDA-flutter`
2. Run `flutter pub get` to ensure dependencies are current
3. Run `dart run build_runner build --delete-conflicting-outputs` to generate JSON serialization code
4. Run `flutter run -d <platform>` where platform is windows (default), macos, linux, android, ios, or chrome
5. Report any build errors with full context
