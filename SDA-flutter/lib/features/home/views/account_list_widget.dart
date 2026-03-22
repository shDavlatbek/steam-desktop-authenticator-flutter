import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/theme/colors.dart';
import '../view_models/home_view_model.dart';

/// A searchable list of Steam Guard accounts.
///
/// Displays a search field at the top (supporting regex with a `~` prefix)
/// and a scrollable list of account names below. The currently selected
/// account is visually highlighted.
class AccountListWidget extends StatefulWidget {
  const AccountListWidget({super.key});

  @override
  State<AccountListWidget> createState() => _AccountListWidgetState();
}

class _AccountListWidgetState extends State<AccountListWidget> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<HomeViewModel>(
      builder: (context, vm, _) {
        final accounts = vm.filteredAccounts;

        return Column(
          children: [
            // ── Search field ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: TextField(
                controller: _searchController,
                onChanged: vm.filterAccounts,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: 'Search accounts...',
                  prefixIcon: Icon(
                    Icons.search,
                    color: Theme.of(context).colorScheme.onSurface.withAlpha(150),
                    size: 20,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.clear,
                            color: Theme.of(context).colorScheme.onSurface.withAlpha(150),
                            size: 18,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            vm.filterAccounts('');
                          },
                        )
                      : null,
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ),

            // ── Account list ─────────────────────────────────────────────
            Expanded(
              child: accounts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.shield_outlined,
                            color: Theme.of(context).colorScheme.onSurface.withAlpha(80),
                            size: 48,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            vm.allAccounts.isEmpty
                                ? 'No accounts'
                                : 'No matching accounts',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withAlpha(150),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: accounts.length,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemBuilder: (context, index) {
                        final account = accounts[index];
                        final isSelected = account == vm.currentAccount;

                        return _AccountTile(
                          name: account.accountName ?? 'Unknown',
                          isSelected: isSelected,
                          onTap: () => vm.selectAccount(index),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _AccountTile extends StatelessWidget {
  final String name;
  final bool isSelected;
  final VoidCallback onTap;

  const _AccountTile({
    required this.name,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: isSelected
            ? SteamColors.steamBlue.withAlpha(30)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          hoverColor: theme.colorScheme.primary.withAlpha(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: isSelected
                  ? Border.all(color: SteamColors.steamBlue.withAlpha(80))
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.person_outline,
                  size: 18,
                  color: isSelected
                      ? SteamColors.steamBlue
                      : onSurface.withAlpha(150),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    name,
                    style: TextStyle(
                      color: isSelected
                          ? SteamColors.steamBlue
                          : onSurface,
                      fontSize: 14,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
