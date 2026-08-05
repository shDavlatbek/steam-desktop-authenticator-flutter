import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/repositories/account_repository.dart';
import 'core/repositories/confirmation_repository.dart';
import 'core/repositories/manifest_repository.dart';
import 'core/services/steam_auth_service.dart';
import 'core/services/steam_phone_service.dart';
import 'core/services/steam_time_service.dart';
import 'core/services/steam_user_service.dart';
import 'core/services/steam_web_service.dart';
import 'shared/theme/theme_notifier.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Create services
  final webService = SteamWebService();
  final timeService = SteamTimeService();
  final authService = SteamAuthService(webService);

  // Create repositories
  final manifestRepo = ManifestRepository();
  final accountRepo = AccountRepository(
    web: webService,
    timeService: timeService,
    authService: authService,
  );
  final confirmationRepo = ConfirmationRepository(
    web: webService,
    timeService: timeService,
  );

  runApp(
    MultiProvider(
      providers: [
        Provider<SteamWebService>.value(value: webService),
        Provider<SteamTimeService>.value(value: timeService),
        Provider<SteamAuthService>.value(value: authService),
        Provider<SteamPhoneService>.value(value: SteamPhoneService()),
        Provider<SteamUserService>.value(value: SteamUserService()),
        Provider<ManifestRepository>.value(value: manifestRepo),
        Provider<AccountRepository>.value(value: accountRepo),
        Provider<ConfirmationRepository>.value(value: confirmationRepo),
        ChangeNotifierProvider(create: (_) => ThemeNotifier(isDark: true)),
      ],
      child: const SdaApp(),
    ),
  );
}
