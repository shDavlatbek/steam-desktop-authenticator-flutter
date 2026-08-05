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

  /// POST that also surfaces the status code and headers.
  ///
  /// Some IAuthenticationService methods have an empty protobuf response, so a
  /// successful call returns `{"response":{}}` and a failed one returns an
  /// empty body — the outcome is only readable from the `x-eresult` header.
  Future<SteamWebResponse> postForResponse(
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
          detail: 'eresult: ${response.headers['x-eresult']}, '
              'body: ${_truncate(response.body)}');

      return SteamWebResponse(
        statusCode: response.statusCode,
        body: response.body,
        eResult: int.tryParse(response.headers['x-eresult'] ?? ''),
        errorMessage: response.headers['x-error_message'],
      );
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

/// A response that carries Steam's `x-eresult` status alongside the body.
class SteamWebResponse {
  final int statusCode;
  final String body;

  /// Steam's EResult code. `1` is success; anything else is a failure whose
  /// meaning is described by [eResultDescription].
  final int? eResult;

  final String? errorMessage;

  const SteamWebResponse({
    required this.statusCode,
    required this.body,
    this.eResult,
    this.errorMessage,
  });

  /// Steam reports success as EResult 1. When the header is absent, fall back
  /// to the HTTP status and a non-empty body.
  bool get isSuccess {
    if (eResult != null) return eResult == 1;
    return statusCode == 200 && body.trim().isNotEmpty;
  }

  /// A human-readable reason for a failed call.
  String get failureReason {
    if (errorMessage != null && errorMessage!.isNotEmpty) return errorMessage!;
    if (eResult != null) return eResultDescription(eResult!);
    return 'Steam returned HTTP $statusCode.';
  }

  /// Descriptions for the EResult codes these auth flows actually produce.
  static String eResultDescription(int code) {
    switch (code) {
      case 1:
        return 'Success.';
      case 2:
        return 'Steam rejected the request.';
      case 5:
        return 'Invalid password or signature.';
      case 8:
        return 'Steam rejected one of the parameters.';
      case 15:
        return 'Access denied — the access token may lack mobile permissions.';
      case 16:
        return 'The request timed out.';
      case 21:
        return 'This login request has expired.';
      case 27:
        return 'This login request was already used.';
      case 84:
        return 'Rate limited by Steam. Wait a while and try again.';
      default:
        return 'Steam returned error code $code.';
    }
  }
}
