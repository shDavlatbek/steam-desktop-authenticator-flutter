import 'package:flutter/foundation.dart';

import 'package:sda_flutter/core/models/qr_challenge.dart';
import 'package:sda_flutter/core/models/steam_guard_account.dart';
import 'package:sda_flutter/core/repositories/login_approval_repository.dart';
import 'package:sda_flutter/core/services/qr_image_decoder.dart';
import 'package:sda_flutter/core/services/steam_login_approval_service.dart';

enum QrApprovalState {
  /// Waiting for a code to be scanned, pasted, or picked from an image.
  awaitingCode,

  /// Searching a chosen image for a QR code.
  decodingImage,

  /// Asking Steam what the pending login looks like.
  loadingInfo,

  /// Showing the login details; the user decides.
  awaitingDecision,

  submitting,
  approved,
  denied,
  error,
}

/// Drives approving a QR login that was started somewhere else — the mirror
/// image of [QrLoginViewModel].
class QrApprovalViewModel extends ChangeNotifier {
  final LoginApprovalRepository _repo;

  /// The account doing the approving. Must hold a shared secret.
  final SteamGuardAccount account;

  QrApprovalState state = QrApprovalState.awaitingCode;
  String? errorMessage;
  QrChallenge? challenge;
  AuthSessionInfo? info;

  QrApprovalViewModel({
    required LoginApprovalRepository repository,
    required this.account,
  }) : _repo = repository;

  /// True when this account is missing what approval requires, so the UI can
  /// explain rather than fail at the last step.
  bool get canApprove => LoginApprovalRepository.canApprove(account);

  String get statusText {
    switch (state) {
      case QrApprovalState.awaitingCode:
        return 'Scan the QR code shown on the device you are signing in on.';
      case QrApprovalState.decodingImage:
        return 'Searching the image for a QR code...';
      case QrApprovalState.loadingInfo:
        return 'Looking up the login request...';
      case QrApprovalState.awaitingDecision:
        return 'Approve this login only if you started it.';
      case QrApprovalState.submitting:
        return 'Sending your response to Steam...';
      case QrApprovalState.approved:
        return 'Login approved. The other device should be signed in now.';
      case QrApprovalState.denied:
        return 'Login denied.';
      case QrApprovalState.error:
        return errorMessage ?? 'An unknown error occurred.';
    }
  }

  /// Whether a newly supplied code should be acted on. Guards against a camera
  /// reporting the same code many times per second, and against a second
  /// source arriving mid-lookup.
  bool get _acceptsNewCode =>
      state == QrApprovalState.awaitingCode || state == QrApprovalState.error;

  /// Handles a scanned or pasted payload.
  Future<void> submitCode(String rawValue) async {
    if (!_acceptsNewCode) return;
    await _lookUp(rawValue);
  }

  /// Handles an image the user chose from the gallery or disk, decoding any QR
  /// code inside it before continuing as if it had been scanned.
  Future<void> submitImage(Uint8List imageBytes) async {
    if (!_acceptsNewCode) return;

    state = QrApprovalState.decodingImage;
    errorMessage = null;
    notifyListeners();

    String? rawValue;
    try {
      rawValue = await QrImageDecoder.decode(imageBytes);
    } catch (_) {
      rawValue = null;
    }

    if (rawValue == null) {
      state = QrApprovalState.error;
      errorMessage = 'No QR code found in that image. Make sure the whole '
          'code is visible and not cropped.';
      notifyListeners();
      return;
    }

    await _lookUp(rawValue);
  }

  Future<void> _lookUp(String rawValue) async {
    final parsed = QrChallenge.tryParse(rawValue);
    if (parsed == null) {
      state = QrApprovalState.error;
      errorMessage = 'That is not a Steam login QR code.';
      notifyListeners();
      return;
    }

    challenge = parsed;
    state = QrApprovalState.loadingInfo;
    errorMessage = null;
    notifyListeners();

    try {
      info = await _repo.getSessionInfo(account, parsed);
      state = QrApprovalState.awaitingDecision;
    } catch (e) {
      state = QrApprovalState.error;
      errorMessage = _formatError(e);
    }
    notifyListeners();
  }

  /// Approves or denies the pending login.
  Future<void> respond({required bool approve}) async {
    final target = challenge;
    if (target == null || state == QrApprovalState.submitting) return;

    state = QrApprovalState.submitting;
    errorMessage = null;
    notifyListeners();

    try {
      await _repo.respond(account, target, approve: approve);
      state = approve ? QrApprovalState.approved : QrApprovalState.denied;
    } catch (e) {
      state = QrApprovalState.error;
      errorMessage = _formatError(e);
    }
    notifyListeners();
  }

  /// Clears the current attempt so another code can be scanned.
  void reset() {
    state = QrApprovalState.awaitingCode;
    errorMessage = null;
    challenge = null;
    info = null;
    notifyListeners();
  }

  String _formatError(Object error) {
    final message = error.toString();
    return message.startsWith('Exception: ')
        ? message.substring('Exception: '.length)
        : message;
  }
}
