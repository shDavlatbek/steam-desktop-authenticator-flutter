import 'package:http/http.dart' as http;
import 'package:sda_flutter/core/constants/steam_guard_constants.dart';

class SteamWebService {
  final http.Client _client;

  SteamWebService({http.Client? client}) : _client = client ?? http.Client();

  Future<String> getRequest(String url, {Map<String, String>? cookies}) async {
    final headers = <String, String>{
      'User-Agent': SteamGuardConstants.mobileAppUserAgent,
    };
    if (cookies != null && cookies.isNotEmpty) {
      headers['Cookie'] =
          cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
    }
    final response = await _client.get(Uri.parse(url), headers: headers);
    return response.body;
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
    final response = await _client.post(
      Uri.parse(url),
      headers: headers,
      body: body ?? <String, String>{},
    );
    return response.body;
  }

  void dispose() => _client.close();
}
