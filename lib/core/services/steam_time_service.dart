import 'dart:convert';

import 'package:sda_flutter/core/constants/api_endpoints.dart';
import 'package:sda_flutter/core/services/steam_web_service.dart';

/// Singleton service that synchronises local time with Steam servers.
///
/// Port of TimeAligner.cs from the original SDA C# project.
class SteamTimeService {
  static final SteamTimeService _instance = SteamTimeService._internal();
  factory SteamTimeService() => _instance;
  SteamTimeService._internal();

  bool _aligned = false;
  int _timeDifference = 0;

  /// Returns the current Unix timestamp adjusted by the Steam server time
  /// difference. Automatically calls [alignTime] on first use.
  Future<int> getSteamTime() async {
    if (!_aligned) {
      await alignTime();
    }
    return DateTime.now().millisecondsSinceEpoch ~/ 1000 + _timeDifference;
  }

  /// Queries the Steam time server and calculates the difference between local
  /// time and server time.
  Future<void> alignTime() async {
    final web = SteamWebService();
    try {
      final responseBody = await web.postRequest(
        ApiEndpoints.twoFactorTimeQuery,
        body: {'steamid': '0'},
      );

      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      final response = json['response'] as Map<String, dynamic>;
      final serverTime = int.parse(response['server_time'].toString());

      final localTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      _timeDifference = serverTime - localTime;
      _aligned = true;
    } finally {
      web.dispose();
    }
  }
}
