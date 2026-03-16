class ApiEndpoints {
  static const String steamApiBase = 'https://api.steampowered.com';
  static const String communityBase = 'https://steamcommunity.com';

  static const String _mobileAuthBase =
      '$steamApiBase/IMobileAuthService/%s/v0001';
  static final String mobileAuthGetWgToken =
      _mobileAuthBase.replaceAll('%s', 'GetWGToken');

  static const String _twoFactorBase =
      '$steamApiBase/ITwoFactorService/%s/v0001';
  static final String twoFactorTimeQuery =
      _twoFactorBase.replaceAll('%s', 'QueryTime');

  // Authentication service
  static const String authGetPasswordRsaPublicKey =
      '$steamApiBase/IAuthenticationService/GetPasswordRSAPublicKey/v1';
  static const String authBeginSessionViaCredentials =
      '$steamApiBase/IAuthenticationService/BeginAuthSessionViaCredentials/v1';
  static const String authPollSessionStatus =
      '$steamApiBase/IAuthenticationService/PollAuthSessionStatus/v1';
  static const String authUpdateWithSteamGuardCode =
      '$steamApiBase/IAuthenticationService/UpdateAuthSessionWithSteamGuardCode/v1';
  static const String authGenerateAccessTokenForApp =
      '$steamApiBase/IAuthenticationService/GenerateAccessTokenForApp/v1/';

  // Two-factor service
  static const String twoFactorAddAuthenticator =
      '$steamApiBase/ITwoFactorService/AddAuthenticator/v1';
  static const String twoFactorFinalizeAddAuthenticator =
      '$steamApiBase/ITwoFactorService/FinalizeAddAuthenticator/v1';
  static const String twoFactorRemoveAuthenticator =
      '$steamApiBase/ITwoFactorService/RemoveAuthenticator/v1';

  // Phone service
  static const String phoneAccountStatus =
      '$steamApiBase/IPhoneService/AccountPhoneStatus/v1';
  static const String phoneSetNumber =
      '$steamApiBase/IPhoneService/SetAccountPhoneNumber/v1';
  static const String phoneVerifyWithCode =
      '$steamApiBase/IPhoneService/VerifyAccountPhoneWithCode/v1';
  static const String phoneIsWaitingForEmail =
      '$steamApiBase/IPhoneService/IsAccountWaitingForEmailConfirmation/v1';
  static const String phoneSendVerificationCode =
      '$steamApiBase/IPhoneService/SendPhoneVerificationCode/v1';

  // User account service
  static const String userGetCountry =
      '$steamApiBase/IUserAccountService/GetUserCountry/v1';

  // Community confirmation endpoints
  static const String confirmationGetList =
      '$communityBase/mobileconf/getlist';
  static const String confirmationAjaxOp =
      '$communityBase/mobileconf/ajaxop';
  static const String confirmationMultiAjaxOp =
      '$communityBase/mobileconf/multiajaxop';
}
