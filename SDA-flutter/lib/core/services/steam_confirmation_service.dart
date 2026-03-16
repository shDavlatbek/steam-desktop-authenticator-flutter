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
    int confId,
    int confKey,
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
    List<Map<String, int>> confs,
    String op,
    String queryParams,
    Map<String, String> cookies,
  ) async {
    final url = '${ApiEndpoints.confirmationMultiAjaxOp}?$queryParams';

    // Build the form body with repeated cid[] and ck[] entries.
    final bodyParts = <String>['op=$op'];
    for (final conf in confs) {
      bodyParts.add('cid[]=${conf['id']}');
      bodyParts.add('ck[]=${conf['nonce']}');
    }

    // The Steam endpoint expects repeated `cid[]` / `ck[]` keys which cannot
    // be represented in a Map<String, String>. We encode them into the URL
    // query string and POST with the operation in the body.
    final queryWithConfs = StringBuffer(url);
    for (final conf in confs) {
      queryWithConfs
        ..write('&cid[]=${conf['id']}')
        ..write('&ck[]=${conf['nonce']}');
    }

    final responseBody = await web.postRequest(
      queryWithConfs.toString(),
      cookies: cookies,
      body: {'op': op},
    );

    final json = jsonDecode(responseBody) as Map<String, dynamic>;
    return json['success'] == true;
  }
}
