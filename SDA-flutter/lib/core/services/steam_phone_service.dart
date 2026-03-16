import 'dart:convert';

import 'package:sda_flutter/core/constants/api_endpoints.dart';
import 'package:sda_flutter/core/services/steam_web_service.dart';

/// Handles IPhoneService API calls for managing phone numbers associated with
/// a Steam account.
class SteamPhoneService {
  /// Checks whether the account has a verified phone number.
  ///
  /// Returns `true` if a phone number is verified on the account.
  static Future<bool> getAccountPhoneStatus(
    SteamWebService web,
    String accessToken,
  ) async {
    final url =
        '${ApiEndpoints.phoneAccountStatus}?access_token=$accessToken';
    final responseBody = await web.postRequest(url);

    final json = jsonDecode(responseBody) as Map<String, dynamic>;
    final response = json['response'] as Map<String, dynamic>;
    return response['verified_phone'] == true;
  }

  /// Associates a phone number with the account.
  ///
  /// [phoneNumber] - The phone number in international format (e.g. +1XXXXXXXXXX).
  /// [countryCode] - The ISO 3166-1 alpha-2 country code (e.g. "US").
  ///
  /// Returns the confirmation email address that Steam sent a verification to,
  /// or `null` if none was provided.
  static Future<String?> setAccountPhoneNumber(
    SteamWebService web,
    String accessToken,
    String phoneNumber,
    String countryCode,
  ) async {
    final url =
        '${ApiEndpoints.phoneSetNumber}?access_token=$accessToken';
    final responseBody = await web.postRequest(
      url,
      body: {
        'phone_number': phoneNumber,
        'phone_country_code': countryCode,
      },
    );

    final json = jsonDecode(responseBody) as Map<String, dynamic>;
    final response = json['response'] as Map<String, dynamic>;
    return response['confirmation_email_address'] as String?;
  }

  /// Verifies the phone number on the account using the SMS code the user
  /// received.
  static Future<void> verifyAccountPhoneWithCode(
    SteamWebService web,
    String accessToken,
    String code,
  ) async {
    final url =
        '${ApiEndpoints.phoneVerifyWithCode}?access_token=$accessToken';
    await web.postRequest(
      url,
      body: {
        'code': code,
      },
    );
  }

  /// Checks whether the account is currently waiting for the user to confirm
  /// an email related to phone verification.
  ///
  /// Returns `true` if an email confirmation is still pending.
  static Future<bool> isAccountWaitingForEmailConfirmation(
    SteamWebService web,
    String accessToken,
  ) async {
    final url =
        '${ApiEndpoints.phoneIsWaitingForEmail}?access_token=$accessToken';
    final responseBody = await web.postRequest(url);

    final json = jsonDecode(responseBody) as Map<String, dynamic>;
    final response = json['response'] as Map<String, dynamic>;
    return response['awaiting_email_confirmation'] == true;
  }

  /// Triggers Steam to send an SMS verification code to the phone number on
  /// file.
  static Future<void> sendPhoneVerificationCode(
    SteamWebService web,
    String accessToken,
  ) async {
    final url =
        '${ApiEndpoints.phoneSendVerificationCode}?access_token=$accessToken';
    await web.postRequest(url);
  }
}
