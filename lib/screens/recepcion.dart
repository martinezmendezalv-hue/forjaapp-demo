import 'package:flutter/material.dart';

import '../data/store.dart';
import '../theme.dart';

class PantallaRecepcion extends StatelessWidget {
  const PantallaRecepcion({super.key, required this.store});
  final ForjaStore store;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.fromLTRB(36, 30, 36, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Cabecera(
              etiqueta: 'PANEL WEB · RECEPCIÓN Y GERENCIA',
              titulo: 'Cómo va el gimnasio hoy',
              subtitulo: 'lo que hoy está en un Excel y un WhatsApp',
              colorEtiqueta: Forja.turquesa,
              colorSubtitulo: Forja.verde,
              accion: FilledButton.icon(
                onPressed: () => _alta(context),
                style: FilledButton.styleFrom(backgroundColor: Forja.marino),
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('Alta de socio'),
              ),
            ),
            const SizedBox(height: 20),
            Row(children: [
              _kpi('${store.socios.length}', 'socios en la demo', Icons.groups_2_outlined, Forja.coralSuave, Forja.rojo),
              const SizedBox(width: 16),
              _kpi('${store.entradasHoy}', 'entradas hoy', Icons.login_rounded, Forja.turquesaSuave, Forja.verde),
              const SizedBox(width: 16),
              _kpi('${(store.ocupacionMedia * 100).round()} %', 'ocupación media de clases', Icons.donut_large_rounded,
                  Forja.amarilloSuave, Forja.ocre),
              const SizedBox(width: 16),
              _kpi('${store.enEspera}', 'personas en lista de espera', Icons.hourglass_top_rounded, Forja.moradoSuave,
                  Forja.morado),
            ]),
            const SizedBox(height: 18),
            Expanded(
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 5, child: _clases()),
                const SizedBox(width: 18),
                Expanded(
                  flex: 4,
                  child: Column(children: [
                    Expanded(child: _inactivos()),
                    const SizedBox(height: 18),
                    Expanded(child: _entradas()),
                  ]),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kpi(String valor, String texto, IconData icono, Color fondo, Color color) {
    return Expanded(
      child: Tarjeta(
        child: Row(children: [
          IconoCirculo(icono, fondo: fondo, color: color, tam: 46),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(valor, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: color)),
              Text(texto, style: const TextStyle(color: Forja.gris, fontSize: 13)),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _clases() {
    return Tarjeta(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Ocupación de las clases de hoy', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const Text('Se actualiza sola cuando un socio reserva o cancela desde la app.',
            style: TextStyle(color: Forja.gris)),
        const SizedBox(height: 14),
        Expanded(
          child: ListView.separated(
            itemCount: store.sesiones.length,
            separatorBuilder: (_, __) => const Divider(height: 18, color: Forja.linea),
            itemBuilder: (_, i) {
              final s = store.sesiones[i];
              final color = s.ocupacion >= 1
                  ? Forja.coral
                  : s.ocupacion >= 0.75
                      ? Forja.amarillo
                      : Forja.turquesa;
              return Row(children: [
                SizedBox(
                  width: 56,
                  child: Text(hora(s.inicio), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                ),
                SizedBox(
                  width: 170,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s.actividad, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text('${s.sala} · ${s.instructor}', style: const TextStyle(fontSize: 12, color: Forja.gris)),
                  ]),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: s.ocupacion.clamp(0, 1).toDouble(),
                      minHeight: 14,
                      backgroundColor: Forja.linea,
                      color: color,
                    ),
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: Text(
                    '${s.reservas.length}/${s.aforo}${s.espera.isNotEmpty ? ' · ${s.espera.length} en espera' : ''}',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontWeight: FontWeight.w700, color: s.llena ? Forja.rojo : Forja.marino),
                  ),
                ),
              ]);
            },
          ),
        ),
        const SizedBox(height: 10),
        const Nota('Para la gerencia:', 'en verde hay sitio, en amarillo casi llena, en rojo completa.'),
      ]),
    );
  }

  Widget _inactivos() {
    final lista = store.inactivos;
    return Tarjeta(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(
            child: Text('Socios que llevan 21 días sin venir', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          ),
          Pildora('${lista.length}', fondo: Forja.coral),
        ]),
        const SizedBox(height: 4),
        const Text('Los que más fácil se dan de baja.', style: TextStyle(color: Forja.gris, fontSize: 13)),
        const SizedBox(height: 8),
        Expanded(
          child: lista.isEmpty
              ? const Center(child: Text('Nadie. ¡Bien!'))
              : ListView(
                  children: [
                    for (final s in lista)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: Forja.coralSuave,
                          child: Text(s.iniciales, style: const TextStyle(color: Forja.rojo, fontWeight: FontWeight.w700)),
                        ),
                        title: Text(s.nombre, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text('${s.diasSinVenir} días · ${s.tarifa.nombre}'),
                        trailing: TextButton(
                          onPressed: () => store.avisarInactivo(s),
                          child: const Text('Enviar aviso'),
                        ),
                      ),
                  ],
                ),
        ),
      ]),
    );
  }

  Widget _entradas() {
    return Tarjeta(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Últimas entradas', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Expanded(
          child: ListView(
            children: [
              for (final a in store.accesos.take(12))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(children: [
                    Icon(
                      a.dentro ? Icons.check_circle_rounded : Icons.cancel_rounded,
                      color: a.dentro ? Forja.verde : Forja.rojo,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(a.socio.nombre, style: const TextStyle(fontWeight: FontWeight.w600))),
                    Text(_resultado(a.resultado), style: const TextStyle(fontSize: 12, color: Forja.gris)),
                    const SizedBox(width: 12),
                    Text(hora(a.momento), style: const TextStyle(fontWeight: FontWeight.w700)),
                  ]),
                ),
            ],
          ),
        ),
      ]),
    );
  }

  static String _resultado(ResultadoAcceso r) => switch (r) {
        ResultadoAcceso.concedido => 'QR',
        ResultadoAcceso.manual => 'manual',
        ResultadoAcceso.cuotaPendiente => 'cuota pendiente',
        ResultadoAcceso.qrCaducado => 'QR caducado',
      };

  Future<void> _alta(BuildContext context) async {
    final ctrl = TextEditingController();
    var tarifa = Tarifa.completa;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          backgroundColor: Forja.tarjeta,
          title: const Text('Alta de socio'),
          content: SizedBox(
            width: 420,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextField(
                controller: ctrl,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Nombre y apellidos'),
              ),
              const SizedBox(height: 16),
              SegmentedButton<Tarifa>(
                segments: [
                  for (final t in Tarifa.values) ButtonSegment(value: t, label: Text(t.nombre)),
                ],
                selected: {tarifa},
                onSelectionChanged: (v) => setSt(() => tarifa = v.first),
              ),
              const SizedBox(height: 16),
              const Nota('Protección de datos:',
                  'el socio acepta la política de privacidad al activar la app. No se piden datos de salud.'),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                if (ctrl.text.trim().isEmpty) return;
                store.altaSocio(ctrl.text.trim(), tarifa);
                Navigator.pop(ctx);
              },
              child: const Text('Dar de alta'),
            ),
          ],
        ),
      ),
    );
  }
}
