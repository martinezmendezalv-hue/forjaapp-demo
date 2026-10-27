import 'package:flutter/material.dart';

import '../data/store.dart';
import '../theme.dart';
import 'recepcion.dart' show estadoAcceso;

class PantallaAcceso extends StatefulWidget {
  const PantallaAcceso({super.key, required this.store});
  final ForjaStore store;

  @override
  State<PantallaAcceso> createState() => _PantallaAccesoState();
}

class _PantallaAccesoState extends State<PantallaAcceso> with TickerProviderStateMixin {
  Acceso? ultimo;
  int manualId = 5;

  /// Tiempo que se muestra el resultado antes de volver a "Acerca tu QR".
  late final AnimationController _reinicio = AnimationController(vsync: this, duration: const Duration(seconds: 5))
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) setState(() => ultimo = null);
    });

  /// Línea del escáner en reposo.
  late final AnimationController _escaner =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat(reverse: true);

  ForjaStore get st => widget.store;

  @override
  void dispose() {
    _reinicio.dispose();
    _escaner.dispose();
    super.dispose();
  }

  void _mostrar(Acceso a) {
    setState(() => ultimo = a);
    _reinicio.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: st,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.fromLTRB(Esp.xxl, Esp.xl, Esp.xxl, Esp.xl),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const CabeceraPanel(antetitulo: 'Punto de acceso · entrada principal', titulo: 'Tablet del torno'),
          const SizedBox(height: Esp.xl),
          Expanded(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(child: _tablet()),
              const SizedBox(width: Esp.xl),
              SizedBox(width: 380, child: _simulador()),
            ]),
          ),
        ]),
      ),
    );
  }

  // ------------------------------------------------------------- tablet

  Widget _tablet() {
    final r = ultimo;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Forja.hierro,
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [BoxShadow(color: Color(0x2915181D), blurRadius: 40, offset: Offset(0, 20))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Semantics(
          liveRegion: true,
          container: true,
          child: AnimatedSwitcher(
            duration: Mov.medio,
            switchInCurve: Mov.curva,
            transitionBuilder: (child, a) => FadeTransition(opacity: a, child: child),
            child: r == null ? _reposo() : _resultado(r),
          ),
        ),
      ),
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
                  width: 190,
                  height: 190,
                  child: AnimatedBuilder(
                    animation: _escaner,
                    builder: (_, child) => CustomPaint(painter: _Visor(_escaner.value), child: child),
                    child: const Center(child: Icon(Icons.qr_code_2_rounded, size: 96, color: Forja.hierro3)),
                  ),
                ),
                const SizedBox(height: Esp.xl),
                const Text('Acerca tu QR al lector',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontFamily: Forja.display, fontSize: 44, fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: Esp.s),
                const Text('Abre ForjaApp y entra en Mi QR',
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 18, color: Forja.grisClaro)),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _resultado(Acceso r) {
    final nombre = r.socio.nombre.split(' ').first;
    final (Color fondo, Color texto, IconData icono, String titulo, String detalle) = switch (r.resultado) {
      ResultadoAcceso.concedido => (
          Forja.verde,
          Colors.white,
          Icons.check_rounded,
          'Adelante, $nombre',
          'Torno abierto · ${horaSeg(r.momento)}'
        ),
      ResultadoAcceso.manual => (
          Forja.temple,
          Colors.white,
          Icons.how_to_reg_rounded,
          'Entrada registrada',
          '${r.socio.nombre} · registrada desde recepción'
        ),
      ResultadoAcceso.cuotaPendiente => (
          Forja.rojo,
          Colors.white,
          Icons.block_rounded,
          'Pasa por recepción',
          '$nombre, tienes un recibo pendiente'
        ),
      ResultadoAcceso.qrCaducado => (
          Forja.paja,
          Forja.tinta,
          Icons.timer_off_outlined,
          'Código caducado',
          'Ese QR ya no vale. Vuelve a abrir Mi QR en la app'
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
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: texto.withValues(alpha: 0.14),
                      border: Border.all(color: texto.withValues(alpha: 0.5), width: 3),
                    ),
                    child: Icon(icono, size: 92, color: texto),
                  ),
                ),
                const SizedBox(height: Esp.xl),
                Text(titulo,
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(fontFamily: Forja.display, fontSize: 52, fontWeight: FontWeight.w700, color: texto)),
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
              label: const Text('Siguiente socio'),
            ),
          ]),
        ),
      ]),
    );
  }

  // ---------------------------------------------------------- simulador

  Widget _simulador() {
    final ventanaAnterior = st.ventanaActual() - 1;
    final intentos = ([...st.accesos]..sort((a, b) => b.momento.compareTo(a.momento))).take(4).toList();
    return ListView(children: [
      Tarjeta(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const TituloBloque('Simular un socio en la puerta',
              apoyo: 'Cada opción acerca al lector el QR que ese socio lleva ahora en el móvil.'),
          const SizedBox(height: Esp.m),
          _opcion('Lucía Gómez', 'Cuota al día', Icons.check_circle_outline_rounded, Forja.verde, Forja.verdeSuave,
              () => _mostrar(st.validarQr(st.tokenQr(1)))),
          _opcion('Raúl Fernández', 'Recibo devuelto', Icons.receipt_long_outlined, Forja.rojo, Forja.rojoSuave,
              () => _mostrar(st.validarQr(st.tokenQr(7)))),
          _opcion('Marcos Herrero', 'Enseña una captura de hace un rato', Icons.screenshot_outlined, Forja.pajaTexto,
              Forja.pajaSuave, () => _mostrar(st.validarQr(st.tokenQr(2, ventanaAnterior)))),
        ]),
      ),
      const SizedBox(height: Esp.l),
      Tarjeta(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const TituloBloque('Entrada manual',
              apoyo: 'Si el socio no trae el móvil o se cae Internet. Se sincroniza al volver la conexión.'),
          const SizedBox(height: Esp.m),
          DropdownButtonFormField<int>(
            value: manualId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Socio', prefixIcon: Icon(Icons.person_search_outlined)),
            items: [
              for (final s in st.socios) DropdownMenuItem(value: s.id, child: Text(s.nombre)),
            ],
            onChanged: (v) => setState(() => manualId = v ?? manualId),
          ),
          const SizedBox(height: Esp.m),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _mostrar(st.entradaManual(manualId)),
              icon: const Icon(Icons.how_to_reg_rounded, size: 20),
              label: const Text('Registrar entrada'),
            ),
          ),
        ]),
      ),
      const SizedBox(height: Esp.l),
      Tarjeta(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, Esp.s),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const TituloBloque('Últimos intentos'),
          const SizedBox(height: Esp.m),
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

  Widget _intento(Acceso a) {
    final e = estadoAcceso(a.resultado);
    return Padding(
      padding: const EdgeInsets.only(bottom: Esp.m),
      child: Row(children: [
        Icon(e.icono, size: 18, color: e.color),
        const SizedBox(width: Esp.s),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(a.socio.nombre, style: Txt.cuerpoFuerte.copyWith(fontSize: 14)),
            Text(e.texto, style: Txt.secundario.copyWith(fontSize: 12.5)),
          ]),
        ),
        Text(horaSeg(a.momento), style: Txt.secundario.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
      ]),
    );
  }

  Widget _opcion(String titulo, String sub, IconData icono, Color color, Color fondo, VoidCallback alPulsar) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Esp.s),
      child: Material(
        color: Forja.superficie,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Rad.m),
          side: const BorderSide(color: Forja.linea),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: alPulsar,
          hoverColor: Forja.acero,
          child: Padding(
            padding: const EdgeInsets.all(Esp.m),
            child: Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(Rad.m)),
                child: Icon(icono, color: color, size: 22),
              ),
              const SizedBox(width: Esp.m),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(titulo, style: Txt.cuerpoFuerte),
                  Text(sub, style: Txt.secundario),
                ]),
              ),
              const Icon(Icons.qr_code_scanner_rounded, color: Forja.gris, size: 22),
            ]),
          ),
        ),
      ),
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
