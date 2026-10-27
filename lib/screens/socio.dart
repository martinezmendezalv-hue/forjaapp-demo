import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../data/store.dart';
import '../main.dart' show avisar;
import '../theme.dart';

/// Socios que se pueden elegir para probar cada caso.
const _personas = [
  (1, 'Primera en la lista de espera del ciclo de las 19:00'),
  (2, 'Tiene plaza en el ciclo de las 19:00'),
  (3, 'Reservas bloqueadas por 3 ausencias este mes'),
  (7, 'Recibo devuelto: el torno no le abre'),
  (5, 'Tarifa Sala libre, sin clases dirigidas'),
  (10, 'Segunda en la lista de espera de las 19:00'),
];

enum _Categoria { todas, cardio, fuerza, cuerpoMente }

extension on _Categoria {
  String get nombre => switch (this) {
        _Categoria.todas => 'Todas',
        _Categoria.cardio => 'Cardio',
        _Categoria.fuerza => 'Fuerza',
        _Categoria.cuerpoMente => 'Cuerpo y mente',
      };
}

_Categoria _categoria(Sesion s) => switch (s.actividad) {
      'Ciclo indoor' || 'HIIT' => _Categoria.cardio,
      'Body pump' => _Categoria.fuerza,
      _ => _Categoria.cuerpoMente,
    };

IconData _iconoActividad(Sesion s) => switch (s.actividad) {
      'Ciclo indoor' => Icons.directions_bike_rounded,
      'HIIT' => Icons.bolt_rounded,
      'Body pump' => Icons.fitness_center_rounded,
      _ => Icons.self_improvement_rounded,
    };

class PantallaSocio extends StatefulWidget {
  const PantallaSocio({super.key, required this.store});
  final ForjaStore store;

  @override
  State<PantallaSocio> createState() => _PantallaSocioState();
}

class _PantallaSocioState extends State<PantallaSocio> {
  int socioId = 1; // Lucía, primera en la lista de espera de las 19:00
  int pestana = 0;
  bool cargando = false;
  _Categoria filtro = _Categoria.todas;

  /// Avisos que cada socio ya ha visto y cuántos eran nuevos al abrir la pestaña.
  final Map<int, int> vistos = {};
  final Map<int, int> nuevos = {};

  ForjaStore get st => widget.store;

  void _cambiarSocio(int id) {
    if (id == socioId) return;
    setState(() {
      socioId = id;
      pestana = 0;
      filtro = _Categoria.todas;
      cargando = true;
    });
    Future.delayed(const Duration(milliseconds: 550), () {
      if (mounted) setState(() => cargando = false);
    });
  }

