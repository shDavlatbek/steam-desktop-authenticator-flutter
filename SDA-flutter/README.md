# Steam Desktop Authenticator - Flutter

A cross-platform (Windows, Android) port of [Steam Desktop Authenticator](https://github.com/Jessecar96/SteamDesktopAuthenticator) built with Flutter. Real, working application — generates TOTP codes, manages trade/market confirmations, links authenticators, imports/exports maFiles, with full encryption support.

## Features

- **Steam Guard TOTP** — Generate 5-character codes identical to the Steam mobile app
- **Trade Confirmations** — View, accept, deny (single or bulk) trade and market confirmations
- **Add Authenticator** — Link Steam Guard to accounts directly (no phone number required)
- **Import / Export** — Import .maFile files or export accounts with manifest.json
- **Encryption** — AES-256-CBC file encryption compatible with the original C# SDA
- **Auto Token Refresh** — Expired access tokens are refreshed automatically before API calls
- **Dark / Light Theme** — Switchable theme with Steam-inspired design
- **Debug Mode** — Built-in HTTP request/response logger for troubleshooting
- **Android Support** — Full Android compatibility with SAF-aware file picking

## Screenshots

The app adapts between wide (side-by-side) and narrow (stacked) layouts automatically.

## Quick Start

```bash
# Install dependencies
cd SDA-flutter
flutter pub get

# Run on Windows
flutter run -d windows

# Run on Android
flutter run -d <device_id>

# Build release APK
flutter build apk --release

# Run tests
flutter test

# Analyze
flutter analyze
```

## Importing Existing Accounts

If you already have `.maFile` files from the original SDA:

1. Open the app
2. Menu > **Import Account**
3. Select your `.maFile` file(s)
4. If encrypted, enter the encryption key first

On Android, use **Select Files** (multi-pick) since directory browsing isn't supported.

## Adding a New Account

1. Menu > **Add Account**
2. Enter Steam username and password
3. Submit the email/Steam Guard code
4. Choose **Yes, Add Authenticator** when prompted
5. **Save the revocation code** — you need it to remove the authenticator
6. Enter the activation code sent to your email
7. Done — the account now generates TOTP codes

## Project Structure

```
lib/
├── core/           # Data layer (models, services, repositories, crypto)
├── features/       # UI modules (home, auth, confirmations, settings, etc.)
└── shared/         # Theme and reusable widgets
```

See [DOCS.md](DOCS.md) for the full architecture documentation and C#-to-Flutter mapping.

## Building

### Windows
```bash
flutter build windows --release
```

### Android
```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

## License

Open source. Based on [SteamDesktopAuthenticator](https://github.com/Jessecar96/SteamDesktopAuthenticator) by Jessecar96.
