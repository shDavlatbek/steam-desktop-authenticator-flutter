import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/repositories/account_repository.dart';
import 'core/repositories/confirmation_repository.dart';
import 'core/repositories/manifest_repository.dart';
import 'core/services/debug_logger.dart';
import 'features/home/view_models/home_view_model.dart';
import 'features/home/views/home_page.dart';
import 'features/import_export/views/welcome_page.dart';
import 'shared/theme/app_theme.dart';
import 'shared/theme/theme_notifier.dart';

class SdaApp extends StatelessWidget {
  const SdaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeNotifier>(
      builder: (context, themeNotifier, _) {
        return MaterialApp(
          title: 'Steam Desktop Authenticator',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeNotifier.themeMode,
          debugShowCheckedModeBanner: false,
          home: const AppShell(),
        );
      },
    );
  }
}

/// Top-level shell that handles initialization:
/// 1. Loads manifest
/// 2. If first run with no accounts → WelcomePage
/// 3. Otherwise → HomePage with HomeViewModel
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool _isLoading = true;
  bool _isFirstRun = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final manifestRepo = context.read<ManifestRepository>();
      final manifest = await manifestRepo.getManifest();
      DebugLogger().setEnabled(manifest.debugMode);
      if (mounted) {
        context.read<ThemeNotifier>().setDark(manifest.darkMode);
      }

      setState(() {
        _isFirstRun = manifest.firstRun && manifest.entries.isEmpty;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error loading manifest:\n$_error',
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _error = null;
                  });
                  _initialize();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_isFirstRun) {
      return WelcomePage(
        onGetStarted: () {
          setState(() {
            _isFirstRun = false;
          });
        },
      );
    }

    return ChangeNotifierProvider(
      create: (ctx) => HomeViewModel(
        manifestRepo: ctx.read<ManifestRepository>(),
        accountRepo: ctx.read<AccountRepository>(),
        confirmationRepo: ctx.read<ConfirmationRepository>(),
      )..initialize(),
      child: const HomePage(),
    );
  }
}
