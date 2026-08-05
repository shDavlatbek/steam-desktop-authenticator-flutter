/// Represents the type of a mobile confirmation.
enum EMobileConfirmationType {
  invalid(0),
  test(1),
  trade(2),
  marketListing(3),
  featureOptOut(4),
  phoneNumberChange(5),
  accountRecovery(6);

  final int value;
  const EMobileConfirmationType(this.value);

  static EMobileConfirmationType fromValue(int value) {
    return EMobileConfirmationType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => EMobileConfirmationType.invalid,
    );
  }
}

class Confirmation {
  /// Steam returns id, nonce, creator_id as strings in the JSON response.
  /// We store them as strings to avoid overflow issues with large uint64 values
  /// (e.g. nonce "4970084111863341325") and because they are only used as
  /// opaque identifiers in URL query parameters.
  String id;
  String key;
  String creator;
  String? headline;
  List<String>? summary;
  String? accept;
  String? cancel;
  String? icon;
  int confType;

  Confirmation({
    this.id = '0',
    this.key = '0',
    this.creator = '0',
    this.headline,
    this.summary,
    this.accept,
    this.cancel,
    this.icon,
    this.confType = 0,
  });

  /// Convenience getter that maps [confType] to the enum.
  EMobileConfirmationType get confirmationType =>
      EMobileConfirmationType.fromValue(confType);

  factory Confirmation.fromJson(Map<String, dynamic> json) {
    return Confirmation(
      id: _parseId(json['id']),
      key: _parseId(json['nonce']),
      creator: _parseId(json['creator_id']),
      headline: json['headline'] as String?,
      summary: (json['summary'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      accept: json['accept'] as String?,
      cancel: json['cancel'] as String?,
      icon: json['icon'] as String?,
      confType: _parseInt(json['type']),
    );
  }

  /// Parse an ID field that may be a String or int from the JSON response.
  static String _parseId(dynamic value) {
    if (value == null) return '0';
    return value.toString();
  }

  /// Parse an int field that may be a String or int from the JSON response.
  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? 0;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nonce': key,
      'creator_id': creator,
      'headline': headline,
      'summary': summary,
      'accept': accept,
      'cancel': cancel,
      'icon': icon,
      'type': confType,
    };
  }
}

class ConfirmationsResponse {
  bool success;
  String? message;
  bool needAuthentication;
  List<Confirmation>? confirmations;

  ConfirmationsResponse({
    this.success = false,
    this.message,
    this.needAuthentication = false,
    this.confirmations,
  });

  factory ConfirmationsResponse.fromJson(Map<String, dynamic> json) {
    return ConfirmationsResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String?,
      needAuthentication: json['needauth'] as bool? ?? false,
      confirmations: (json['conf'] as List<dynamic>?)
          ?.map((e) => Confirmation.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      'needauth': needAuthentication,
      'conf': confirmations?.map((e) => e.toJson()).toList(),
    };
  }
}
