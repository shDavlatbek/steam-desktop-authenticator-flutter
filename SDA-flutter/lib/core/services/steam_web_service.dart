import 'package:http/http.dart' as http;
import 'package:sda_flutter/core/constants/steam_guard_constants.dart';
import 'package:sda_flutter/core/services/debug_logger.dart';

class SteamWebService {
  final http.Client _client;
  final DebugLogger _log = DebugLogger();

  SteamWebService({http.Client? client}) : _client = client ?? http.Client();

  Future<String> getRequest(String url, {Map<String, String>? cookies}) async {
    final headers = <String, String>{
      'User-Agent': SteamGuardConstants.mobileAppUserAgent,
    };
    if (cookies != null && cookies.isNotEmpty) {
      headers['Cookie'] =
          cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
    }

    _log.http('SteamWeb', 'GET $url');

    try {
      final response = await _client.get(Uri.parse(url), headers: headers);
      _log.http('SteamWeb', 'GET ${response.statusCode}',
          detail: _truncate(response.body));
      return response.body;
    } catch (e, st) {
      _log.error('SteamWeb', 'GET failed: $e', detail: st.toString());
      rethrow;
    }
  }

  Future<String> postRequest(
    String url, {
    Map<String, String>? cookies,
    Map<String, String>? body,
  }) async {
    final headers = <String, String>{
      'User-Agent': SteamGuardConstants.mobileAppUserAgent,
      'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
    };
    if (cookies != null && cookies.isNotEmpty) {
      headers['Cookie'] =
          cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
    }

    _log.http('SteamWeb', 'POST $url',
        detail: body != null ? 'Body keys: ${body.keys.join(', ')}' : null);

    try {
      final response = await _client.post(
        Uri.parse(url),
        headers: headers,
        body: body ?? <String, String>{},
      );
      _log.http('SteamWeb', 'POST ${response.statusCode}',
          detail: _truncate(response.body));
      return response.body;
    } catch (e, st) {
      _log.error('SteamWeb', 'POST failed: $e', detail: st.toString());
      rethrow;
    }
  }

  /// POST with a raw form-encoded string body.
  /// Used for endpoints like multiajaxop that need repeated keys (cid[], ck[]).
  Future<String> postRawBody(
    String url, {
    Map<String, String>? cookies,
    required String body,
  }) async {
    final headers = <String, String>{
      'User-Agent': SteamGuardConstants.mobileAppUserAgent,
      'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
    };
    if (cookies != null && cookies.isNotEmpty) {
      headers['Cookie'] =
          cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
    }

    _log.http('SteamWeb', 'POST (raw) $url', detail: 'Body: $body');

    try {
      final response = await _client.post(
        Uri.parse(url),
        headers: headers,
        body: body,
      );
      _log.http('SteamWeb', 'POST ${response.statusCode}',
          detail: _truncate(response.body));
      return response.body;
    } catch (e, st) {
      _log.error('SteamWeb', 'POST failed: $e', detail: st.toString());
      rethrow;
    }
  }

  /// Truncate response body for logging to avoid flooding memory.
  String _truncate(String s, [int max = 2000]) =>
      s.length > max ? '${s.substring(0, max)}...[truncated]' : s;

  void dispose() => _client.close();
}
