import 'dart:convert';

import 'package:sda_flutter/core/constants/api_endpoints.dart';
import 'package:sda_flutter/core/services/steam_web_service.dart';

/// Handles Steam trade/market confirmation operations via the mobileconf
/// endpoints.
class SteamConfirmationService {
  /// Fetches the list of pending confirmations for the logged-in user.
  ///
  /// [url] - The full confirmation list URL, including authentication query
  /// parameters (p, a, k, t, m, tag).
  /// [cookies] - Session cookies required for authentication.
  ///
  /// Returns the decoded JSON response containing the confirmations array.
  static Future<Map<String, dynamic>> fetchConfirmations(
    SteamWebService web,
    String url,
    Map<String, String> cookies,
  ) async {
    final responseBody = await web.getRequest(url, cookies: cookies);
    return jsonDecode(responseBody) as Map<String, dynamic>;
  }

  /// Accepts or denies a single confirmation via the AJAX endpoint.
  ///
  /// [confId] - The confirmation ID (`id` from the confirmation object).
  /// [confKey] - The confirmation key (`nonce` from the confirmation object).
  /// [op] - The operation: `'allow'` to accept, `'cancel'` to deny.
  /// [queryParams] - Pre-built authentication query string (p, a, k, t, m, tag).
  /// [cookies] - Session cookies required for authentication.
  ///
  /// Returns `true` if the operation succeeded.
  static Future<bool> sendConfirmationAjax(
    SteamWebService web,
    String confId,
    String confKey,
    String op,
    String queryParams,
    Map<String, String> cookies,
  ) async {
    final url =
        '${ApiEndpoints.confirmationAjaxOp}?op=$op&$queryParams&cid=$confId&ck=$confKey';
    final responseBody = await web.getRequest(url, cookies: cookies);
    final json = jsonDecode(responseBody) as Map<String, dynamic>;
    return json['success'] == true;
  }

  /// Accepts or denies multiple confirmations in a single request.
  ///
  /// [confs] - A list of maps, each containing `'id'` and `'nonce'` keys.
  /// [op] - The operation: `'allow'` to accept, `'cancel'` to deny.
  /// [queryParams] - Pre-built authentication query string (p, a, k, t, m, tag).
  /// [cookies] - Session cookies required for authentication.
  ///
  /// Returns `true` if the operation succeeded.
  static Future<bool> sendMultiConfirmationAjax(
    SteamWebService web,
    List<Map<String, String>> confs,
    String op,
    String queryParams,
    Map<String, String> cookies,
  ) async {
    // C# sends everything as form-encoded POST body to the bare URL.
    // op + auth query params + repeated cid[]/ck[] all go in the body.
    final url = ApiEndpoints.confirmationMultiAjaxOp;

    final bodyParts = <String>['op=$op', queryParams];
    for (final conf in confs) {
      bodyParts.add('cid[]=${conf['id']}');
      bodyParts.add('ck[]=${conf['nonce']}');
    }

    final responseBody = await web.postRawBody(
      url,
      cookies: cookies,
      body: bodyParts.join('&'),
    );

    final json = jsonDecode(responseBody) as Map<String, dynamic>;
    return json['success'] == true;
  }
}
