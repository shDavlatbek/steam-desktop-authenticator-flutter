class ManifestEntry {
  String? iv;
  String? salt;
  String filename;
  int steamId;

  ManifestEntry({
    this.iv,
    this.salt,
    required this.filename,
    this.steamId = 0,
  });

  factory ManifestEntry.fromJson(Map<String, dynamic> json) {
    return ManifestEntry(
      iv: json['encryption_iv'] as String?,
      salt: json['encryption_salt'] as String?,
      filename: json['filename'] as String? ?? '',
      steamId: json['steamid'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'encryption_iv': iv,
      'encryption_salt': salt,
      'filename': filename,
      'steamid': steamId,
    };
  }
}

class Manifest {
  bool encrypted;
  bool firstRun;
  List<ManifestEntry> entries;
  bool periodicChecking;
  int periodicCheckingInterval;
  bool checkAllAccounts;
  bool autoConfirmMarketTransactions;
  bool autoConfirmTrades;
  bool debugMode;

  Manifest({
    this.encrypted = false,
    this.firstRun = true,
    List<ManifestEntry>? entries,
    this.periodicChecking = false,
    this.periodicCheckingInterval = 5,
    this.checkAllAccounts = false,
    this.autoConfirmMarketTransactions = false,
    this.autoConfirmTrades = false,
    this.debugMode = false,
  }) : entries = entries ?? [];

  factory Manifest.fromJson(Map<String, dynamic> json) {
    return Manifest(
      encrypted: json['encrypted'] as bool? ?? false,
      firstRun: json['first_run'] as bool? ?? true,
      entries: (json['entries'] as List<dynamic>?)
              ?.map((e) => ManifestEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      periodicChecking: json['periodic_checking'] as bool? ?? false,
      periodicCheckingInterval:
          json['periodic_checking_interval'] as int? ?? 5,
      checkAllAccounts:
          json['periodic_checking_checkall'] as bool? ?? false,
      autoConfirmMarketTransactions:
          json['auto_confirm_market_transactions'] as bool? ?? false,
      autoConfirmTrades: json['auto_confirm_trades'] as bool? ?? false,
      debugMode: json['debug_mode'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'encrypted': encrypted,
      'first_run': firstRun,
      'entries': entries.map((e) => e.toJson()).toList(),
      'periodic_checking': periodicChecking,
      'periodic_checking_interval': periodicCheckingInterval,
      'periodic_checking_checkall': checkAllAccounts,
      'auto_confirm_market_transactions': autoConfirmMarketTransactions,
      'auto_confirm_trades': autoConfirmTrades,
      'debug_mode': debugMode,
    };
  }
}
