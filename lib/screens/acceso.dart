import 'dart:async';

import 'package:flutter/material.dart';

import '../servicios/api.dart' show ErrorServidor, segundosQr;
import '../servicios/sesion.dart' show sesion;
import '../theme.dart';
import '../widgets/escaner.dart';
import 'recepcion.dart' show estadoAcceso, horaDe;

/// Tablet del torno: lee el pase QR de cada socio y lo comprueba con el
/// servidor. Si alguien no trae el móvil, se registra su entrada a mano.
class PantallaAcceso extends StatefulWidget {
  const PantallaAcceso({super.key});

  @override
  State<PantallaAcceso> createState() => _PantallaAccesoState();
}

/// Lo que se enseña en la tablet tras leer un pase.
class _Lectura {
  _Lectura(this.nombre, this.resultado) : momento = DateTime.now();
  final String nombre;
  final String resultado;
  final DateTime momento;
}

class _PantallaAccesoState extends State<PantallaAcceso> with TickerProviderStateMixin {
  _Lectura? ultimo;

  /// Lector con la cámara encendido.
  bool camara = false;

  /// Mensaje breve sobre la cámara ("Ese QR no es de Forja"...).
  String? pista;
  Timer? _pistaTimer;

  /// Para no registrar dos veces al mismo socio delante del lector.
  int? _ultimoSocio;
  DateTime _horaUltimo = DateTime(2000);

  /// Tamaños reducidos cuando la tablet ocupa la pantalla de un móvil.
  bool _compacto = false;

  /// Socios reales y últimos intentos (para la entrada manual y el historial).
  List<Map<String, dynamic>> socios = [];
  List<Map<String, dynamic>> intentos = [];
  int? manualId;

