/// A Steam QR login challenge, as encoded in the QR code itself.
///
/// Steam renders challenges as `https://s.team/q/{version}/{client_id}`, so a
/// scanned code carries everything needed to identify the pending session.
/// [clientId] is kept as a [String] because Steam's client IDs are uint64 and
/// overflow a Dart int on some platforms — the same reason confirmation IDs
/// are strings.
class QrChallenge {
  final int version;
  final String clientId;

  const QrChallenge({required this.version, required this.clientId});

  /// Matches the challenge URL shape. A trailing query string is allowed and
  /// ignored; Steam has been observed appending parameters to the QR payload.
  static final RegExp _urlPattern =
      RegExp(r'^https?://s\.team/q/(\d+)/(\d+)(\?|$)');

  /// Parses a scanned QR payload.
  ///
  /// Returns `null` when [url] is not a Steam login challenge, so callers can
  /// tell the user they scanned the wrong code rather than crashing.
  static QrChallenge? tryParse(String url) {
    final match = _urlPattern.firstMatch(url.trim());
    if (match == null) return null;

    final version = int.tryParse(match.group(1)!);
    if (version == null) return null;

    return QrChallenge(version: version, clientId: match.group(2)!);
  }

  @override
  String toString() => 'QrChallenge(version: $version, clientId: $clientId)';

  @override
  bool operator ==(Object other) =>
      other is QrChallenge &&
      other.version == version &&
      other.clientId == clientId;

  @override
  int get hashCode => Object.hash(version, clientId);
}