  void _irA(int i) {
    setState(() {
      pestana = i;
      if (i == 3) {
        final total = st.avisos.where((a) => a.socioId == socioId).length;
        nuevos[socioId] = total - (vistos[socioId] ?? 0);
        vistos[socioId] = total;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: st,
      builder: (context, _) {
        final so = st.socio(socioId);
        return LayoutBuilder(builder: (context, c) {
          if (c.maxWidth < 760) {
            // Web en un móvil: la app ocupa toda la pantalla.
            return Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(Esp.l, Esp.m, Esp.l, Esp.s),
                child: _selectorCompacto(),
              ),
              Expanded(child: _app(so, marco: false)),
            ]);
          }
          return Padding(
            padding: const EdgeInsets.fromLTRB(Esp.xxl, Esp.xl, Esp.xxl, Esp.xl),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Center(child: _marcoMovil(so))),
              const SizedBox(width: Esp.xxl),
              SizedBox(width: 380, child: _panelDemo(so)),
            ]),
          );
        });
      },
    );
  }

  // ------------------------------------------------------------ marco móvil

  Widget _marcoMovil(Socio so) {
    return LayoutBuilder(builder: (context, c) {
      // El móvil se dibuja a tamaño real y se escala si la ventana es pequeña.
      final alto = c.maxHeight.clamp(640.0, 820.0);
      final ancho = (alto * 0.47).clamp(330.0, 390.0);
      return FittedBox(
        fit: BoxFit.scaleDown,
        child: Semantics(
          label: 'Vista previa de la app del socio',
          container: true,
          child: Container(
            width: ancho,
            height: alto,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Forja.hierro,
              borderRadius: BorderRadius.circular(46),
              boxShadow: const [
                BoxShadow(color: Color(0x2915181D), blurRadius: 40, offset: Offset(0, 20)),
                BoxShadow(color: Color(0x1415181D), blurRadius: 6, offset: Offset(0, 2)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(36),
              child: Stack(children: [
                Positioned.fill(child: _app(so)),
                // Isla de la cámara
                Positioned(
                  top: 9,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      width: 96,
                      height: 26,
                      decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(20)),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
      );
    });
  }

  Widget _app(Socio so, {bool marco = true}) {
    final qr = pestana == 2;
    return ColoredBox(
      color: qr ? Forja.hierro : Forja.acero,
      child: Column(children: [
        if (marco) _barraEstado(),
        if (!qr) _cabeceraApp(so),
        Expanded(
          child: AnimatedSwitcher(
            duration: Mov.medio,
            switchInCurve: Mov.curva,
            transitionBuilder: (child, a) => FadeTransition(
              opacity: a,
              child: SlideTransition(
                position: Tween(begin: const Offset(0.04, 0), end: Offset.zero).animate(a),
                child: child,
              ),
            ),
            child: KeyedSubtree(
              key: ValueKey('$pestana-$socioId-$cargando'),
              child: cargando
                  ? _cargandoClases()
                  : switch (pestana) {
                      0 => _clases(so),
                      1 => _misReservas(so),
                      2 => _qr(so),
                      _ => _avisos(so),
                    },
            ),
          ),
        ),
        _navegacion(so),
      ]),
    );
  }

  Widget _barraEstado() {
    return ExcludeSemantics(
      child: Container(
        color: Forja.hierro,
        padding: const EdgeInsets.fromLTRB(28, 13, 24, 6),
        child: Row(children: [
          Text(hora(DateTime.now()),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white, height: 1)),
          const Spacer(),
          const Icon(Icons.signal_cellular_alt_rounded, size: 15, color: Colors.white),
          const SizedBox(width: 4),
          const Icon(Icons.wifi_rounded, size: 15, color: Colors.white),
          const SizedBox(width: 4),
          const Icon(Icons.battery_full_rounded, size: 15, color: Colors.white),
        ]),
      ),
    );
  }

  Widget _cabeceraApp(Socio so) {
    final titulo = switch (pestana) {
      1 => 'Mis reservas',
      3 => 'Avisos',
      _ => 'Hola, ${so.nombre.split(' ').first}',
    };
    return Container(
      color: Forja.hierro,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              pestana == 0 ? fechaLarga(DateTime.now()).toUpperCase() : 'FORJA TRAINING CLUB',
              style: const TextStyle(
                  color: Forja.grisOscuro, fontSize: 11.5, fontWeight: FontWeight.w600, letterSpacing: 1),
            ),
            const SizedBox(height: 2),
            Semantics(
              header: true,
              child: Text(titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontFamily: Forja.display,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.1)),
            ),
          ]),
        ),
        Tooltip(
          message: '${so.nombre} · tarifa ${so.tarifa.nombre}',
          child: Avatar(so.nombre, tam: 40, fondo: Forja.ascua, color: Forja.hierro),
        ),
      ]),
    );
  }

  Widget _cargandoClases() {
    return Semantics(
      label: 'Cargando las clases',
      child: ListView(
        padding: const EdgeInsets.all(Esp.l),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          const Row(children: [
            Esqueleto(alto: 32, ancho: 64, radio: 16),
            SizedBox(width: Esp.s),
            Esqueleto(alto: 32, ancho: 72, radio: 16),
            SizedBox(width: Esp.s),
            Esqueleto(alto: 32, ancho: 64, radio: 16),
          ]),
          const SizedBox(height: Esp.l),
          for (var i = 0; i < 3; i++)
            const Padding(
              padding: EdgeInsets.only(bottom: Esp.m),
              child: Tarjeta(
                padding: EdgeInsets.all(Esp.l),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Esqueleto(alto: 40, ancho: 48),
                    SizedBox(width: Esp.m),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Esqueleto(alto: 16, ancho: 120),
                        SizedBox(height: Esp.s),
                        Esqueleto(alto: 12, ancho: 90),
                      ]),
                    ),
                  ]),
                  SizedBox(height: Esp.l),
                  Esqueleto(alto: 8),
                  SizedBox(height: Esp.m),
                  Esqueleto(alto: 40, radio: Rad.m),
                ]),
              ),
            ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ Clases

  Widget _clases(Socio so) {
    final ahora = DateTime.now();
    bool terminada(Sesion s) => s.inicio.add(Duration(minutes: s.minutos)).isBefore(ahora);
    final delFiltro = st.sesiones.where((s) => filtro == _Categoria.todas || _categoria(s) == filtro).toList();
    // Primero lo que aún se puede hacer; las clases terminadas, al final.
    final proximas = delFiltro.where((s) => !terminada(s)).toList();
    final pasadas = delFiltro.where(terminada).toList();
    Widget tarjeta(Sesion s) => Padding(
          padding: const EdgeInsets.only(bottom: Esp.m),
          child: _TarjetaClase(
            key: ValueKey('clase-${s.id}'),
            sesion: s,
            socio: so,
            monitor: _monitor(s),
            alReservar: () => _reservar(so, s),
            alCancelar: () => st.cancelar(so.id, s.id),
          ),
        );
    return ListView(
      padding: const EdgeInsets.all(Esp.l),
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final cat in _Categoria.values)
              Padding(
                padding: const EdgeInsets.only(right: Esp.s),
                child: ChoiceChip(
                  label: Text(cat.nombre),
                  selected: filtro == cat,
                  showCheckmark: false,
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                    color: filtro == cat ? Colors.white : Forja.tinta,
                  ),
                  selectedColor: Forja.hierro,
                  backgroundColor: Forja.superficie,
                  side: BorderSide(color: filtro == cat ? Forja.hierro : Forja.linea),
                  shape: const StadiumBorder(),
                  onSelected: (_) => setState(() => filtro = cat),
                ),
              ),
          ]),
        ),
        const SizedBox(height: Esp.m),
        if (so.bloqueado)
          const Padding(
            padding: EdgeInsets.only(bottom: Esp.m),
            child: Nota(
              'Has faltado 3 veces sin avisar este mes. Podrás volver a reservar dentro de 7 días.',
              titulo: 'Reservas en pausa.',
              icono: Icons.lock_clock_outlined,
              color: Forja.rojo,
              fondo: Forja.rojoSuave,
            ),
          )
        else if (so.tarifa == Tarifa.sala)
          const Padding(
            padding: EdgeInsets.only(bottom: Esp.m),
            child: Nota(
              'Incluye la sala de musculación. Para las clases dirigidas, cámbiate a Completa o a un bono en recepción.',
              titulo: 'Tarifa Sala libre.',
            ),
          ),
        if (delFiltro.isEmpty)
          const EstadoVacio(
            icono: Icons.event_busy_outlined,
            titulo: 'No hay clases de este tipo hoy',
            texto: 'Prueba con otra categoría.',
          )
        else if (proximas.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: Esp.m),
            child: Nota(
              'Por hoy ya no quedan clases. El horario de mañana se abre a las 00:00.',
              titulo: 'Fin de la jornada.',
              icono: Icons.nightlight_outlined,
            ),
          ),
        for (final s in proximas) tarjeta(s),
        if (pasadas.isNotEmpty) ...[
          _subtitulo('Ya terminadas', pasadas.length),
          for (final s in pasadas) tarjeta(s),
        ],
      ],
    );
  }

  void _reservar(Socio so, Sesion s) {
    final error = st.reservar(so.id, s.id);
    if (error != null) avisar(ScaffoldMessenger.maybeOf(context), error, error: true);
  }

  String _monitor(Sesion s) {
    for (final e in st.empleados) {
      if (e.nombre.startsWith(s.instructor)) return e.nombre;
    }
    return s.instructor;
  }

  // ---------------------------------------------------------------- Reservas

  Widget _misReservas(Socio so) {
    final confirmadas = st.sesiones.where((s) => s.reservas.contains(so.id)).toList();
    final espera = st.sesiones.where((s) => s.espera.contains(so.id)).toList();
    if (confirmadas.isEmpty && espera.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          child: EstadoVacio(
            icono: Icons.event_available_outlined,
            titulo: 'Aún no tienes reservas',
            texto: 'Elige una clase de hoy y resérvala en un toque.',
            accion: FilledButton.icon(
              onPressed: () => _irA(0),
              icon: const Icon(Icons.calendar_month_rounded, size: 18),
              label: const Text('Ver clases de hoy'),
            ),
          ),
        ),
      );
    }
    Widget tarjeta(Sesion s) => Padding(
          padding: const EdgeInsets.only(bottom: Esp.m),
          child: _TarjetaClase(
            key: ValueKey('reserva-${s.id}'),
            sesion: s,
            socio: so,
            monitor: _monitor(s),
            alReservar: () => _reservar(so, s),
            alCancelar: () => st.cancelar(so.id, s.id),
          ),
        );
    return ListView(
      padding: const EdgeInsets.all(Esp.l),
      children: [
        if (confirmadas.isNotEmpty) ...[
          _subtitulo('Confirmadas', confirmadas.length),
          for (final s in confirmadas) tarjeta(s),
        ],
        if (espera.isNotEmpty) ...[
          _subtitulo('En lista de espera', espera.length),
          for (final s in espera) tarjeta(s),
        ],
        const Nota('Puedes cancelar sin penalización hasta 2 horas antes de la clase.', icono: Icons.schedule_rounded),
      ],
    );
  }

  Widget _subtitulo(String texto, int n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Esp.xs, Esp.xs, Esp.xs, Esp.s),
      child: Text('${texto.toUpperCase()} · $n', style: Txt.etiqueta),
    );
  }

  // ------------------------------------------------------------------ Mi QR

  Widget _qr(Socio so) {
    final restantes = st.segundosRestantesQr();
    final token = st.tokenQr(so.id);
    return LayoutBuilder(builder: (context, c) {
      final lado = (c.maxWidth - 76).clamp(150.0, 260.0);
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Esp.xl, Esp.l, Esp.xl, Esp.l),
        child: Column(children: [
          Semantics(
            header: true,
            child: const Text('Tu pase de entrada',
                style: TextStyle(
                    fontFamily: Forja.display, fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
          const SizedBox(height: 2),
          Text('${so.nombre} · ${so.tarifa.nombre}', style: const TextStyle(color: Forja.grisClaro, fontSize: 14)),
          const SizedBox(height: Esp.l),
          Semantics(
            label: 'Código QR de entrada de ${so.nombre}. Se renueva en $restantes segundos.',
            image: true,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(Rad.xl)),
              child: AnimatedSwitcher(
                duration: Mov.medio,
                transitionBuilder: (child, a) => FadeTransition(
                  opacity: a,
                  child: ScaleTransition(scale: Tween(begin: 0.96, end: 1.0).animate(a), child: child),
                ),
                child: QrImageView(
                  key: ValueKey(token),
                  data: token,
                  size: lado,
                  padding: EdgeInsets.zero,
                  eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Forja.hierro),
                  dataModuleStyle:
                      const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Forja.hierro),
                ),
              ),
            ),
          ),
          const SizedBox(height: Esp.l),
          _cuentaAtras(restantes),
          const SizedBox(height: Esp.l),
          if (!so.cuotaAlDia)
            const Nota(
              'Tienes un recibo pendiente. El torno no se abrirá hasta que lo regularices en recepción.',
              titulo: 'Cuota pendiente.',
              icono: Icons.receipt_long_outlined,
              color: Forja.rojo,
              fondo: Forja.rojoSuave,
            )
          else
            const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.brightness_high_rounded, size: 16, color: Forja.grisOscuro),
              SizedBox(width: 6),
              Flexible(
                child: Text('Sube el brillo y acerca el móvil al lector',
                    style: TextStyle(color: Forja.grisClaro, fontSize: 13)),
              ),
            ]),
        ]),
      );
    });
  }

  Widget _cuentaAtras(int restantes) {
    const total = ForjaStore.segundosQr;
    final urgente = restantes <= 1;
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      SizedBox(
        width: 48,
        height: 48,
        child: Stack(alignment: Alignment.center, children: [
          TweenAnimationBuilder<double>(
            tween: Tween(end: restantes / total),
            duration: restantes == total ? Duration.zero : const Duration(seconds: 1),
            builder: (_, v, __) => SizedBox.expand(
              child: CircularProgressIndicator(
                value: v,
                strokeWidth: 4,
                strokeCap: StrokeCap.round,
                backgroundColor: Forja.hierro3,
                color: urgente ? Forja.ascua : Forja.paja,
              ),
            ),
          ),
          Text('$restantes',
              style: const TextStyle(
                fontFamily: Forja.display,
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                fontFeatures: [FontFeature.tabularFigures()],
              )),
        ]),
      ),
      const SizedBox(width: Esp.m),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(urgente ? 'Cambia ahora' : 'Cambia en $restantes s',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
        const Text('Código nuevo cada $total s: una captura no sirve',
            style: TextStyle(color: Forja.grisOscuro, fontSize: 12.5)),
      ]),
    ]);
  }

  // ----------------------------------------------------------------- Avisos

  Widget _avisos(Socio so) {
    final mios = st.avisos.where((a) => a.socioId == so.id).toList();
    if (mios.isEmpty) {
      return const Center(
        child: SingleChildScrollView(
          child: EstadoVacio(
            icono: Icons.notifications_none_rounded,
            titulo: 'Sin avisos por ahora',
            texto: 'Aquí te avisaremos si se libera una plaza o cambia un horario.',
          ),
        ),
      );
    }
    final n = nuevos[so.id] ?? 0;
    return ListView.separated(
      padding: const EdgeInsets.all(Esp.l),
      itemCount: mios.length,
      separatorBuilder: (_, __) => const SizedBox(height: Esp.s),
      itemBuilder: (_, i) {
        final a = mios[i];
        final plaza = a.texto.startsWith('¡Tienes plaza');
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Duration(milliseconds: 300 + i * 80),
          curve: Mov.curva,
          builder: (_, t, child) => Opacity(
            opacity: t,
            child: Transform.translate(offset: Offset(0, (1 - t) * 12), child: child),
          ),
          child: Tarjeta(
            padding: const EdgeInsets.all(14),
            borde: i < n ? Forja.ascua : Forja.linea,
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: plaza ? Forja.verdeSuave : Forja.ascuaSuave,
                  borderRadius: BorderRadius.circular(Rad.m),
                ),
                child: Icon(plaza ? Icons.event_available_rounded : Icons.campaign_outlined,
                    size: 20, color: plaza ? Forja.verde : Forja.ascuaTexto),
              ),
              const SizedBox(width: Esp.m),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(
                      child: Text(plaza ? 'Plaza confirmada' : 'Mensaje del club',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    ),
                    if (i < n)
                      const Insignia(Estado('Nuevo', Icons.fiber_new_rounded, Forja.ascuaTexto, Forja.ascuaSuave)),
                  ]),
                  const SizedBox(height: 2),
                  Text(a.texto, style: const TextStyle(fontSize: 13.5, height: 1.35)),
                  const SizedBox(height: Esp.xs),
                  Text(haceCuanto(a.momento), style: Txt.secundario.copyWith(fontSize: 12)),
                ]),
              ),
            ]),
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------- navegación

  Widget _navegacion(Socio so) {
    final total = st.avisos.where((a) => a.socioId == so.id).length;
    final sinLeer = pestana == 3 ? 0 : total - (vistos[so.id] ?? 0);
    final qr = pestana == 2;
    return NavigationBarTheme(
      data: NavigationBarThemeData(
        labelTextStyle: WidgetStateProperty.resolveWith((s) {
          final sel = s.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
            color: sel ? (qr ? Colors.white : Forja.tinta) : (qr ? Forja.grisClaro : Forja.gris),
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
              size: 24,
              color: s.contains(WidgetState.selected) ? Forja.ascuaTexto : (qr ? Forja.grisClaro : Forja.gris),
            )),
      ),
      child: NavigationBar(
        height: 66,
        backgroundColor: qr ? Forja.hierro2 : Forja.superficie,
        surfaceTintColor: Colors.transparent,
        indicatorColor: Forja.ascuaSuave,
        selectedIndex: pestana,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: _irA,
        destinations: [
          const NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month_rounded),
              label: 'Clases'),
          const NavigationDestination(
              icon: Icon(Icons.event_available_outlined),
              selectedIcon: Icon(Icons.event_available_rounded),
              label: 'Reservas'),
          const NavigationDestination(icon: Icon(Icons.qr_code_2_rounded), label: 'Mi QR'),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: sinLeer > 0,
              backgroundColor: Forja.ascuaTexto,
              label: Text('$sinLeer'),
              child: const Icon(Icons.notifications_outlined),
            ),
            selectedIcon: const Icon(Icons.notifications_rounded),
            label: 'Avisos',
            tooltip: sinLeer > 0 ? 'Avisos, $sinLeer sin leer' : 'Avisos',
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------ panel de la demo

  Widget _selectorCompacto() {
    return DropdownButtonFormField<int>(
      value: socioId,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Ver la app como', isDense: true),
      items: [
        for (final (id, _) in _personas) DropdownMenuItem(value: id, child: Text(st.socio(id).nombre)),
      ],
      onChanged: (v) => _cambiarSocio(v ?? socioId),
    );
  }

  Widget _panelDemo(Socio so) {
    return ListView(children: [
      Tarjeta(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const TituloBloque('Ver la app como…', apoyo: 'Cada socio enseña un caso distinto.'),
          const SizedBox(height: Esp.m),
          for (final (id, caso) in _personas) _persona(id, caso),
        ]),
      ),
      const SizedBox(height: Esp.l),
      _pruebaGuiada(),
    ]);
  }

  Widget _persona(int id, String caso) {
    final s = st.socio(id);
    final activo = id == socioId;
    return Padding(
      padding: const EdgeInsets.only(bottom: Esp.xs),
      child: Semantics(
        selected: activo,
        button: true,
        child: Material(
          color: activo ? Forja.ascuaSuave : Colors.transparent,
          borderRadius: BorderRadius.circular(Rad.m),
          child: InkWell(
            borderRadius: BorderRadius.circular(Rad.m),
            onTap: () => _cambiarSocio(id),
            child: Padding(
              padding: const EdgeInsets.all(Esp.s),
              child: Row(children: [
                Avatar(s.nombre,
                    tam: 36,
                    fondo: activo ? Forja.ascuaTexto : Forja.acero,
                    color: activo ? Colors.white : Forja.tinta),
                const SizedBox(width: Esp.m),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s.nombre, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
                    Text(caso, style: Txt.secundario.copyWith(fontSize: 12.5)),
                  ]),
                ),
                AnimatedOpacity(
                  duration: Mov.corto,
                  opacity: activo ? 1 : 0,
                  child: const Icon(Icons.check_rounded, color: Forja.ascuaTexto, size: 20),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pruebaGuiada() {
    final ciclo = st.sesion(4);
    final paso1 = !ciclo.reservas.contains(2) && !ciclo.espera.contains(2);
    final paso2 = ciclo.reservas.contains(1);
    final paso3 = paso2 && socioId == 1 && (vistos[1] ?? 0) > 0;
    final enEspera = ciclo.espera.map((id) => st.socio(id).nombre.split(' ').first).join(', ');
    return Tarjeta(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const TituloBloque('Prueba la lista de espera',
            apoyo: 'Cuando alguien cancela, la plaza pasa sola al primero de la lista.'),
        const SizedBox(height: Esp.m),
        Container(
          padding: const EdgeInsets.all(Esp.m),
          decoration: BoxDecoration(color: Forja.acero, borderRadius: BorderRadius.circular(Rad.m)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.directions_bike_rounded, size: 18),
              const SizedBox(width: Esp.s),
              const Expanded(child: Text('Ciclo indoor · 19:00', style: Txt.cuerpoFuerte)),
              Text('${ciclo.reservas.length}/${ciclo.aforo}',
                  style: Txt.hora.copyWith(fontSize: 16, color: ciclo.llena ? Forja.rojo : Forja.tinta)),
            ]),
            const SizedBox(height: Esp.s),
            BarraTemple(ciclo.ocupacion, fondo: Forja.linea),
            const SizedBox(height: Esp.s),
            Text(enEspera.isEmpty ? 'Nadie en lista de espera' : 'En lista de espera: $enEspera',
                style: Txt.secundario),
          ]),
        ),
        const SizedBox(height: Esp.m),
        _paso(1, 'Entra como Marcos y cancela el ciclo de las 19:00.', paso1,
            accion: socioId == 2 ? null : () => _cambiarSocio(2), textoAccion: 'Entrar como Marcos'),
        _paso(2, 'La plaza pasa sola a Lucía, la primera de la lista.', paso2),
        _paso(3, 'Vuelve a Lucía y abre Avisos: tiene la plaza confirmada.', paso3,
            accion: paso2 && socioId != 1 ? () => _cambiarSocio(1) : null, textoAccion: 'Volver a Lucía'),
      ]),
    );
  }

  Widget _paso(int n, String texto, bool hecho, {VoidCallback? accion, String? textoAccion}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Esp.s),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AnimatedContainer(
          duration: Mov.medio,
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: hecho ? Forja.verde : Forja.superficie,
            shape: BoxShape.circle,
            border: Border.all(color: hecho ? Forja.verde : Forja.linea, width: 1.5),
          ),
          child: hecho
              ? const Icon(Icons.check_rounded, size: 16, color: Colors.white, semanticLabel: 'Hecho')
              : Text('$n', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        ),
        const SizedBox(width: Esp.m),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(texto,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.35,
                    color: hecho ? Forja.gris : Forja.tinta,
                    decoration: hecho ? TextDecoration.lineThrough : null,
                    decorationColor: Forja.gris,
                  )),
            ),
            if (accion != null && !hecho)
              Padding(
                padding: const EdgeInsets.only(top: Esp.xs),
                child: OutlinedButton.icon(
                  onPressed: accion,
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 36)),
                  icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                  label: Text(textoAccion ?? ''),
                ),
              ),
          ]),
        ),
      ]),
    );
  }
}

