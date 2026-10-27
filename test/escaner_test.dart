import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:forja_app_demo/data/store.dart';
import 'package:forja_app_demo/widgets/escaner.dart';
import 'package:image/image.dart' as img;
import 'package:zxing2/qrcode.dart';

/// Dibuja un QR como lo vería la webcam: foto JPEG con margen blanco.
Uint8List fotoDeQr(String texto) {
  final qr = Encoder.encode(texto, ErrorCorrectionLevel.m);
  final m = qr.matrix!;
  const escala = 8, margen = 40;
  final foto = img.Image(width: m.width * escala + margen * 2, height: m.height * escala + margen * 2);
  img.fill(foto, color: img.ColorRgb8(255, 255, 255));
  for (var y = 0; y < m.height; y++) {
    for (var x = 0; x < m.width; x++) {
      if (m.get(x, y) == 1) {
        img.fillRect(foto,
            x1: margen + x * escala,
            y1: margen + y * escala,
            x2: margen + (x + 1) * escala - 1,
            y2: margen + (y + 1) * escala - 1,
            color: img.ColorRgb8(21, 24, 29));
      }
    }
  }
  return img.encodeJpg(foto, quality: 85);
}

void main() {
  test('el lector de Windows lee el QR del pase de un socio', () {
    final store = ForjaStore();
    final token = store.tokenQr(1);
    expect(leerQrDeFoto(fotoDeQr(token)), token);
    store.dispose();
  });

  test('una foto sin QR no devuelve nada', () {
    final vacia = img.Image(width: 320, height: 240);
    img.fill(vacia, color: img.ColorRgb8(200, 200, 200));
    expect(leerQrDeFoto(img.encodeJpg(vacia)), isNull);
  });

  test('el pase vigente tiene antigüedad 0 y uno inventado no es de Forja', () {
    final store = ForjaStore();
    expect(store.antiguedadQr(store.tokenQr(3)), 0);
    expect(store.antiguedadQr(store.tokenQr(3, store.ventanaActual() - 2)), 2);
    expect(store.antiguedadQr('FORJA-3-123-1'), isNull);
    expect(store.antiguedadQr('https://example.com'), isNull);
    store.dispose();
  });
}
