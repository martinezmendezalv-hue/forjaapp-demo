import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../theme.dart';

/// Número de compilación de esta app (lo pone GitHub Actions al compilar).
/// En las compilaciones locales vale 0 y no se busca actualización.
const compilacion = int.fromEnvironment('COMPILACION');

const _release = 'https://github.com/martinezmendezalv-hue/forjaapp-demo/releases/download/demo';

/// Las apps instaladas fuera de Google Play y de la App Store no se
/// actualizan solas: al abrir la app se mira si hay una versión más nueva y
/// se ofrece descargarla.
class AvisoActualizacion extends StatefulWidget {
  const AvisoActualizacion({super.key, required this.child});
  final Widget child;

  @override
  State<AvisoActualizacion> createState() => _AvisoActualizacionState();
}

class _AvisoActualizacionState extends State<AvisoActualizacion> {
  bool _hayNueva = false;
  bool _cerrado = false;

  // La web siempre es la última; en iPhone hay que volver a pasar el IPA
  // con Sideloadly, así que se lleva a la página de descargas.
  static bool get _aplica => !kIsWeb && compilacion > 0;

  static Uri get _descarga => switch (defaultTargetPlatform) {
        TargetPlatform.android => Uri.parse('$_release/ForjaApp-Demo.apk'),
        TargetPlatform.windows => Uri.parse('$_release/ForjaApp-Demo-Setup.exe'),
        _ => Uri.parse('https://github.com/martinezmendezalv-hue/forjaapp-demo/releases/tag/demo'),
      };

  @override
  void initState() {
    super.initState();
    if (_aplica) _comprobar();
  }

  Future<void> _comprobar() async {
    try {
      final r = await http.get(Uri.parse('$_release/version.json')).timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) return;
      final ultima = (jsonDecode(r.body) as Map)['compilacion'];
      if (ultima is int && ultima > compilacion && mounted) setState(() => _hayNueva = true);
    } catch (_) {
      // Sin internet o sin GitHub: ya se avisará la próxima vez.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_hayNueva || _cerrado) return widget.child;
    return Column(children: [
      Material(
        color: Forja.ascuaSuave,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Esp.l, Esp.s, Esp.s, Esp.s),
            child: Row(children: [
              const Icon(Icons.system_update_rounded, color: Forja.ascuaTexto),
              const SizedBox(width: Esp.m),
              const Expanded(
                child: Text('Hay una versión nueva de ForjaApp.', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              FilledButton(
                onPressed: () => launchUrl(_descarga, mode: LaunchMode.externalApplication),
                child: const Text('Actualizar'),
              ),
              IconButton(
                tooltip: 'Ahora no',
                onPressed: () => setState(() => _cerrado = true),
                icon: const Icon(Icons.close_rounded),
              ),
            ]),
          ),
        ),
      ),
      Expanded(child: widget.child),
    ]);
  }
}
