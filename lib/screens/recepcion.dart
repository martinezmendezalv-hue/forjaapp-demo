import 'package:flutter/material.dart';

import '../servicios/sesion.dart' show sesion;
import '../theme.dart';
import '../widgets/carga.dart';

/// Cómo se enseña cada resultado de un intento de entrada.
Estado estadoAcceso(String resultado) => switch (resultado) {
      'concedido' => const Estado('Entró con su QR', Icons.check_circle_outline_rounded, Forja.verde, Forja.verdeSuave),
      'manual' => const Estado('Entrada manual', Icons.how_to_reg_rounded, Forja.temple, Forja.templeSuave),
      'cuotaPendiente' => const Estado('Sin plan: no pasa', Icons.block_rounded, Forja.rojo, Forja.rojoSuave),
      'qrCaducado' => const Estado('QR caducado o repetido', Icons.timer_off_outlined, Forja.pajaTexto, Forja.pajaSuave),
      _ => const Estado('QR no válido', Icons.help_outline_rounded, Forja.gris, Forja.acero),
    };

String nombrePlan(String? plan) => plan == null ? 'Sin plan' : plan[0].toUpperCase() + plan.substring(1);

/// Hora local de una fecha ISO del servidor.
String horaDe(Object? iso) {
  final t = DateTime.tryParse(iso is String ? iso : '');
  return t == null ? '' : hora(t.toLocal());
}

/// Recepción con los datos reales del servidor: los socios que se han
/// registrado y quién ha entrado hoy.
class PantallaRecepcion extends StatelessWidget {
  const PantallaRecepcion({super.key});

  @override
  Widget build(BuildContext context) {
    return Cargador<Map<String, dynamic>>(
      cargar: sesion.api.recepcion,
      builder: (context, d, recargar) => _Contenido(d, recargar),
    );
  }
}

class _Contenido extends StatefulWidget {
  const _Contenido(this.d, this.recargar);
  final Map<String, dynamic> d;
  final Future<void> Function() recargar;

  @override
  State<_Contenido> createState() => _ContenidoState();
}

class _ContenidoState extends State<_Contenido> {
  String filtro = '';

  Map<String, dynamic> get resumen => widget.d['resumen'] as Map<String, dynamic>;
  List<Map<String, dynamic>> get socios => (widget.d['socios'] as List).cast<Map<String, dynamic>>();
  List<Map<String, dynamic>> get accesos => (widget.d['accesos'] as List).cast<Map<String, dynamic>>();

