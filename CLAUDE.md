# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A Flutter (Windows + Android) port of [Steam Desktop Authenticator](https://github.com/Jessecar96/SteamDesktopAuthenticator). It is a real authenticator: it generates Steam Guard TOTP codes, manages trade/market confirmations, links new authenticators, and reads/writes encrypted `.maFile` storage.

The **original C# source is vendored in-repo at `SteamDesktopAuthenticator/`** (read-only reference — never edit it). Cross-reference it whenever touching crypto, API calls, or file formats. Key files:

| What | C# source |
|---|---|
| TOTP + confirmation hash | `SteamDesktopAuthenticator/lib/SteamAuth/SteamGuardAccount.cs` |
| Session / cookies / JWT | `SteamDesktopAuthenticator/lib/SteamAuth/SessionData.cs` |
| Authenticator linking | `SteamDesktopAuthenticator/lib/SteamAuth/AuthenticatorLinker.cs` |
| File encryption | `SteamDesktopAuthenticator/Steam Desktop Authenticator/FileEncryptor.cs` |
| Manifest I/O | `SteamDesktopAuthenticator/Steam Desktop Authenticator/Manifest.cs` |

## Commands

The Flutter project is at the repo root (`pubspec.yaml` is here — there is no `SDA-flutter/` subdirectory).

```bash
flutter pub get
flutter analyze                    # must stay at 0 issues
flutter test                       # 33 tests, all passing
flutter test test/core/crypto/     # crypto suite only — run after ANY crypto change
flutter test test/core/crypto/steam_totp_test.dart --plain-name "generates"   # single test
dart fix --apply                   # auto-fix lints

flutter run -d windows
flutter run -d <android_device_id>
flutter build windows --release
flutter build apk --release        # → build/app/outputs/flutter-apk/app-release.apk
```

**Do not run `build_runner`.** `json_annotation` is listed in `pubspec.yaml` but unused — there are zero `.g.dart` files and every model hand-writes `fromJson`/`toJson`. The `.agents/*.md` files still instruct otherwise; they are stale (they also reference a nonexistent `SDA-flutter/` directory and a nonexistent `integration_test/` suite).

## Architecture

MVVM with `provider`. Strict layering, dependencies point downward only:

```
models → services → repositories → view_models → views
```

- **`lib/main.dart`** — constructs every service/repository once and registers them in a `MultiProvider`. Services and repositories are plain `Provider.value` (no `ChangeNotifier`); only `ThemeNotifier` and per-feature ViewModels notify.
- **`lib/app.dart`** — `AppShell` is the entry gate: loads the manifest, applies `debugMode`/`darkMode` from it, then renders either `WelcomePage` (first run, no accounts) or `HomePage` wrapped in a `ChangeNotifierProvider<HomeViewModel>`.
- **`core/services/`** — thin, mostly static wrappers over single Steam API calls. Stateless except `SteamTimeService` (singleton) and `DebugLogger` (singleton).
- **`core/repositories/`** — orchestration and all business logic. `ManifestRepository` owns *all* file I/O and encryption; `AccountRepository` owns TOTP/login/token refresh; `ConfirmationRepository` owns confirmation fetch/accept/deny.
- **`features/<name>/{view_models,views}/`** — ViewModels extend `ChangeNotifier`; views are widgets only.

There is no route table. Navigation is imperative `Navigator.push(MaterialPageRoute(...))`, dispatched from the `switch` in `home_page.dart` (`_handleMenuAction`). Pages that need a ViewModel are wrapped in `ChangeNotifierProvider` at the push site, and callers commonly chain `.then((_) => vm.loadAccounts())` to refresh on return.

### The two QR flows

They are easy to confuse and share only `QrChallenge` and the endpoint constants:

- **QR login** (`qr_login_page.dart` / `qr_login_view_model.dart`) — this app *shows* a QR, the official Steam app scans it, and tokens arrive via polling. Reached from the "Sign in with QR code" button on `LoginPage`, so both Add Account and Login Again get it for free. `QrLoginPage` pops a `SessionData`, the same contract as `LoginPage`.
- **QR approval** (`qr_approval_page.dart` / `qr_approval_view_model.dart` / `login_approval_repository.dart`) — this app *scans* a QR shown elsewhere and approves it by signing with the account's `shared_secret`, which is what the official Steam app does. Reached from the QR button in the app bar, left of the account menu — both are gated on `vm.currentAccount != null`. It accepts a code three ways — camera, a picked image, or a pasted URL — which all funnel into `QrApprovalViewModel._lookUp`. The `_acceptsNewCode` guard there matters: a camera reports the same code many times per second, so without it every frame would fire a lookup.

Imports inside `lib/` are mostly relative; a handful of files use `package:sda_flutter/...`. Either works — match the surrounding file.

## Invariants that will silently break the app if violated

