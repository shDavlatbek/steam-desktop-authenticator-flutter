---
name: sda-flutter-dev
description: Development guide for working on the SDA Flutter project - architecture, patterns, and conventions
---

# SDA Flutter Development Guide

## Project Context
SDA-Flutter is a complete port of SteamDesktopAuthenticator (C# WinForms) to Flutter. It generates real Steam Guard TOTP codes, manages trade confirmations, links authenticators, and handles encrypted maFile storage.

## Architecture
- **Pattern**: MVVM with Provider (ChangeNotifier)
- **Layers**: Models → Services → Repositories → ViewModels → Views
- **Theme**: Material 3 dark theme (SteamColors in shared/theme/colors.dart)

## Key Conventions

### Navigation
All navigation is wired in `home_page.dart` — no remaining TODOs. Pattern used:
```dart
Navigator.push(context, MaterialPageRoute(builder: (_) => TargetPage()))
  .then((_) => vm.loadAccounts()); // reload on return where needed
```
For screens needing a ViewModel, wrap with `ChangeNotifierProvider`.

### JSON Serialization
Models use manual `fromJson`/`toJson` (no code generation). JSON keys must exactly match the C# originals for maFile compatibility.

### Crypto Code
Never modify crypto files without cross-referencing the C# source. A single byte difference breaks TOTP codes. Always run `flutter test test/core/crypto/` after crypto changes.

### State Management
- ViewModels extend `ChangeNotifier`
- Services are stateless (except `SteamTimeService` singleton)
- Repositories hold no UI state, only data orchestration
- Register new providers in `main.dart`

## Critical Files
- `lib/core/crypto/steam_totp.dart` — TOTP algorithm (MUST match C#)
- `lib/core/crypto/file_encryptor.dart` — AES encryption (MUST match C#)
- `lib/core/models/session_data.dart` — JWT parsing + cookie generation
- `lib/core/repositories/manifest_repository.dart` — All file I/O
- `lib/features/home/view_models/home_view_model.dart` — Main app state

## What's Done
- 47 source files, 33 passing tests, 0 analysis issues
- All C# crypto ported (TOTP, confirmation hash, AES-256-CBC)
- All Steam API services (login, 2FA, phone, confirmations, tokens)
- All UI screens (home, login, confirmations, settings, encryption, import, welcome)
- All 7 navigation actions wired up (no remaining TODOs in source code)

## What Needs Work
1. **System tray** integration (tray_manager + window_manager)
2. **Periodic confirmation checking** background timer
3. **Auto-confirm logic** for trades/market
4. **Trade popup overlay** notifications
5. **Cross-platform testing** (macOS, Linux, Android, iOS)

## Commands
```bash
cd SDA-flutter
flutter pub get          # Install deps
flutter test             # Run tests
flutter analyze          # Check for issues
flutter run -d windows   # Run app
```

## Reference Documentation
Full project documentation is in `SDA-flutter/DOCS.md`
