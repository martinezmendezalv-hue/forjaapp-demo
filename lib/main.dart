import 'package:flutter/material.dart';

import 'data/store.dart';
import 'screens/acceso.dart';
import 'screens/fichajes.dart';
import 'screens/recepcion.dart';
import 'screens/socio.dart';
import 'theme.dart';

void main() {
  runApp(const ForjaApp());
}

class ForjaApp extends StatefulWidget {
  const ForjaApp({super.key});

  @override
  State<ForjaApp> createState() => _ForjaAppState();
}

class _ForjaAppState extends State<ForjaApp> {
  final store = ForjaStore();
  final messengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    store.ultimoMensaje.addListener(_mostrarMensaje);
  }

  void _mostrarMensaje() {
    final m = store.ultimoMensaje.value;
    if (m == null) return;
    avisar(messengerKey.currentState, m);
  }

  @override
  void dispose() {
    store.ultimoMensaje.removeListener(_mostrarMensaje);
    store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ForjaApp',
      debugShowCheckedModeBanner: false,
      theme: Forja.tema(),
      scaffoldMessengerKey: messengerKey,
      home: Arranque(store: store),
    );
  }
}

/// Notificación flotante de la app. Con [error] sale en rojo.
void avisar(ScaffoldMessengerState? m, String texto, {bool error = false}) {
  m
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      backgroundColor: error ? Forja.rojo : Forja.hierro,
      content: Row(children: [
        Icon(error ? Icons.error_outline_rounded : Icons.notifications_active_outlined,
            color: error ? Colors.white : Forja.ascua, size: 20),
        const SizedBox(width: Esp.m),
        Expanded(child: Text(texto)),
      ]),
      duration: const Duration(seconds: 4),
      width: 560,
      showCloseIcon: true,
      closeIconColor: Colors.white,
    ));
}

/// Pantalla de carga breve al abrir la app.
class Arranque extends StatefulWidget {
  const Arranque({super.key, required this.store});
  final ForjaStore store;

  @override
  State<Arranque> createState() => _ArranqueState();
}

class _ArranqueState extends State<Arranque> {
  bool listo = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1100), () {
      if (mounted) setState(() => listo = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: Mov.largo,
      child: listo
          ? Inicio(store: widget.store)
          : const Scaffold(
              backgroundColor: Forja.hierro,
              body: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Logo(tam: 88),
                  SizedBox(height: Esp.xl),
                  Text('FORJA TRAINING CLUB',
                      style: TextStyle(
                          fontFamily: Forja.display,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 3,
                          color: Colors.white)),
                  SizedBox(height: Esp.l),
                  SizedBox(
                    width: 160,
                    child: LinearProgressIndicator(
                      minHeight: 3,
                      color: Forja.ascua,
                      backgroundColor: Forja.hierro3,
                      semanticsLabel: 'Cargando los datos del club',
                    ),
                  ),
                ]),
              ),
            ),
    );
  }
}

class _Seccion {
  const _Seccion(this.icono, this.iconoActivo, this.titulo, this.descripcion);
  final IconData icono;
  final IconData iconoActivo;
  final String titulo;
  final String descripcion;
}

const _secciones = [
  _Seccion(Icons.smartphone_outlined, Icons.smartphone_rounded, 'App del socio', 'Reservas y pase de entrada'),
  _Seccion(Icons.space_dashboard_outlined, Icons.space_dashboard_rounded, 'Recepción', 'Ocupación y socios'),
  _Seccion(Icons.qr_code_scanner_outlined, Icons.qr_code_scanner_rounded, 'Punto de acceso', 'Tablet del torno'),
  _Seccion(Icons.badge_outlined, Icons.badge_rounded, 'Fichajes', 'Registro de jornada'),
];

class Inicio extends StatefulWidget {
  const Inicio({super.key, required this.store});
  final ForjaStore store;

  @override
  State<Inicio> createState() => _InicioState();
}

