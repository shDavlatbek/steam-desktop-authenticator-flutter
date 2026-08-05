import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:qr/qr.dart';
import 'package:sda_flutter/core/services/qr_image_decoder.dart';

/// Renders [data] as a QR code PNG, the way a screenshot of the Steam login
/// page would look. Generated with the `qr` package so the test does not lean
/// on the same library that does the decoding.
Uint8List renderQrPng(
  String data, {
  int scale = 6,
  int quietZone = 4,
  bool inverted = false,
}) {
  final qr = QrImage(
    QrCode.fromData(data: data, errorCorrectLevel: QrErrorCorrectLevel.M),
  );

  final modules = qr.moduleCount;
  final size = (modules + quietZone * 2) * scale;

  final background = inverted ? img.ColorRgb8(0, 0, 0) : img.ColorRgb8(255, 255, 255);
  final foreground = inverted ? img.ColorRgb8(255, 255, 255) : img.ColorRgb8(0, 0, 0);

  final image = img.Image(width: size, height: size, numChannels: 3);
  img.fill(image, color: background);

  for (int row = 0; row < modules; row++) {
    for (int col = 0; col < modules; col++) {
      if (!qr.isDark(row, col)) continue;
      final x = (col + quietZone) * scale;
      final y = (row + quietZone) * scale;
      img.fillRect(
        image,
        x1: x,
        y1: y,
        x2: x + scale - 1,
        y2: y + scale - 1,
        color: foreground,
      );
    }
  }

  return img.encodePng(image);
}

void main() {
  const challengeUrl = 'https://s.team/q/1/2207813151333862682';

  group('QrImageDecoder.decodeSync', () {
    test('reads a challenge URL back out of a rendered QR code', () {
      final png = renderQrPng(challengeUrl);
      expect(QrImageDecoder.decodeSync(png), equals(challengeUrl));
    });

    test('reads a QR code rendered light-on-dark', () {
      // A screenshot taken from a dark-themed page arrives inverted; the
      // decoder retries with an inverted luminance source.
      final png = renderQrPng(challengeUrl, inverted: true);
      expect(QrImageDecoder.decodeSync(png), equals(challengeUrl));
    });

    test('survives a small module scale', () {
      final png = renderQrPng(challengeUrl, scale: 2);
      expect(QrImageDecoder.decodeSync(png), equals(challengeUrl));
    });

    test('decodes a JPEG, not just PNG', () {
      final decoded = img.decodePng(renderQrPng(challengeUrl))!;
      final jpeg = img.encodeJpg(decoded, quality: 95);
      expect(QrImageDecoder.decodeSync(jpeg), equals(challengeUrl));
    });

    test('returns null for an image with no QR code', () {
      final blank = img.Image(width: 200, height: 200, numChannels: 3);
      img.fill(blank, color: img.ColorRgb8(255, 255, 255));
      expect(QrImageDecoder.decodeSync(img.encodePng(blank)), isNull);
    });

    test('returns null for bytes that are not an image', () {
      final notAnImage = Uint8List.fromList('this is not a picture'.codeUnits);
      expect(QrImageDecoder.decodeSync(notAnImage), isNull);
    });

    test('returns null for empty input rather than throwing', () {
      expect(QrImageDecoder.decodeSync(Uint8List(0)), isNull);
    });

    test('decodes a payload that is not a Steam URL', () {
      // Decoding and validation are separate concerns — QrChallenge decides
      // whether the payload is usable.
      final png = renderQrPng('https://example.com/not-steam');
      expect(
        QrImageDecoder.decodeSync(png),
        equals('https://example.com/not-steam'),
      );
    });
  });
}
