import 'session_data.dart';

class SteamGuardAccount {
  String? sharedSecret;
  String? serialNumber;
  String? revocationCode;
  String? uri;
  int serverTime;
  String? accountName;
  String? tokenGid;
  String? identitySecret;
  String? secret1;
  int status;
  String? deviceId;
  String? phoneNumberHint;
  int confirmType;
  bool fullyEnrolled;
  SessionData? session;

  SteamGuardAccount({
    this.sharedSecret,
    this.serialNumber,
    this.revocationCode,
    this.uri,
    this.serverTime = 0,
    this.accountName,
    this.tokenGid,
    this.identitySecret,
    this.secret1,
    this.status = 0,
    this.deviceId,
    this.phoneNumberHint,
    this.confirmType = 0,
    this.fullyEnrolled = false,
    this.session,
  });

  factory SteamGuardAccount.fromJson(Map<String, dynamic> json) {
    return SteamGuardAccount(
      sharedSecret: json['shared_secret'] as String?,
      serialNumber: json['serial_number'] as String?,
      revocationCode: json['revocation_code'] as String?,
      uri: json['uri'] as String?,
      serverTime: json['server_time'] as int? ?? 0,
      accountName: json['account_name'] as String?,
      tokenGid: json['token_gid'] as String?,
      identitySecret: json['identity_secret'] as String?,
      secret1: json['secret_1'] as String?,
      status: json['status'] as int? ?? 0,
      deviceId: json['device_id'] as String?,
      phoneNumberHint: json['phone_number_hint'] as String?,
      confirmType: json['confirm_type'] as int? ?? 0,
      fullyEnrolled: json['fully_enrolled'] as bool? ?? false,
      session: json['Session'] != null
          ? SessionData.fromJson(json['Session'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'shared_secret': sharedSecret,
      'serial_number': serialNumber,
      'revocation_code': revocationCode,
      'uri': uri,
      'server_time': serverTime,
      'account_name': accountName,
      'token_gid': tokenGid,
      'identity_secret': identitySecret,
      'secret_1': secret1,
      'status': status,
      'device_id': deviceId,
      'phone_number_hint': phoneNumberHint,
      'confirm_type': confirmType,
      'fully_enrolled': fullyEnrolled,
      'Session': session?.toJson(),
    };
  }
}