class _InicioState extends State<Inicio> {
  /// En la web se puede abrir una sección directamente: ?seccion=recepcion
  int seccion = switch (Uri.base.queryParameters['seccion']) {
    'recepcion' => 1,
    'acceso' => 2,
    'fichajes' => 3,
    _ => 0,
  };

  Widget _pantalla() => switch (seccion) {
        0 => PantallaSocio(store: widget.store),
        1 => PantallaRecepcion(store: widget.store),
        2 => PantallaAcceso(store: widget.store),
        _ => PantallaFichajes(store: widget.store),
      };

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final estrecho = c.maxWidth < 900;
      final contenido = AnimatedSwitcher(
        duration: Mov.medio,
        switchInCurve: Mov.curva,
        transitionBuilder: (child, a) => FadeTransition(
          opacity: a,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.015), end: Offset.zero).animate(a),
            child: child,
          ),
        ),
        child: KeyedSubtree(key: ValueKey(seccion), child: _pantalla()),
      );
      if (estrecho) {
        // En pantallas estrechas (la web abierta en un móvil) el menú pasa a un cajón.
        return Scaffold(
          appBar: AppBar(
            backgroundColor: Forja.hierro,
            foregroundColor: Colors.white,
            titleSpacing: 0,
            title: Row(children: [
              const Logo(tam: 30),
              const SizedBox(width: Esp.m),
              Text(_secciones[seccion].titulo,
                  style: const TextStyle(fontFamily: Forja.display, fontWeight: FontWeight.w700, fontSize: 22)),
            ]),
          ),
          drawer: Drawer(
            backgroundColor: Forja.hierro,
            child: SafeArea(child: _menu(cerrarAlElegir: true)),
          ),
          body: seccion == 0
              ? contenido
              : SingleChildScrollView(
                  // Los paneles de escritorio necesitan unos 1000 px: aquí se
                  // desplazan en horizontal en vez de romperse.
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(width: 1000, child: contenido),
                ),
        );
      }
      return Scaffold(
        body: Row(children: [
          SizedBox(width: 248, child: ColoredBox(color: Forja.hierro, child: _menu())),
          Expanded(
            child: Column(children: [
              _barraSuperior(),
              Expanded(child: LayoutBuilder(builder: (context, k) => _conMinimo(contenido, k))),
            ]),
          ),
        ]),
      );
    });
  }

  /// Los paneles de escritorio están pensados para 1080 × 640 como mínimo:
  /// en ventanas más pequeñas se desplazan en lugar de recortarse.
  Widget _conMinimo(Widget hijo, BoxConstraints k) {
    const ancho = 1080.0, alto = 640.0;
    if (seccion == 0 || (k.maxWidth >= ancho && k.maxHeight >= alto)) return hijo;
    return Scrollbar(
      child: SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: k.maxWidth < ancho ? ancho : k.maxWidth,
            height: k.maxHeight < alto ? alto : k.maxHeight,
            child: hijo,
          ),
        ),
      ),
    );
  }

  Widget _barraSuperior() {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final ahora = DateTime.now();
        final f = fechaLarga(ahora);
        return Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: Esp.xxl),
          decoration: const BoxDecoration(
            color: Forja.superficie,
            border: Border(bottom: BorderSide(color: Forja.linea)),
          ),
          child: Row(children: [
            const Icon(Icons.location_on_outlined, size: 18, color: Forja.gris),
            const SizedBox(width: Esp.xs),
            const Flexible(
              child:
                  Text('Forja Training Club · Guadalajara', style: Txt.cuerpoFuerte, overflow: TextOverflow.ellipsis),
            ),
            const Spacer(),
            Text('${f[0].toUpperCase()}${f.substring(1)}', style: Txt.secundario.copyWith(fontSize: 14)),
            const SizedBox(width: Esp.m),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Forja.acero, borderRadius: BorderRadius.circular(Rad.s)),
              child: Text(horaSeg(ahora), style: Txt.hora.copyWith(fontSize: 16)),
            ),
            const SizedBox(width: Esp.l),
            const SizedBox(height: 28, child: VerticalDivider()),
            const SizedBox(width: Esp.l),
            const Avatar('Ana Martín', tam: 32, fondo: Forja.templeSuave, color: Forja.temple),
            const SizedBox(width: Esp.s),
            const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ana Martín', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                Text('Recepción · turno de mañana', style: TextStyle(fontSize: 12, color: Forja.gris)),
              ],
            ),
          ]),
        );
      },
    );
  }

  Widget _menu({bool cerrarAlElegir = false}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Esp.l, Esp.xl, Esp.l, Esp.l),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: Esp.s),
          child: Row(children: [
            Logo(tam: 42),
            SizedBox(width: Esp.m),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('FORJA',
                  style: TextStyle(
                      fontFamily: Forja.display,
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.5,
                      height: 1)),
              Text('TRAINING CLUB',
                  style: TextStyle(
                      fontFamily: Forja.display,
                      color: Forja.grisOscuro,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2.4)),
            ]),
          ]),
        ),
        const SizedBox(height: Esp.xxl),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: Esp.s),
          child: Text('SECCIONES',
              style: TextStyle(color: Forja.grisOscuro, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1.4)),
        ),
        const SizedBox(height: Esp.s),
        for (var i = 0; i < _secciones.length; i++) _botonMenu(i, cerrarAlElegir),
        const Spacer(),
        Container(
          padding: const EdgeInsets.all(Esp.m),
          decoration: BoxDecoration(
            color: Forja.hierro2,
            borderRadius: BorderRadius.circular(Rad.m),
            border: Border.all(color: Forja.hierro3),
          ),
          child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.science_outlined, size: 18, color: Forja.paja),
            SizedBox(width: Esp.s),
            Expanded(
              child: Text(
                'Versión de demostración con datos de ejemplo. Nada sale de este equipo.',
                style: TextStyle(color: Forja.grisClaro, fontSize: 12.5, height: 1.4),
              ),
            ),
          ]),
        ),
        const SizedBox(height: Esp.m),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: Esp.s),
          child: Text('Proyecto de 2.º DAM · Álvaro Martínez', style: TextStyle(color: Forja.grisOscuro, fontSize: 12)),
        ),
      ]),
    );
  }

  Widget _botonMenu(int i, bool cerrarAlElegir) {
    final s = _secciones[i];
    final activo = i == seccion;
    return Padding(
      padding: const EdgeInsets.only(bottom: Esp.xs),
      child: Semantics(
        selected: activo,
        button: true,
        child: Material(
          color: activo ? Forja.hierro2 : Colors.transparent,
          borderRadius: BorderRadius.circular(Rad.m),
          child: InkWell(
            borderRadius: BorderRadius.circular(Rad.m),
            hoverColor: Forja.hierro2,
            focusColor: Forja.hierro3,
            onTap: () {
              setState(() => seccion = i);
              if (cerrarAlElegir) Navigator.of(context).maybePop();
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Esp.xs, 10, Esp.m, 10),
              child: Row(children: [
                AnimatedContainer(
                  duration: Mov.medio,
                  width: 3,
                  height: 30,
                  decoration: BoxDecoration(
                    color: activo ? Forja.ascua : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: Esp.m),
                Icon(activo ? s.iconoActivo : s.icono, size: 22, color: activo ? Forja.ascua : Forja.grisClaro),
                const SizedBox(width: Esp.m),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s.titulo,
                        style: TextStyle(
                          color: activo ? Colors.white : Forja.grisClaro,
                          fontWeight: activo ? FontWeight.w600 : FontWeight.w500,
                          fontSize: 15,
                        )),
                    Text(s.descripcion, style: const TextStyle(color: Forja.grisOscuro, fontSize: 12)),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
