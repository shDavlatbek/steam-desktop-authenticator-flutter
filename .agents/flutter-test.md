---
name: flutter-test
description: Run all tests for the SDA Flutter application
---

# Flutter Test Runner

Run all unit tests, crypto compatibility tests, and integration tests.

## Steps
1. `cd SDA-flutter`
2. Run `flutter pub get`
3. Run `dart run build_runner build --delete-conflicting-outputs` to ensure generated files are current
4. Run `flutter test` to execute all unit tests
5. Report results: number passed, failed, and any error details
6. If crypto tests fail, highlight the specific test vectors that don't match
