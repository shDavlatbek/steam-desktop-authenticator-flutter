import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/theme/colors.dart';
import '../view_models/home_view_model.dart';

/// Displays the current TOTP code for the selected Steam Guard account.
///
/// Shows a large monospace code, a circular countdown indicator, the account
/// name, and a copy-to-clipboard button. When no account is selected a
/// placeholder message is shown instead.
class TotpDisplayWidget extends StatelessWidget {
  const TotpDisplayWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<HomeViewModel>(
      builder: (context, vm, _) {
        if (vm.currentAccount == null) {
          return const _NoAccountPlaceholder();
        }

        return _TotpContent(
          accountName: vm.currentAccount!.accountName ?? 'Unknown',
          code: vm.currentCode,
          secondsRemaining: vm.secondsRemaining,
          onCopy: vm.copyCodeToClipboard,
        );
      },
    );
  }
}

class _TotpContent extends StatelessWidget {
  final String accountName;
  final String code;
  final int secondsRemaining;
  final VoidCallback onCopy;

  const _TotpContent({
    required this.accountName,
    required this.code,
    required this.secondsRemaining,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final progress = secondsRemaining / 30.0;
    final isLow = secondsRemaining <= 5;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Account name ───────────────────────────────────────────
            Text(
              accountName,
              style: const TextStyle(
                color: SteamColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),

            // ── Countdown ring + code ──────────────────────────────────
            SizedBox(
              width: 180,
              height: 180,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Background ring
                  SizedBox(
                    width: 180,
                    height: 180,
                    child: CircularProgressIndicator(
                      value: 1.0,
                      strokeWidth: 6,
                      color: SteamColors.surfaceColor,
                    ),
                  ),
                  // Animated progress ring
                  SizedBox(
                    width: 180,
                    height: 180,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: progress, end: progress),
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      builder: (context, value, _) {
                        return CircularProgressIndicator(
                          value: value,
                          strokeWidth: 6,
                          strokeCap: StrokeCap.round,
                          color: isLow
                              ? SteamColors.warning
                              : SteamColors.steamBlue,
                        );
                      },
                    ),
                  ),
                  // Code + seconds
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        code.isNotEmpty ? code : '-----',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 6,
                          color: code.isNotEmpty
                              ? SteamColors.textPrimary
                              : SteamColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${secondsRemaining}s',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isLow
                              ? SteamColors.warning
                              : SteamColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ── Copy button ────────────────────────────────────────────
            SizedBox(
              width: 200,
              child: ElevatedButton.icon(
                onPressed: code.isNotEmpty ? onCopy : null,
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Copy Code'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoAccountPlaceholder extends StatelessWidget {
  const _NoAccountPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.lock_outline,
            size: 64,
            color: SteamColors.textSecondary.withAlpha(80),
          ),
          const SizedBox(height: 16),
          const Text(
            'No account selected',
            style: TextStyle(
              color: SteamColors.textSecondary,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Select an account from the list to view its code.',
            style: TextStyle(
              color: SteamColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
