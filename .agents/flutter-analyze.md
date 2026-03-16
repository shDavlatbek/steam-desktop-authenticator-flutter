---
name: flutter-analyze
description: Analyze SDA Flutter code for issues and auto-fix
---

# Flutter Analyzer

Run static analysis and auto-fix lint issues.

## Steps
1. `cd SDA-flutter`
2. Run `flutter pub get`
3. Run `dart run build_runner build --delete-conflicting-outputs`
4. Run `flutter analyze` to check for issues
5. If issues found, run `dart fix --apply` to auto-fix
6. Run `flutter analyze` again to verify fixes
7. Report any remaining issues that need manual attention