**Crypto must stay byte-identical to the C#.** `steam_totp.dart`, `confirmation_hash.dart`, and `file_encryptor.dart` produce output consumed by Steam and by the original SDA. A one-byte difference yields codes that look valid but are rejected. Never "clean up" these files; always diff against the C# and run `flutter test test/core/crypto/`.

**`mobile_confirmation_signature.dart` has no C# counterpart** — it belongs to Steam's QR login flow — but the same rule applies. Its message is exactly 18 little-endian bytes (`version` u16, `client_id` u64, `steamid` u64) HMAC-SHA256'd with the base64-decoded `shared_secret`. Wrong byte order or field widths produce a well-formed signature that Steam silently rejects. The reference implementations are `LoginApprover.ts` in DoctorMcKay/node-steam-session and `approver.rs` in dyc3/steamguard-cli.

**maFile JSON keys must match C# exactly.** Users import `.maFile` files written by the C# app and export back to it. Keys are snake_case in `SteamGuardAccount` but PascalCase inside the nested `Session` object (`SteamID`, `AccessToken`, `RefreshToken`, `SessionID`). Adding a field means adding it to both `fromJson` and `toJson` by hand.

**All timestamps come from `SteamTimeService.getSteamTime()`, never the local clock.** TOTP codes and confirmation hashes are signed against Steam-aligned time; the service self-aligns on first use and caches the offset.

**Confirmation `id`, `nonce`, and `creator_id` are `String`, not `int`.** Steam returns uint64 values that overflow Dart's int on web and were the cause of a past `type 'String' is not a subtype of type 'int?'` crash.

**Refresh the session before every confirmation call.** `ConfirmationRepository._ensureValidSession()` checks the JWT `exp` claim and refreshes the access token, throwing `NeedsAuthenticationException` when the refresh token itself is dead. Skipping it produces `{"success":false,"needauth":true}`. Any new confirmation-adjacent operation must call it first.

**`multiajaxop` needs `SteamWebService.postRawBody`.** Bulk accept/deny sends repeated `cid[]`/`ck[]` keys, which a `Map<String,String>` body cannot express.

**After re-login, write the new tokens to disk.** `saveAccount` must be called or "Login Again" appears to work and then fails on next launch.

## Storage model

Accounts live in `{getApplicationSupportDirectory()}/maFiles/`, with `manifest.json` as the index and one `{steamid}.maFile` per account. `ManifestRepository` caches the parsed manifest — pass `getManifest(forceLoad: true)` after external changes. On load it prunes entries whose file is missing and clears the `encrypted` flag when no entries remain.

Encryption is AES-256-CBC with PBKDF2 (SHA1, 50 000 iterations); per-entry salt and IV are stored in `manifest.json`, ciphertext as Base64 in the `.maFile`. The passkey is held in memory on `HomeViewModel.passKey` and threaded into `getAllAccounts(passKey:)` — it is never persisted.

App settings (`debug_mode`, `dark_mode`, periodic checking, auto-confirm) are fields on `manifest.json`, not `SharedPreferences`.

## Platform notes

- **Android file picking** must use `FileType.any` with multi-select. `FileType.custom` with a `.maFile` extension crashes, and SAF directory picking returns content URIs that `dart:io` cannot traverse — so there is no directory-based import on Android.
- Android Gradle heap is pinned to 4G in `android/gradle.properties`; raising it reintroduces an OOM crash.
- **`mobile_scanner` has no Windows or Linux implementation.** `QrApprovalPage` guards on `Platform.isAndroid || isIOS || isMacOS` and never constructs a `MobileScannerController` elsewhere; desktop falls back to choosing an image or pasting the `s.team` URL. Importing the package on Windows is safe — the Windows build is verified working — but *calling* it there throws. `qr_flutter` (rendering) has no such limit and works everywhere.
- **`qr_image_decoder.dart` deliberately does not use `MobileScannerController.analyzeImage`**, even though that exists, because it inherits the same Windows gap. It uses `image` + `zxing2` (pure Dart) so choosing a screenshot works identically on desktop and mobile, and runs the decode through `compute()` since a 12MP photo would otherwise block the UI thread.
- `mobile_scanner` applies the Kotlin Gradle Plugin, which current Flutter warns about and future versions will reject. `android.builtInKotlin=false` / `android.newDsl=false` in `gradle.properties` were added automatically to keep the build working.

## Debugging

`DebugLogger` is a singleton enabled from `manifest.debugMode` at startup. `SteamWebService` logs every request URL, status, and (truncated) response body; `ConfirmationRepository` logs account state and built URLs. View it in-app: Settings → toggle Debug mode, then the debug log page (color-coded, copy-all, clear).

## Further reading

`DOCS.md` holds the full C#-class → Dart-file mapping, the complete Steam API endpoint table, the `manifest.json` / `.maFile` schemas, and the known-limitations list (system tray, periodic checking, auto-confirm, trade popup, update checker are all unimplemented). Its shell snippets and `../SteamDesktopAuthenticator/` paths predate the repo flattening — read paths there as relative to the repo root.
