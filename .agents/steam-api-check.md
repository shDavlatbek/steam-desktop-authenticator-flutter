---
name: steam-api-check
description: Verify Steam API compatibility with integration tests
---

# Steam API Compatibility Check

Run integration tests that verify Steam API endpoints work correctly.

## Steps
1. `cd SDA-flutter`
2. Run `flutter pub get`
3. Run `flutter test integration_test/` to run integration tests
4. These tests hit real Steam endpoints (time query - no auth required)
5. Report any API compatibility issues or endpoint changes
