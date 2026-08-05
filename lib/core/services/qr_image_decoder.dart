import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:zxing2/qrcode.dart';

/// Reads a QR code out of a still image — a screenshot of the Steam login page
/// or a photo from the gallery.
///
/// Deliberately pure Dart (`image` + `zxing2`) rather than
/// `MobileScannerController.analyzeImage`, because that has no Windows
/// implementation and this needs to work on desktop, where taking a screenshot
/// of the login QR is the natural thing to do.
class QrImageDecoder {
  /// Above this, the image is downscaled before decoding. A 12MP phone photo
  /// would otherwise allocate ~48MB for the luminance buffer alone.
  static const int _maxPixels = 4000000;

  /// Decodes [bytes] on a background isolate. Returns the QR payload, or null
  /// if the image could not be read or holds no QR code.
  static Future<String?> decode(Uint8List bytes) => compute(decodeSync, bytes);

  /// The synchronous body of [decode], exposed for tests.
  @visibleForTesting
  static String? decodeSync(Uint8List bytes) {
    img.Image? image;
    try {
      image = img.decodeImage(bytes);
    } catch (_) {
      return null; // not an image, or an unsupported format
    }
    if (image == null) return null;

    image = _downscaleIfHuge(image);

    final LuminanceSource source;
    try {
      source = _toLuminanceSource(image);
    } catch (_) {
      return null;
    }

    final hints = DecodeHints()..put(DecodeHintType.tryHarder);

    // Steam's login page renders the QR dark-on-light, but a screenshot taken
    // in a dark theme (or an inverted phone camera) can arrive reversed, so
    // both polarities are tried. HybridBinarizer copes better with uneven
    // lighting in photos; the global one is better on flat screenshots.
    for (final candidate in [source, InvertedLuminanceSource(source)]) {
      for (final binarizer in [
        HybridBinarizer(candidate),
        GlobalHistogramBinarizer(candidate),
      ]) {
        try {
          final result = QRCodeReader().decode(
            BinaryBitmap(binarizer),
            hints: hints,
          );
          final text = result.text;
          if (text.isNotEmpty) return text;
        } catch (_) {
          continue; // NotFound/Checksum/Format — try the next combination
        }
      }
    }

    return null;
  }

  static img.Image _downscaleIfHuge(img.Image image) {
    final pixels = image.width * image.height;
    if (pixels <= _maxPixels) return image;

    final scale = math.sqrt(_maxPixels / pixels);
    return img.copyResize(
      image,
      width: math.max(1, (image.width * scale).round()),
      interpolation: img.Interpolation.average,
    );
  }

  /// Converts to the packed ABGR int32 buffer zxing2 expects.
  static LuminanceSource _toLuminanceSource(img.Image image) {
    final rgba = image.convert(numChannels: 4);
    final bytes = rgba.getBytes(order: img.ChannelOrder.abgr);

    // A view rather than a copy, honouring any offset in the backing buffer.
    final pixels = Int32List.view(
      bytes.buffer,
      bytes.offsetInBytes,
      image.width * image.height,
    );

    return RGBLuminanceSource(image.width, image.height, pixels);
  }
}
