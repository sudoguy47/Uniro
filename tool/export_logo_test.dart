import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uniro1/widgets/uniro_logo.dart';

/// One-shot exporter: renders [UniroLogoPainter] straight to canvas and
/// writes PNG launcher icons (white tile + mark at 72%).
/// Run explicitly with: flutter test tool/export_logo_test.dart
/// (NOT part of the regular suite — it writes into android/res).
void main() {
  test('export launcher icons', () async {
    const densities = {
      'mipmap-mdpi': 48,
      'mipmap-hdpi': 72,
      'mipmap-xhdpi': 96,
      'mipmap-xxhdpi': 144,
      'mipmap-xxxhdpi': 192,
    };
    const white = Color(0xFFFFFFFF);
    for (final entry in densities.entries) {
      final px = entry.value;
      final mark = (px * 0.72).roundToDouble();
      final offset = (px - mark) / 2;
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawRect(
        ui.Rect.fromLTWH(0, 0, px.toDouble(), px.toDouble()),
        ui.Paint()..color = white,
      );
      canvas.save();
      canvas.translate(offset, offset);
      UniroLogoPainter().paint(canvas, Size(mark, mark));
      canvas.restore();
      final image = await recorder
          .endRecording()
          .toImage(px, px);
      final bytes =
          await image.toByteData(format: ui.ImageByteFormat.png);
      final out = File(
          'android/app/src/main/res/${entry.key}/ic_launcher.png');
      await out.writeAsBytes(bytes!.buffer.asUint8List());
      // ignore: avoid_print
      print('wrote ${out.path} (${px}x$px)');
    }
  });
}
