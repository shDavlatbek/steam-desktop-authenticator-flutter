import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/models/confirmation.dart';
import '../../../shared/theme/colors.dart';

/// A single confirmation card displaying the icon, headline, summary,
/// and accept/deny action buttons.
class ConfirmationCard extends StatelessWidget {
  final Confirmation confirmation;
  final bool isProcessing;
  final VoidCallback onAccept;
  final VoidCallback onDeny;

  const ConfirmationCard({
    super.key,
    required this.confirmation,
    required this.isProcessing,
    required this.onAccept,
    required this.onDeny,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row: icon + headline ──────────────────────────
            Row(
              children: [
                _buildIcon(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        confirmation.headline ?? 'Confirmation',
                        style: const TextStyle(
                          color: SteamColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Creator ID: ${confirmation.creator}',
                        style: const TextStyle(
                          color: SteamColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // ── Summary lines ────────────────────────────────────────
            if (confirmation.summary != null &&
                confirmation.summary!.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              for (final line in confirmation.summary!)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    line,
                    style: const TextStyle(
                      color: SteamColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
            ],

            const SizedBox(height: 16),

            // ── Action buttons ───────────────────────────────────────
            if (isProcessing)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onAccept,
                      icon: const Icon(Icons.check, size: 18),
                      label: Text(confirmation.accept ?? 'Accept'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SteamColors.steamGreen,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onDeny,
                      icon: const Icon(Icons.close, size: 18),
                      label: Text(confirmation.cancel ?? 'Deny'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SteamColors.error,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon() {
    if (confirmation.icon != null && confirmation.icon!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: confirmation.icon!,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          placeholder: (_, _) => Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: SteamColors.surfaceColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.image, color: SteamColors.textSecondary),
          ),
          errorWidget: (_, _, _) => _fallbackIcon(),
        ),
      );
    }
    return _fallbackIcon();
  }

  Widget _fallbackIcon() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: SteamColors.surfaceColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        _iconForType(confirmation.confirmationType),
        color: SteamColors.steamBlue,
      ),
    );
  }

  IconData _iconForType(EMobileConfirmationType type) {
    switch (type) {
      case EMobileConfirmationType.trade:
        return Icons.swap_horiz;
      case EMobileConfirmationType.marketListing:
        return Icons.storefront;
      case EMobileConfirmationType.phoneNumberChange:
        return Icons.phone;
      case EMobileConfirmationType.accountRecovery:
        return Icons.lock_reset;
      default:
        return Icons.verified_user;
    }
  }
}
