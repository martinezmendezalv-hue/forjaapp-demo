import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../theme.dart';

/// Número de compilación de esta app (lo pone GitHub Actions al compilar).
/// En las compilaciones locales vale 0 y no se busca actualización.
const compilacion = int.fromEnvironment('COMPILACION');

const _release = 'https://github.com/martinezmendezalv-hue/forjaapp-demo/releases/download/demo';
const _canal = MethodChannel('forja/actualizacion');

enum _Fase { nada, descargando, permiso, lista, instalando, error, iphone }

/// Las apps instaladas fuera de Google Play y de la App Store no se
/// actualizan solas. Al abrir la app se mira si hay una versión más nueva y:
///  - en Android se descarga sola y se abre el instalador (Android obliga a
///    que la persona pulse «Actualizar»; la primera vez pide permiso);
///  - en Windows se descarga e instala sin preguntar y la app se reabre;
///  - en iPhone solo se avisa (hay que volver a pasar el IPA con Sideloadly).
class AvisoActualizacion extends StatefulWidget {
  const AvisoActualizacion({super.key, required this.child});
  final Widget child;

  @override
  State<AvisoActualizacion> createState() => _AvisoActualizacionState();
}

class _AvisoActualizacionState extends State<AvisoActualizacion> with WidgetsBindingObserver {
  _Fase _fase = _Fase.nada;
  double? _progreso;
  String? _apk;
  bool _cerrado = false;

  static bool get _android => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  static bool get _windows => !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
  static bool get _ios => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!kIsWeb && compilacion > 0) _comprobar();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Al volver de los ajustes de Android (tras dar el permiso) se instala.
  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    if (estado == AppLifecycleState.resumed && _fase == _Fase.permiso) _instalarAndroid();
  }

  void _poner(_Fase f, {double? progreso}) {
    if (!mounted) return;
    setState(() {
      _fase = f;
      _progreso = progreso;
    });
  }

  Future<void> _comprobar() async {
    try {
      final r = await http.get(Uri.parse('$_release/version.json')).timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) return;
      final ultima = (jsonDecode(r.body) as Map)['compilacion'];
      if (ultima is! int || ultima <= compilacion) return;
    } catch (_) {
      return; // Sin internet o sin GitHub: ya se mirará la próxima vez.
    }
    if (_android) {
      await _descargar('ForjaApp-Demo.apk', await _canal.invokeMethod<String>('carpeta'));
      if (_apk != null) await _instalarAndroid();
    } else if (_windows) {
      await _descargar('ForjaApp-Demo-Setup.exe', Directory.systemTemp.path);
      if (_apk != null) await _instalarWindows();
    } else if (_ios) {
      _poner(_Fase.iphone);
    }
  }

  Future<void> _descargar(String nombre, String? carpeta) async {
    if (carpeta == null) return;
    _poner(_Fase.descargando, progreso: 0);
    final destino = File('$carpeta${Platform.pathSeparator}$nombre');
    final cliente = http.Client();
    try {
      final r = await cliente.send(http.Request('GET', Uri.parse('$_release/$nombre')));
      if (r.statusCode != 200) throw HttpException('Error ${r.statusCode}');
      final total = r.contentLength ?? 0;
      var recibido = 0;
      final salida = destino.openWrite();
      await for (final trozo in r.stream) {
        salida.add(trozo);
        recibido += trozo.length;
        if (total > 0) _poner(_Fase.descargando, progreso: recibido / total);
      }
      await salida.close();
      _apk = destino.path;
    } catch (_) {
      _poner(_Fase.error);
    } finally {
      cliente.close();
    }
  }

  Future<void> _instalarAndroid() async {
    try {
      final r = await _canal.invokeMethod<String>('instalar', {'ruta': _apk});
      _poner(r == 'permiso' ? _Fase.permiso : _Fase.lista);
    } catch (_) {
      _poner(_Fase.error);
    }
  }

  /// Instalación silenciosa con Inno Setup: cierra esta app y la reabre al acabar.
  Future<void> _instalarWindows() async {
    _poner(_Fase.instalando);
    try {
      await Process.start(_apk!, ['/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART'], mode: ProcessStartMode.detached);
      await Future<void>.delayed(const Duration(seconds: 1));
      exit(0);
    } catch (_) {
      _poner(_Fase.error);
    }
  }

  String get _texto => switch (_fase) {
        _Fase.descargando => 'Descargando la versión nueva de ForjaApp…',
        _Fase.permiso => 'Permite «Instalar apps de esta fuente» para ForjaApp y vuelve a la app.',
        _Fase.lista => 'Versión nueva descargada. Pulsa «Actualizar» en la ventana de Android.',
        _Fase.instalando => 'Actualizando ForjaApp… se volverá a abrir sola.',
        _Fase.error => 'No se ha podido descargar la versión nueva. Se volverá a intentar al abrir la app.',
        _Fase.iphone => 'Hay una versión nueva de ForjaApp: instálala con Sideloadly.',
        _Fase.nada => '',
      };

  @override
  Widget build(BuildContext context) {
    if (_fase == _Fase.nada || _cerrado) return widget.child;
    return Column(children: [
      Material(
        color: _fase == _Fase.error ? Forja.rojoSuave : Forja.ascuaSuave,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Esp.l, Esp.s, Esp.s, Esp.s),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                const Icon(Icons.system_update_rounded, color: Forja.ascuaTexto),
                const SizedBox(width: Esp.m),
                Expanded(child: Text(_texto, style: const TextStyle(fontWeight: FontWeight.w600))),
                if (_fase == _Fase.lista || _fase == _Fase.permiso)
                  FilledButton(onPressed: _instalarAndroid, child: const Text('Instalar')),
                if (_fase == _Fase.iphone)
                  FilledButton(
                    onPressed: () => launchUrl(
                      Uri.parse('https://github.com/martinezmendezalv-hue/forjaapp-demo/releases/tag/demo'),
                      mode: LaunchMode.externalApplication,
                    ),
                    child: const Text('Ver'),
                  ),
                if (_fase != _Fase.descargando && _fase != _Fase.instalando)
                  IconButton(
                    tooltip: 'Ahora no',
                    onPressed: () => setState(() => _cerrado = true),
                    icon: const Icon(Icons.close_rounded),
                  ),
              ]),
              if (_fase == _Fase.descargando) ...[
                const SizedBox(height: Esp.s),
                LinearProgressIndicator(value: _progreso, color: Forja.ascua, backgroundColor: Colors.white),
                const SizedBox(height: Esp.xs),
              ],
            ]),
          ),
        ),
      ),
      Expanded(child: widget.child),
    ]);
  }
}
