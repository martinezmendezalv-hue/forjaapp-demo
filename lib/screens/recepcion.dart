import 'package:flutter/material.dart';

import '../data/store.dart';
import '../theme.dart';

class PantallaRecepcion extends StatelessWidget {
  const PantallaRecepcion({super.key, required this.store, this.altas = true});
  final ForjaStore store;

  /// Solo gerencia da de alta socios.
  final bool altas;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => LayoutBuilder(builder: (context, c) {
        final llenas = store.sesiones.where((s) => s.llena).length;
        final indicadores = [
          Indicador(
            valor: '${store.socios.length}',
            texto: 'Socios activos',
            icono: Icons.groups_2_outlined,
            detalle: '${store.inactivos.length} en riesgo de baja',
          ),
          Indicador(
            valor: '${store.entradasHoy}',
            texto: 'Entradas hoy',
            icono: Icons.login_rounded,
            color: Forja.verde,
            detalle: 'Por QR y manuales',
          ),
          Indicador(
            valor: '${(store.ocupacionMedia * 100).round()} %',
            texto: 'Ocupación de clases',
            icono: Icons.local_fire_department_outlined,
            color: Forja.ascuaTexto,
            detalle: '$llenas de ${store.sesiones.length} clases completas',
          ),
          Indicador(
            valor: '${store.enEspera}',
            texto: 'En lista de espera',
            icono: Icons.hourglass_top_rounded,
            color: Forja.pajaTexto,
            detalle: 'Suben solos si alguien cancela',
          ),
        ];
        final alta = FilledButton.icon(
          onPressed: () => _alta(context),
          icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
          label: const Text('Alta de socio'),
        );
        if (c.maxWidth < 1000 || c.maxHeight < 600) {
          // Móvil o ventana pequeña: todo en una columna que se desplaza.
          final w = c.maxWidth < 560 ? c.maxWidth - Esp.l * 2 : (c.maxWidth - Esp.l * 3) / 2;
          return ListView(padding: const EdgeInsets.all(Esp.l), children: [
            if (altas) ...[
              SizedBox(width: double.infinity, child: alta),
              const SizedBox(height: Esp.l),
            ],
            Wrap(spacing: Esp.l, runSpacing: Esp.l, children: [
              for (final i in indicadores) SizedBox(width: w, child: i),
            ]),
            const SizedBox(height: Esp.l),
            _clases(compacto: true),
            const SizedBox(height: Esp.l),
            _inactivos(compacto: true),
            const SizedBox(height: Esp.l),
            _entradas(compacto: true),
          ]);
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(Esp.xxl, Esp.xl, Esp.xxl, Esp.xl),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CabeceraPanel(
              antetitulo: 'Recepción · panel de gerencia',
              titulo: 'Cómo va el club hoy',
              acciones: [if (altas) alta],
            ),
            const SizedBox(height: Esp.xl),
            Row(children: [
              for (final (n, i) in indicadores.indexed) ...[
                if (n > 0) const SizedBox(width: Esp.l),
                Expanded(child: i),
              ],
            ]),
            const SizedBox(height: Esp.l),
            Expanded(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Expanded(flex: 11, child: _clases()),
                const SizedBox(width: Esp.l),
                Expanded(
                  flex: 8,
                  child: Column(children: [
                    Expanded(child: _inactivos()),
                    const SizedBox(height: Esp.l),
                    Expanded(child: _entradas()),
                  ]),
                ),
              ]),
            ),
          ]),
        );
      }),
    );
  }

  /// Lista con separadores: dentro de la tarjeta en escritorio, o entera en el móvil.
  Widget _lista({required bool compacto, required int n, required Widget Function(int) item, required Widget vacio}) {
    if (n == 0) return compacto ? vacio : Expanded(child: Center(child: vacio));
    if (compacto) {
      return Column(children: [
        for (var i = 0; i < n; i++) ...[if (i > 0) const Divider(), item(i)],
      ]);
    }
    return Expanded(
      child: ListView.separated(
          itemCount: n, separatorBuilder: (_, __) => const Divider(), itemBuilder: (_, i) => item(i)),
    );
  }

  // ------------------------------------------------------------ clases

  Widget _clases({bool compacto = false}) {
    return Tarjeta(
      padding: EdgeInsets.fromLTRB(compacto ? Esp.l : Esp.xl, 20, compacto ? Esp.l : Esp.xl, Esp.l),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const TituloBloque('Clases de hoy', apoyo: 'Se actualiza en cuanto un socio reserva o cancela desde la app.'),
        const SizedBox(height: Esp.l),
        if (!compacto)
          const CabeceraTabla(columnas: [
            (70, 'HORA'),
            (null, 'CLASE'),
            (180, 'OCUPACIÓN'),
            (150, 'ESTADO'),
          ]),
        _lista(
          compacto: compacto,
          n: store.sesiones.length,
          item: (i) => _filaClase(store.sesiones[i], compacto: compacto),
          vacio: const SizedBox.shrink(),
        ),
      ]),
    );
  }

  Widget _filaClase(Sesion s, {bool compacto = false}) {
    final ahora = DateTime.now();
    final fin = s.inicio.add(Duration(minutes: s.minutos));
    final Estado estado;
    String? texto;
    if (fin.isBefore(ahora)) {
      estado = Estado.terminada;
    } else if (s.inicio.isBefore(ahora)) {
      estado = const Estado('En curso', Icons.play_circle_outline_rounded, Forja.temple, Forja.templeSuave);
    } else if (s.llena) {
      estado = Estado.llena;
    } else if (s.libres <= 3) {
      estado = Estado.ultimas;
    } else {
      estado = Estado.libre;
      texto = '${s.libres} libres';
    }
    if (compacto) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: Esp.s),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(hora(s.inicio), style: Txt.hora),
            const SizedBox(width: Esp.m),
            Expanded(child: Text(s.actividad, style: Txt.cuerpoFuerte, overflow: TextOverflow.ellipsis)),
            Insignia(estado, texto: texto),
          ]),
          Text('${s.sala} · ${s.instructor} · ${s.minutos} min', style: Txt.secundario),
          const SizedBox(height: Esp.s),
          Row(children: [
            Expanded(child: BarraTemple(s.ocupacion, alto: 7)),
            const SizedBox(width: Esp.m),
            Text('${s.reservas.length}/${s.aforo}${s.espera.isEmpty ? '' : ' · +${s.espera.length} en espera'}',
                style: Txt.secundario.copyWith(color: s.llena ? Forja.rojo : Forja.gris)),
          ]),
        ]),
      );
    }
    return FilaTabla(
      child: Row(children: [
        SizedBox(width: 70, child: Text(hora(s.inicio), style: Txt.hora)),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.actividad, style: Txt.cuerpoFuerte),
            Text('${s.sala} · ${s.instructor} · ${s.minutos} min', style: Txt.secundario),
          ]),
        ),
        SizedBox(
          width: 180,
          child: Padding(
            padding: const EdgeInsets.only(right: Esp.xl),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('${s.reservas.length}/${s.aforo}',
                    style: Txt.hora.copyWith(fontSize: 15, color: s.llena ? Forja.rojo : Forja.tinta)),
                if (s.espera.isNotEmpty) ...[
                  const Spacer(),
                  Text('+${s.espera.length} en espera',
                      style: Txt.secundario.copyWith(fontSize: 12, color: Forja.pajaTexto)),
                ],
              ]),
              const SizedBox(height: 5),
              BarraTemple(s.ocupacion, alto: 7),
            ]),
          ),
        ),
        SizedBox(width: 150, child: Align(alignment: Alignment.centerLeft, child: Insignia(estado, texto: texto))),
      ]),
    );
  }

  // --------------------------------------------------------- inactivos

  Widget _inactivos({bool compacto = false}) {
    final lista = store.inactivos;
    return Tarjeta(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, Esp.m),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TituloBloque(
          'Riesgo de baja',
          apoyo: 'Socios que llevan 21 días o más sin venir.',
          accion: Insignia(Estado('${lista.length}', Icons.trending_down_rounded, Forja.ascuaTexto, Forja.ascuaSuave)),
        ),
        const SizedBox(height: Esp.s),
        _lista(
          compacto: compacto,
          n: lista.length,
          vacio: const EstadoVacio(
            icono: Icons.sentiment_satisfied_alt_rounded,
            titulo: 'Todos vienen a entrenar',
            texto: 'Nadie lleva más de tres semanas sin venir.',
          ),
          item: (i) {
            final s = lista[i];
            final enviado = store.avisos.any((a) => a.socioId == s.id && a.texto.startsWith('Te echamos'));
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: Esp.s),
              child: Row(children: [
                Avatar(s.nombre, tam: 36),
                const SizedBox(width: Esp.m),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s.nombre, style: Txt.cuerpoFuerte, overflow: TextOverflow.ellipsis),
                    Text('${s.diasSinVenir} días sin venir · ${s.tarifa.nombre}', style: Txt.secundario),
                  ]),
                ),
                AnimatedSwitcher(
                  duration: Mov.medio,
                  child: enviado
                      ? const Insignia(
                          Estado('Aviso enviado', Icons.mark_email_read_outlined, Forja.verde, Forja.verdeSuave),
                          key: ValueKey('enviado'),
                        )
                      : OutlinedButton.icon(
                          key: const ValueKey('enviar'),
                          onPressed: () => store.avisarInactivo(s),
                          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 38)),
                          icon: const Icon(Icons.send_rounded, size: 16),
                          label: const Text('Enviar aviso'),
                        ),
                ),
              ]),
            );
          },
        ),
      ]),
    );
  }

  // ---------------------------------------------------------- entradas

  Widget _entradas({bool compacto = false}) {
    final lista = ([...store.accesos]..sort((a, b) => b.momento.compareTo(a.momento))).take(20).toList();
    return Tarjeta(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, Esp.m),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const TituloBloque('Últimas entradas', apoyo: 'Lo que registra el torno, en tiempo real.'),
        const SizedBox(height: Esp.s),
        _lista(
          compacto: compacto,
          n: lista.length,
          vacio: const EstadoVacio(
            icono: Icons.door_front_door_outlined,
            titulo: 'Aún no ha entrado nadie',
            texto: 'Las entradas aparecerán aquí al pasar por el torno.',
          ),
          item: (i) {
            final a = lista[i];
            final e = estadoAcceso(a.resultado);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(color: e.fondo, borderRadius: BorderRadius.circular(Rad.s)),
                  child: Icon(e.icono, size: 18, color: e.color),
                ),
                const SizedBox(width: Esp.m),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(a.socio.nombre, style: Txt.cuerpoFuerte.copyWith(fontSize: 14)),
                    Text(e.texto,
                        style: Txt.secundario.copyWith(fontSize: 12.5, color: a.dentro ? Forja.gris : e.color)),
                  ]),
                ),
                Text(hora(a.momento), style: Txt.hora.copyWith(fontSize: 15)),
              ]),
            );
          },
        ),
      ]),
    );
  }

  // -------------------------------------------------------------- alta

  Future<void> _alta(BuildContext context) async {
    final ctrl = TextEditingController();
    var tarifa = Tarifa.completa;
    String? error;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          void guardar() {
            final nombre = ctrl.text.trim();
            if (nombre.split(' ').where((p) => p.isNotEmpty).length < 2) {
              setSt(() => error = 'Escribe el nombre y al menos un apellido.');
              return;
            }
            store.altaSocio(nombre, tarifa);
            Navigator.pop(ctx);
          }

          return AlertDialog(
            title: const Text('Alta de socio'),
            content: SizedBox(
              width: 460,
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Al terminar, el socio recibe un correo para activar la app.', style: Txt.secundario),
                const SizedBox(height: Esp.l),
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  onChanged: (_) {
                    if (error != null) setSt(() => error = null);
                  },
                  onSubmitted: (_) => guardar(),
                  decoration: InputDecoration(
                    labelText: 'Nombre y apellidos',
                    hintText: 'Por ejemplo, Lucía Gómez',
                    errorText: error,
                    prefixIcon: const Icon(Icons.person_outline_rounded),
                  ),
                ),
                const SizedBox(height: Esp.l),
                const Text('TARIFA', style: Txt.etiqueta),
                const SizedBox(height: Esp.s),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<Tarifa>(
                    segments: [
                      for (final t in Tarifa.values) ButtonSegment(value: t, label: Text(t.nombre)),
                    ],
                    selected: {tarifa},
                    onSelectionChanged: (v) => setSt(() => tarifa = v.first),
                  ),
                ),
                const SizedBox(height: Esp.l),
                const Nota(
                  'El socio acepta la política de privacidad al activar la app. No pedimos datos de salud ni huella.',
                  icono: Icons.shield_outlined,
                ),
              ]),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(Esp.xl, 0, Esp.xl, 20),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              FilledButton(onPressed: guardar, child: const Text('Dar de alta')),
            ],
          );
        },
      ),
    );
  }
}

/// Texto, icono y colores de cada resultado del torno.
Estado estadoAcceso(ResultadoAcceso r) => switch (r) {
      ResultadoAcceso.concedido => const Estado('Entrada con QR', Icons.check_rounded, Forja.verde, Forja.verdeSuave),
      ResultadoAcceso.manual =>
        const Estado('Entrada manual en recepción', Icons.how_to_reg_rounded, Forja.temple, Forja.templeSuave),
      ResultadoAcceso.cuotaPendiente =>
        const Estado('Denegada: cuota pendiente', Icons.block_rounded, Forja.rojo, Forja.rojoSuave),
      ResultadoAcceso.qrCaducado =>
        const Estado('Denegada: QR caducado', Icons.timer_off_outlined, Forja.pajaTexto, Forja.pajaSuave),
    };