  /// Tiempo que se muestra el resultado antes de volver a "Acerca tu QR".
  late final AnimationController _reinicio = AnimationController(vsync: this, duration: const Duration(seconds: 5))
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) setState(() => ultimo = null);
    });

  /// Línea del escáner en reposo.
  late final AnimationController _escaner =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _pistaTimer?.cancel();
    _reinicio.dispose();
    _escaner.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      final d = await sesion.api.recepcion();
      if (!mounted) return;
      setState(() {
        socios = (d['socios'] as List).cast<Map<String, dynamic>>();
        intentos = (d['accesos'] as List).cast<Map<String, dynamic>>().take(5).toList();
        if (!socios.any((s) => s['id'] == manualId)) manualId = socios.isEmpty ? null : socios.first['id'] as int;
      });
    } on ErrorServidor catch (e) {
      if (e.sesionCaducada) await sesion.salir();
    }
  }

  void _mostrar(_Lectura l) {
    setState(() => ultimo = l);
    _reinicio.forward(from: 0);
    _cargar();
  }

  void _alternarCamara() {
    setState(() {
      camara = !camara;
      ultimo = null;
      pista = null;
    });
    _reinicio.stop();
  }

  void _avisar(String texto) {
    _pistaTimer?.cancel();
    setState(() => pista = texto);
    _pistaTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => pista = null);
    });
  }

  /// Llega un texto leído por la cámara.
  void _leido(String token) {
    if (ultimo != null) return; // se está enseñando un resultado
    if (!token.startsWith('FORJA2-')) {
      if (pista == null) _avisar('Ese QR no es un pase de ForjaApp');
      return;
    }
    _leidoServidor(token);
  }

  bool _validando = false;

  /// El pase lo comprueba siempre el servidor (firma, caducidad y plan).
  Future<void> _leidoServidor(String token) async {
    if (_validando) return;
    final uid = int.tryParse(token.split('-').elementAtOrNull(1) ?? '');
    if (uid == _ultimoSocio && DateTime.now().difference(_horaUltimo) < const Duration(seconds: 8)) return;
    _validando = true;
    try {
      final r = await sesion.api.validarAcceso(token);
      if (!mounted) return;
      final socio = r['socio'];
      if (r['resultado'] == 'desconocido' || socio is! Map) {
        _avisar('Ese QR no es un pase de ForjaApp');
        return;
      }
      _ultimoSocio = uid;
      _horaUltimo = DateTime.now();
      _mostrar(_Lectura(socio['nombre'] as String, r['resultado'] as String));
    } on ErrorServidor catch (e) {
      if (mounted) _avisar(e.mensaje);
    } finally {
      _validando = false;
    }
  }

  Future<void> _manual([int? id]) async {
    final elegido = id ?? manualId;
    if (elegido == null) return;
    try {
      final r = await sesion.api.accesoManual(elegido);
      if (!mounted) return;
      _mostrar(_Lectura((r['socio'] as Map)['nombre'] as String, r['resultado'] as String));
    } on ErrorServidor catch (e) {
      if (mounted) _avisar(e.mensaje);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < 760) {
        // En un móvil la tablet ocupa toda la pantalla y el resto va en botones.
        return Padding(
          padding: const EdgeInsets.all(Esp.m),
          child: Column(children: [
            Expanded(child: _tablet()),
            const SizedBox(height: Esp.m),
            Row(children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _alternarCamara,
                  icon: Icon(camara ? Icons.no_photography_outlined : Icons.qr_code_scanner_rounded, size: 20),
                  label: Text(camara ? 'Cerrar la cámara' : 'Escanear con la cámara'),
                ),
              ),
              const SizedBox(width: Esp.s),
              OutlinedButton.icon(
                onPressed: () => _hojaManual(context),
                icon: const Icon(Icons.how_to_reg_rounded, size: 20),
                label: const Text('Manual'),
              ),
            ]),
          ]),
        );
      }
      return Padding(
        padding: const EdgeInsets.fromLTRB(Esp.xxl, Esp.xl, Esp.xxl, Esp.xl),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const CabeceraPanel(antetitulo: 'Punto de acceso · entrada principal', titulo: 'Tablet del torno'),
          const SizedBox(height: Esp.xl),
          Expanded(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(child: _tablet()),
              const SizedBox(width: Esp.xl),
              SizedBox(width: 380, child: _lateral()),
            ]),
          ),
        ]),
      );
    });
  }

  // ------------------------------------------------------------- tablet

  Widget _tablet() {
    final r = ultimo;
    return LayoutBuilder(builder: (context, c) {
      _compacto = c.maxWidth < 560;
      return Container(
        padding: EdgeInsets.all(_compacto ? 8 : 14),
        decoration: BoxDecoration(
          color: Forja.hierro,
          borderRadius: BorderRadius.circular(30),
          boxShadow: const [BoxShadow(color: Color(0x2915181D), blurRadius: 40, offset: Offset(0, 20))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(fit: StackFit.expand, children: [
            if (camara) EscanerQr(alLeer: _leido),
            Semantics(
              liveRegion: true,
              container: true,
              child: AnimatedSwitcher(
                duration: Mov.medio,
                switchInCurve: Mov.curva,
                transitionBuilder: (child, a) => FadeTransition(opacity: a, child: child),
                child: r != null
                    ? _resultado(r)
                    : camara
                        ? _capaCamara()
                        : _reposo(),
              ),
            ),
          ]),
        ),
      );
    });
  }

  /// Lo que se ve encima de la imagen de la cámara mientras lee.
  Widget _capaCamara() {
    final lado = _compacto ? 210.0 : 260.0;
    return Container(
      key: const ValueKey('camara'),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xB315181D), Color(0x0015181D), Color(0x0015181D), Color(0xCC15181D)],
          stops: [0, 0.22, 0.65, 1],
        ),
      ),
      child: Column(children: [
        _barraTablet(Colors.white),
        const Spacer(),
        SizedBox(
          width: lado,
          height: lado,
          child: AnimatedBuilder(
            animation: _escaner,
            builder: (_, __) => CustomPaint(painter: _Visor(_escaner.value)),
          ),
        ),
        const Spacer(),
        AnimatedSwitcher(
          duration: Mov.corto,
          child: Container(
            key: ValueKey(pista),
            margin: const EdgeInsets.symmetric(horizontal: Esp.l),
            padding: const EdgeInsets.symmetric(horizontal: Esp.m, vertical: Esp.s),
            decoration: BoxDecoration(
              color: pista == null ? Colors.transparent : Forja.paja,
              borderRadius: BorderRadius.circular(Rad.m),
            ),
            child: Text(
              pista ?? 'Enseña el QR de ForjaApp a la cámara',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: pista == null ? Colors.white : Forja.tinta,
                fontSize: _compacto ? 16 : 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: Esp.s),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: Esp.l),
          child: Text('El código cambia cada $segundosQr s: vale el que está en pantalla ahora',
              textAlign: TextAlign.center, style: TextStyle(color: Forja.grisClaro, fontSize: 13)),
        ),
        SizedBox(height: _compacto ? Esp.l : Esp.xl),
      ]),
    );
  }

  Widget _barraTablet(Color texto) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Esp.xl, 18, Esp.xl, 0),
      child: Row(children: [
        Text('FORJA TRAINING CLUB',
            style: TextStyle(
                fontFamily: Forja.display, color: texto, fontWeight: FontWeight.w700, letterSpacing: 2, fontSize: 16)),
        const Spacer(),
        Text(hora(DateTime.now()),
            style: TextStyle(
                fontFamily: Forja.display,
                color: texto,
                fontWeight: FontWeight.w700,
                fontSize: 20,
                fontFeatures: const [FontFeature.tabularFigures()])),
      ]),
    );
  }

  Widget _reposo() {
    return ColoredBox(
      key: const ValueKey('reposo'),
      color: Forja.hierro2,
      child: Column(children: [
        _barraTablet(Forja.grisClaro),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(Esp.xl),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(
                  width: _compacto ? 150 : 190,
                  height: _compacto ? 150 : 190,
                  child: AnimatedBuilder(
                    animation: _escaner,
                    builder: (_, child) => CustomPaint(painter: _Visor(_escaner.value), child: child),
                    child: const Center(child: Icon(Icons.qr_code_2_rounded, size: 96, color: Forja.hierro3)),
                  ),
                ),
                const SizedBox(height: Esp.xl),
                Text('Acerca tu QR al lector',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontFamily: Forja.display,
                        fontSize: _compacto ? 32 : 44,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
                const SizedBox(height: Esp.s),
                const Text('Abre ForjaApp y entra en Mi pase',
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 18, color: Forja.grisClaro)),
                if (!_compacto) ...[
                  const SizedBox(height: Esp.xl),
                  FilledButton.icon(
                    onPressed: _alternarCamara,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 52),
                      textStyle: const TextStyle(fontFamily: Forja.texto, fontSize: 17, fontWeight: FontWeight.w600),
                    ),
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    label: const Text('Escanear con la cámara'),
                  ),
                ],
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _resultado(_Lectura r) {
    final nombre = r.nombre.split(' ').first;
    final (Color fondo, Color texto, IconData icono, String titulo, String detalle) = switch (r.resultado) {
      'concedido' => (
          Forja.verde,
          Colors.white,
          Icons.check_rounded,
          'Adelante, $nombre',
          'Torno abierto · ${horaSeg(r.momento)}'
        ),
      'manual' => (
          Forja.temple,
          Colors.white,
          Icons.how_to_reg_rounded,
          'Entrada registrada',
          '${r.nombre} · registrada desde recepción'
        ),
      'cuotaPendiente' => (
          Forja.rojo,
          Colors.white,
          Icons.block_rounded,
          'Pasa por recepción',
          '$nombre, todavía no tienes un plan'
        ),
      _ => (
          Forja.paja,
          Forja.tinta,
          Icons.timer_off_outlined,
          'Código caducado',
          'Ese QR ya no vale. Vuelve a abrir Mi pase en la app'
        ),
    };
    return ColoredBox(
      key: ValueKey(r),
      color: fondo,
      child: Column(children: [
        _barraTablet(texto),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(Esp.xl),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.4, end: 1),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.elasticOut,
                  builder: (_, e, child) => Transform.scale(scale: e, child: child),
                  child: Container(
                    width: _compacto ? 110 : 150,
                    height: _compacto ? 110 : 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: texto.withValues(alpha: 0.14),
                      border: Border.all(color: texto.withValues(alpha: 0.5), width: 3),
                    ),
                    child: Icon(icono, size: _compacto ? 66 : 92, color: texto),
                  ),
                ),
                const SizedBox(height: Esp.xl),
                Text(titulo,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontFamily: Forja.display,
                        fontSize: _compacto ? 36 : 52,
                        fontWeight: FontWeight.w700,
                        color: texto)),
                const SizedBox(height: Esp.s),
                Text(detalle, textAlign: TextAlign.center, style: TextStyle(fontSize: 19, color: texto)),
              ]),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Esp.xl, 0, Esp.l, Esp.l),
          child: Row(children: [
            Expanded(
              child: AnimatedBuilder(
                animation: _reinicio,
                builder: (_, __) => ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: 1 - _reinicio.value,
                    minHeight: 4,
                    color: texto.withValues(alpha: 0.8),
                    backgroundColor: texto.withValues(alpha: 0.2),
                    semanticsLabel: 'Tiempo hasta el siguiente socio',
                  ),
                ),
              ),
            ),
            const SizedBox(width: Esp.l),
            TextButton.icon(
              onPressed: () {
                _reinicio.stop();
                setState(() => ultimo = null);
              },
              style: TextButton.styleFrom(foregroundColor: texto, iconColor: texto),
              icon: const Icon(Icons.skip_next_rounded),
              label: Text(_compacto ? 'Siguiente' : 'Siguiente socio'),
            ),
          ]),
        ),
      ]),
    );
  }

  // -------------------------------------------------------------- lateral

  Widget _lateral() {
    return ListView(children: [
      Tarjeta(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const TituloBloque('Lector con la cámara',
              apoyo: 'El socio abre Mi pase en su móvil y lo enseña a la cámara.'),
          const SizedBox(height: Esp.m),
          SizedBox(
            width: double.infinity,
            child: camara
                ? OutlinedButton.icon(
                    onPressed: _alternarCamara,
                    icon: const Icon(Icons.no_photography_outlined, size: 20),
                    label: const Text('Cerrar la cámara'),
                  )
                : FilledButton.icon(
                    onPressed: _alternarCamara,
                    icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                    label: const Text('Escanear con la cámara'),
                  ),
          ),
        ]),
      ),
      const SizedBox(height: Esp.l),
      Tarjeta(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const TituloBloque('Entrada manual', apoyo: 'Si el socio no trae el móvil. Solo pasa si tiene plan.'),
          const SizedBox(height: Esp.m),
          if (socios.isEmpty)
            const Text('Todavía no hay socios registrados.', style: Txt.secundario)
          else ...[
            DropdownButtonFormField<int>(
              value: manualId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Socio', prefixIcon: Icon(Icons.person_search_outlined)),
              items: [
                for (final s in socios) DropdownMenuItem(value: s['id'] as int, child: Text(s['nombre'] as String)),
              ],
              onChanged: (v) => setState(() => manualId = v),
            ),
            const SizedBox(height: Esp.m),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _manual(),
                icon: const Icon(Icons.how_to_reg_rounded, size: 20),
                label: const Text('Registrar entrada'),
              ),
            ),
          ],
        ]),
      ),
      const SizedBox(height: Esp.l),
      Tarjeta(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, Esp.s),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const TituloBloque('Últimos intentos de hoy'),
          const SizedBox(height: Esp.m),
          if (intentos.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: Esp.m),
              child: Text('Hoy todavía no ha pasado nadie.', style: Txt.secundario),
            ),
          for (final a in intentos) _intento(a),
        ]),
      ),
      const SizedBox(height: Esp.l),
      const Nota(
        'La AEPD multó con 27.000 € a un gimnasio por exigir la huella para entrar. El QR identifica igual sin tratar datos biométricos.',
        titulo: '¿Por qué QR y no huella?',
        icono: Icons.policy_outlined,
      ),
    ]);
  }

  /// En el móvil, la entrada manual sale en una hoja inferior.
  Future<void> _hojaManual(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Forja.superficie,
      builder: (hoja) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(hoja).height * 0.7),
          child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(Esp.l, 0, Esp.l, Esp.l), children: [
            const TituloBloque('Entrada manual', apoyo: 'Toca al socio que está en la puerta.'),
            const SizedBox(height: Esp.m),
            if (socios.isEmpty) const Text('Todavía no hay socios registrados.', style: Txt.secundario),
            for (final s in socios)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Avatar(s['nombre'] as String),
                title: Text(s['nombre'] as String, style: Txt.cuerpoFuerte),
                subtitle: Text(s['plan'] == null ? 'Sin plan' : 'Plan ${s['plan']}'),
                trailing: const Icon(Icons.how_to_reg_rounded),
                onTap: () {
                  Navigator.pop(hoja);
                  _manual(s['id'] as int);
                },
              ),
          ]),
        ),
      ),
    );
  }

  Widget _intento(Map<String, dynamic> a) {
    final e = estadoAcceso(a['resultado'] as String);
    return Padding(
      padding: const EdgeInsets.only(bottom: Esp.m),
      child: Row(children: [
        Icon(e.icono, size: 18, color: e.color),
        const SizedBox(width: Esp.s),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(a['nombre'] as String? ?? 'Pase desconocido', style: Txt.cuerpoFuerte.copyWith(fontSize: 14)),
            Text(e.texto, style: Txt.secundario.copyWith(fontSize: 12.5)),
          ]),
        ),
        Text(horaDe(a['fecha']), style: Txt.secundario.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
      ]),
    );
  }
}

/// Esquinas del visor y línea de escaneo en color ascua.
class _Visor extends CustomPainter {
  _Visor(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Forja.ascua
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    const l = 36.0;
    final w = size.width, h = size.height;
    for (final (x, y, dx, dy) in [(0.0, 0.0, 1.0, 1.0), (w, 0.0, -1.0, 1.0), (0.0, h, 1.0, -1.0), (w, h, -1.0, -1.0)]) {
      canvas.drawLine(Offset(x, y), Offset(x + l * dx, y), p);
      canvas.drawLine(Offset(x, y), Offset(x, y + l * dy), p);
    }
    final y = 18 + (h - 36) * Curves.easeInOut.transform(t);
    final linea = Paint()
      ..shader = const LinearGradient(colors: [Color(0x00E8611A), Forja.ascua, Color(0x00E8611A)])
          .createShader(Rect.fromLTWH(0, y - 1, w, 3));
    canvas.drawRect(Rect.fromLTWH(14, y - 1.5, w - 28, 3), linea);
  }

  @override
  bool shouldRepaint(_Visor old) => old.t != t;
}
