import 'dart:async';
import 'dart:io';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:zxing2/qrcode.dart' hide BarcodeFormat;

import '../theme.dart';

/// Vista de la cámara que avisa cada vez que lee un QR.
///
/// En Android, iPhone y la web usa mobile_scanner. En Windows no hay
/// lector nativo: se hace una foto con la webcam cada 0,6 s y zxing2
/// busca el QR en ella.
class EscanerQr extends StatelessWidget {
  const EscanerQr({super.key, required this.alLeer});
  final ValueChanged<String> alLeer;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) return _EscanerWindows(alLeer: alLeer);
    return _EscanerMovil(alLeer: alLeer);
  }
}

// ------------------------------------------------------ móvil y navegador

class _EscanerMovil extends StatefulWidget {
  const _EscanerMovil({required this.alLeer});
  final ValueChanged<String> alLeer;

  @override
  State<_EscanerMovil> createState() => _EscanerMovilState();
}

class _EscanerMovilState extends State<_EscanerMovil> {
  final _control = MobileScannerController(formats: const [BarcodeFormat.qrCode]);

  @override
  void dispose() {
    _control.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MobileScanner(
      controller: _control,
      onDetect: (captura) {
        for (final c in captura.barcodes) {
          final texto = c.rawValue;
          if (texto != null) widget.alLeer(texto);
        }
      },
      placeholderBuilder: (_, __) => const _Mensaje(icono: Icons.photo_camera_outlined, texto: 'Abriendo la cámara…'),
      errorBuilder: (_, error, __) => _Mensaje(
        icono: Icons.no_photography_outlined,
        texto: switch (error.errorCode) {
          MobileScannerErrorCode.permissionDenied =>
            'ForjaApp no tiene permiso para usar la cámara. Actívalo en los ajustes del móvil o del navegador.',
          MobileScannerErrorCode.unsupported => 'Este dispositivo no tiene una cámara compatible.',
          _ => 'No se ha podido abrir la cámara.',
        },
      ),
    );
  }
}

// ---------------------------------------------------------------- Windows

class _EscanerWindows extends StatefulWidget {
  const _EscanerWindows({required this.alLeer});
  final ValueChanged<String> alLeer;

  @override
  State<_EscanerWindows> createState() => _EscanerWindowsState();
}

class _EscanerWindowsState extends State<_EscanerWindows> {
  int? _camara;
  Size? _tamano;
  String? _error;
  Timer? _bucle;
  bool _ocupado = false;
  bool _cerrado = false;

  @override
  void initState() {
    super.initState();
    _abrir();
  }

  Future<void> _abrir() async {
    try {
      final camaras = await CameraPlatform.instance.availableCameras();
      if (camaras.isEmpty) {
        _fallo('No se encuentra ninguna cámara en este equipo. Conecta una webcam o usa los botones de simulación.');
        return;
      }
      final id = await CameraPlatform.instance.createCameraWithSettings(
        camaras.first,
        const MediaSettings(resolutionPreset: ResolutionPreset.medium, enableAudio: false),
      );
      final iniciada = CameraPlatform.instance.onCameraInitialized(id).first;
      await CameraPlatform.instance.initializeCamera(id);
      final e = await iniciada;
      if (_cerrado) {
        await CameraPlatform.instance.dispose(id);
        return;
      }
      setState(() {
        _camara = id;
        _tamano = Size(e.previewWidth, e.previewHeight);
      });
      _bucle = Timer.periodic(const Duration(milliseconds: 600), (_) => _buscarQr());
    } on CameraException catch (e) {
      _fallo(e.code == 'CameraAccessDenied'
          ? 'Windows no deja usar la cámara. Actívala en Configuración → Privacidad y seguridad → Cámara.'
          : 'No se ha podido abrir la cámara (${e.description ?? e.code}).');
    } catch (_) {
      _fallo('No se ha podido abrir la cámara.');
    }
  }

  void _fallo(String texto) {
    if (mounted) setState(() => _error = texto);
  }

  Future<void> _buscarQr() async {
    final id = _camara;
    if (_ocupado || id == null || _cerrado) return;
    _ocupado = true;
    try {
      final foto = await CameraPlatform.instance.takePicture(id);
      final bytes = await foto.readAsBytes();
      unawaited(File(foto.path).delete().then((_) {}, onError: (_) {}));
      final texto = await compute(leerQrDeFoto, bytes);
      if (texto != null && mounted && !_cerrado) widget.alLeer(texto);
    } catch (_) {
      // Una foto fallida no detiene el lector: se reintenta en la siguiente vuelta.
    } finally {
      _ocupado = false;
    }
  }

  @override
  void dispose() {
    _cerrado = true;
    _bucle?.cancel();
    final id = _camara;
    if (id != null) CameraPlatform.instance.dispose(id);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return _Mensaje(icono: Icons.no_photography_outlined, texto: _error!);
    final id = _camara, tam = _tamano;
    if (id == null || tam == null) {
      return const _Mensaje(icono: Icons.photo_camera_outlined, texto: 'Abriendo la cámara…');
    }
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(width: tam.width, height: tam.height, child: CameraPlatform.instance.buildPreview(id)),
      ),
    );
  }
}

/// Busca un QR en una foto (JPEG o PNG). Se ejecuta en otro hilo con compute().
String? leerQrDeFoto(Uint8List bytes) {
  final foto = img.decodeImage(bytes);
  if (foto == null) return null;
  final imagen = foto.width > 960 ? img.copyResize(foto, width: 960) : foto;
  final rgba = Uint8List.fromList(imagen.convert(numChannels: 4).getBytes(order: img.ChannelOrder.abgr));
  final fuente = RGBLuminanceSource(imagen.width, imagen.height, rgba.buffer.asInt32List());
  try {
    return QRCodeReader().decode(BinaryBitmap(HybridBinarizer(fuente))).text;
  } catch (_) {
    return null;
  }
}

class _Mensaje extends StatelessWidget {
  const _Mensaje({required this.icono, required this.texto});
  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Forja.hierro2,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(Esp.xl),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icono, size: 48, color: Forja.grisClaro),
            const SizedBox(height: Esp.m),
            Text(texto,
                textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.4)),
          ]),
        ),
      ),
    );
  }
}