// ---------------------------------------------------------- tarjeta de clase

class _TarjetaClase extends StatefulWidget {
  const _TarjetaClase({
    super.key,
    required this.sesion,
    required this.socio,
    required this.monitor,
    required this.alReservar,
    required this.alCancelar,
  });

  final Sesion sesion;
  final Socio socio;
  final String monitor;
  final VoidCallback alReservar;
  final VoidCallback alCancelar;

  @override
  State<_TarjetaClase> createState() => _TarjetaClaseState();
}

class _TarjetaClaseState extends State<_TarjetaClase> with SingleTickerProviderStateMixin {
  late final AnimationController _pulso = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  late bool _teniaPlaza = _tienePlaza;

  bool get _tienePlaza => widget.sesion.reservas.contains(widget.socio.id);

  @override
  void didUpdateWidget(covariant _TarjetaClase old) {
    super.didUpdateWidget(old);
    final ahora = _tienePlaza;
    // Animación al conseguir plaza (al reservar o al ascender de la lista).
    if (ahora && !_teniaPlaza && old.socio.id == widget.socio.id) _pulso.forward(from: 0);
    _teniaPlaza = ahora;
  }

  @override
  void dispose() {
    _pulso.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.sesion;
    final so = widget.socio;
    final ahora = DateTime.now();
    final fin = s.inicio.add(Duration(minutes: s.minutos));
    final empezada = s.inicio.isBefore(ahora);
    final enCurso = empezada && fin.isAfter(ahora);
    final reservada = s.reservas.contains(so.id);
    final puesto = s.espera.indexOf(so.id) + 1;

    final Estado estado;
    String? textoEstado;
    if (reservada) {
      estado = Estado.reservada;
    } else if (puesto > 0) {
      estado = Estado.espera;
      textoEstado = 'En espera · $puesto.º';
    } else if (enCurso) {
      estado = const Estado('En curso', Icons.play_circle_outline_rounded, Forja.temple, Forja.templeSuave);
    } else if (empezada) {
      estado = Estado.terminada;
    } else if (s.llena) {
      estado = Estado.llena;
      if (s.espera.isNotEmpty) textoEstado = 'Completa · ${s.espera.length} en espera';
    } else if (s.libres <= 3) {
      estado = Estado.ultimas;
      textoEstado = s.libres == 1 ? 'Última plaza' : 'Últimas ${s.libres} plazas';
    } else {
      estado = Estado.libre;
      textoEstado = '${s.libres} plazas libres';
    }

    Widget? accion;
    if (reservada) {
      accion = OutlinedButton.icon(
        key: const ValueKey('cancelar'),
        onPressed: widget.alCancelar,
        style: OutlinedButton.styleFrom(foregroundColor: Forja.rojo),
        icon: const Icon(Icons.close_rounded, size: 18),
        label: const Text('Cancelar reserva'),
      );
    } else if (puesto > 0) {
      accion = OutlinedButton.icon(
        key: const ValueKey('salir'),
        onPressed: widget.alCancelar,
        icon: const Icon(Icons.logout_rounded, size: 18),
        label: const Text('Salir de la lista de espera'),
      );
    } else if (!empezada && s.llena) {
      accion = FilledButton.icon(
        key: const ValueKey('espera'),
        onPressed: widget.alReservar,
        style: FilledButton.styleFrom(backgroundColor: Forja.paja, foregroundColor: Forja.tinta),
        icon: const Icon(Icons.hourglass_top_rounded, size: 18),
        label: const Text('Apuntarme a la lista de espera'),
      );
    } else if (!empezada) {
      accion = FilledButton.icon(
        key: const ValueKey('reservar'),
        onPressed: widget.alReservar,
        icon: const Icon(Icons.add_rounded, size: 18),
        label: const Text('Reservar plaza'),
      );
    }

    if (accion != null) accion = SizedBox(key: accion.key, width: double.infinity, child: accion);

    final atenuada = empezada && !reservada && puesto == 0;

    return AnimatedBuilder(
      animation: _pulso,
      builder: (_, child) {
        final t = _pulso.value;
        final escala = 1 + 0.03 * Curves.easeOut.transform(t < 0.5 ? t * 2 : (1 - t) * 2);
        return Transform.scale(scale: escala, child: child);
      },
      child: Semantics(
        container: true,
        label: '${s.actividad} a las ${hora(s.inicio)} con ${widget.monitor}. '
            '${s.reservas.length} de ${s.aforo} plazas ocupadas. ${textoEstado ?? estado.texto}.',
        child: Tarjeta(
          padding: const EdgeInsets.all(Esp.l),
          // Las clases que ya no admiten reservas se ven apagadas sin perder contraste.
          color: atenuada ? const Color(0xFFF6F7F9) : Forja.superficie,
          borde: reservada ? Forja.verde : Forja.linea,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ExcludeSemantics(
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(
                  width: 56,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(hora(s.inicio), style: Txt.hora.copyWith(fontSize: 21, height: 1)),
                    const SizedBox(height: 3),
                    Text('${s.minutos} min', style: Txt.secundario.copyWith(fontSize: 12)),
                  ]),
                ),
                Container(width: 1, height: 38, color: Forja.linea, margin: const EdgeInsets.only(right: Esp.m)),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(_iconoActividad(s), size: 17, color: Forja.ascuaTexto),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(s.actividad,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontFamily: Forja.display, fontSize: 20, fontWeight: FontWeight.w700, height: 1.1)),
                      ),
                    ]),
                    const SizedBox(height: 3),
                    Row(children: [
                      Avatar(widget.monitor, tam: 20, fondo: Forja.templeSuave, color: Forja.temple),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text('${widget.monitor.split(' ').first} · ${s.sala}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Txt.secundario.copyWith(fontSize: 12.5)),
                      ),
                    ]),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: Esp.m),
            ExcludeSemantics(
              child: Row(children: [
                Expanded(
                  child: Align(alignment: Alignment.centerLeft, child: Insignia(estado, texto: textoEstado)),
                ),
                const SizedBox(width: Esp.s),
                Text('${s.reservas.length}/${s.aforo}',
                    style: Txt.hora.copyWith(fontSize: 15, color: s.llena ? Forja.rojo : Forja.tinta)),
              ]),
            ),
            const SizedBox(height: Esp.s),
            BarraTemple(s.ocupacion, fondo: atenuada ? Forja.linea : Forja.acero),
            if (accion != null) ...[
              const SizedBox(height: Esp.m),
              SizedBox(
                width: double.infinity,
                child: AnimatedSwitcher(
                  duration: Mov.medio,
                  transitionBuilder: (child, a) => FadeTransition(
                    opacity: a,
                    child: ScaleTransition(scale: Tween(begin: 0.92, end: 1.0).animate(a), child: child),
                  ),
                  child: accion,
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}