  Future<void> _entrada(Map<String, dynamic> s) async {
    Map<String, dynamic>? r;
    final ok = await intentar(context, () async => r = await sesion.api.accesoManual(s['id'] as int));
    if (!ok || !mounted) return;
    final paso = r!['resultado'] == 'manual';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(paso
          ? 'Entrada registrada: ${s['nombre']}.'
          : '${s['nombre']} no tiene plan: no puede entrar hasta que se suscriba.'),
    ));
    await widget.recargar();
  }

  @override
  Widget build(BuildContext context) {
    final sinPlan = (resumen['socios'] as int) - (resumen['conPlan'] as int);
    final indicadores = [
      Indicador(
        valor: '${resumen['socios']}',
        texto: 'Socios',
        icono: Icons.groups_2_outlined,
        detalle: 'Cuentas registradas',
      ),
      Indicador(
        valor: '${resumen['conPlan']}',
        texto: 'Con plan',
        icono: Icons.workspace_premium_outlined,
        color: Forja.ascuaTexto,
        detalle: '$sinPlan sin plan',
      ),
      Indicador(
        valor: '${resumen['entradasHoy']}',
        texto: 'Entradas hoy',
        icono: Icons.login_rounded,
        color: Forja.verde,
        detalle: '${resumen['personasHoy']} personas distintas',
      ),
      Indicador(
        valor: '${resumen['rechazosHoy']}',
        texto: 'No pasaron hoy',
        icono: Icons.block_rounded,
        color: Forja.rojo,
        detalle: 'Sin plan o QR caducado',
      ),
    ];
    final actualizar = OutlinedButton.icon(
      onPressed: widget.recargar,
      icon: const Icon(Icons.refresh_rounded, size: 20),
      label: const Text('Actualizar'),
    );

    return LayoutBuilder(builder: (context, c) {
      final ancho = c.maxWidth;
      if (ancho < 1000) {
        final w = ancho < 560 ? ancho - Esp.l * 2 : (ancho - Esp.l * 3) / 2;
        return RefreshIndicator(
          onRefresh: widget.recargar,
          child: ListView(padding: margenSeccion(ancho), children: [
            Row(children: [
              const Expanded(child: Text('Cómo va el club hoy', style: Txt.titular)),
              actualizar,
            ]),
            const SizedBox(height: Esp.l),
            Wrap(spacing: Esp.l, runSpacing: Esp.l, children: [
              for (final i in indicadores) SizedBox(width: w, child: i),
            ]),
            const SizedBox(height: Esp.l),
            _entradas(),
            const SizedBox(height: Esp.l),
            _socios(),
          ]),
        );
      }
      return Padding(
        padding: margenSeccion(ancho),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CabeceraPanel(antetitulo: 'Recepción', titulo: 'Cómo va el club hoy', acciones: [actualizar]),
          const SizedBox(height: Esp.xl),
          Row(children: [
            for (final (i, ind) in indicadores.indexed) ...[
              if (i > 0) const SizedBox(width: Esp.l),
              Expanded(child: ind),
            ],
          ]),
          const SizedBox(height: Esp.l),
          Expanded(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(flex: 3, child: SingleChildScrollView(child: _socios())),
              const SizedBox(width: Esp.l),
              Expanded(flex: 2, child: SingleChildScrollView(child: _entradas())),
            ]),
          ),
        ]),
      );
    });
  }

  Widget _entradas() {
    return Tarjeta(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, Esp.s),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const TituloBloque('Entradas de hoy', apoyo: 'Por el torno con su QR o registradas a mano.'),
        const SizedBox(height: Esp.m),
        if (accesos.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: Esp.m),
            child: Text('Hoy todavía no ha entrado nadie.', style: Txt.secundario),
          ),
        for (final a in accesos)
          Padding(
            padding: const EdgeInsets.only(bottom: Esp.m),
            child: Row(children: [
              Icon(estadoAcceso(a['resultado'] as String).icono, size: 18, color: estadoAcceso(a['resultado'] as String).color),
              const SizedBox(width: Esp.s),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(a['nombre'] as String? ?? 'Pase desconocido', style: Txt.cuerpoFuerte.copyWith(fontSize: 14)),
                  Text(estadoAcceso(a['resultado'] as String).texto, style: Txt.secundario.copyWith(fontSize: 12.5)),
                ]),
              ),
              Text(horaDe(a['fecha']), style: Txt.secundario.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
            ]),
          ),
      ]),
    );
  }

  Widget _socios() {
    final f = filtro.trim().toLowerCase();
    final lista = socios
        .where((s) => f.isEmpty || '${s['nombre']} ${s['email']}'.toLowerCase().contains(f))
        .toList();
    return Tarjeta(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, Esp.s),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const TituloBloque('Socios', apoyo: 'Las personas que se han registrado en la app.'),
        const SizedBox(height: Esp.m),
        if (socios.isEmpty)
          const EstadoVacio(
            icono: Icons.person_search_outlined,
            titulo: 'Todavía no hay socios',
            texto: 'Cuando alguien se registre en la app aparecerá aquí, con su plan y su última entrada.',
          )
        else ...[
          TextField(
            onChanged: (v) => setState(() => filtro = v),
            decoration: const InputDecoration(labelText: 'Buscar por nombre o correo', prefixIcon: Icon(Icons.search_rounded)),
          ),
          const SizedBox(height: Esp.m),
          if (lista.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: Esp.m),
              child: Text('Nadie coincide con la búsqueda.', style: Txt.secundario),
            ),
          for (final s in lista) _filaSocio(s),
        ],
      ]),
    );
  }

  Widget _filaSocio(Map<String, dynamic> s) {
    final plan = s['plan'] as String?;
    final ultima = DateTime.tryParse(s['ultimaEntrada'] as String? ?? '');
    return Padding(
      padding: const EdgeInsets.only(bottom: Esp.m),
      child: Row(children: [
        Avatar(s['nombre'] as String),
        const SizedBox(width: Esp.m),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s['nombre'] as String, style: Txt.cuerpoFuerte, overflow: TextOverflow.ellipsis),
            Text(
              ultima == null ? 'Todavía no ha entrado' : 'Última entrada: ${haceCuanto(ultima.toLocal())}',
              style: Txt.secundario.copyWith(fontSize: 12.5),
              overflow: TextOverflow.ellipsis,
            ),
          ]),
        ),
        const SizedBox(width: Esp.s),
        Insignia(
          plan == null
              ? const Estado('Sin plan', Icons.block_rounded, Forja.rojo, Forja.rojoSuave)
              : const Estado('', Icons.workspace_premium_outlined, Forja.verde, Forja.verdeSuave),
          texto: nombrePlan(plan),
        ),
        IconButton(
          tooltip: 'Registrar entrada manual',
          onPressed: () => _entrada(s),
          icon: const Icon(Icons.how_to_reg_rounded),
        ),
      ]),
    );
  }
}
