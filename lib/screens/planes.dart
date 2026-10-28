import 'package:flutter/material.dart';

import '../servicios/api.dart';
import '../servicios/sesion.dart';
import '../theme.dart';
import '../widgets/carga.dart';

/// Sección «Planes»: las cuotas del club y la suscripción del socio.
class PantallaPlanes extends StatelessWidget {
  const PantallaPlanes({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      return Cargador<List<Plan>>(
        cargar: sesion.api.planes,
        builder: (context, planes, _) => ListenableBuilder(
          listenable: sesion,
          builder: (context, _) => SingleChildScrollView(
            padding: margenSeccion(c.maxWidth),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (c.maxWidth >= 760) ...[
                const CabeceraPanel(antetitulo: 'Cuotas y suscripción', titulo: 'Elige tu plan'),
                const SizedBox(height: Esp.xl),
              ],
              if (sesion.usuario?.esSocio == true) ...[
                _estado(sesion.usuario, planes),
                const SizedBox(height: Esp.l),
              ],
              ListaPlanes(planes: planes),
              const SizedBox(height: Esp.l),
              const Nota(
                'Contrato mínimo de 52 semanas; después puedes darte de baja avisando con 4 semanas. '
                'En esta demo no se cobra nada: el pago se haría en recepción.',
              ),
            ]),
          ),
        ),
      );
    });
  }

  Widget _estado(Usuario? u, List<Plan> planes) {
    final actual = planes.where((p) => p.id == u?.plan).firstOrNull;
    return actual == null
        ? const Nota(
            'Aún no tienes plan. Elige uno para reservar clases y que el torno te deje entrar.',
            titulo: 'Sin suscripción.',
            icono: Icons.credit_card_off_outlined,
            color: Forja.pajaTexto,
            fondo: Forja.pajaSuave,
          )
        : Nota(
            '${actual.precioTexto} ${actual.periodo}. Puedes cambiar de plan cuando quieras.',
            titulo: 'Tu plan: ${actual.nombre}.',
            icono: Icons.verified_outlined,
            color: Forja.verde,
            fondo: Forja.verdeSuave,
          );
  }
}

/// Las tarjetas de los planes, en fila o en columna según el ancho.
class ListaPlanes extends StatelessWidget {
  const ListaPlanes({super.key, required this.planes, this.alElegir});
  final List<Plan> planes;
  final VoidCallback? alElegir;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final columnas = c.maxWidth >= 900 ? 3 : 1;
      final ancho = columnas == 1 ? c.maxWidth : (c.maxWidth - Esp.l * 2) / 3;
      return Wrap(spacing: Esp.l, runSpacing: Esp.l, children: [
        for (final p in planes) SizedBox(width: ancho, child: _TarjetaPlan(plan: p, alElegir: alElegir)),
      ]);
    });
  }
}

class _TarjetaPlan extends StatelessWidget {
  const _TarjetaPlan({required this.plan, this.alElegir});
  final Plan plan;
  final VoidCallback? alElegir;

  Future<void> _elegir(BuildContext context) async {
    final si = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Plan ${plan.nombre}'),
        content: Text('Te suscribes a ${plan.nombre} por ${plan.precioTexto} ${plan.periodo}.\n\n'
            'En esta demo no se cobra nada: el pago se haría en recepción.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Suscribirme')),
        ],
      ),
    );
    if (si != true || !context.mounted) return;
    final ok = await intentar(context, () async {
      sesion.actualizar(await sesion.api.suscribir(plan.id));
    }, exito: '¡Listo! Ya tienes el plan ${plan.nombre}.');
    if (ok) alElegir?.call();
  }

  @override
  Widget build(BuildContext context) {
    final socio = sesion.usuario?.esSocio == true;
    final mio = socio && sesion.usuario?.plan == plan.id;
    final oscuro = plan.destacado;
    return Tarjeta(
      padding: const EdgeInsets.all(Esp.xl),
      color: oscuro ? Forja.hierro : Forja.superficie,
      borde: mio ? Forja.verde : (oscuro ? Forja.hierro : Forja.linea),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: Esp.s, runSpacing: Esp.s, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text(plan.nombre.toUpperCase(),
              style: TextStyle(
                fontFamily: Forja.display,
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
                color: oscuro ? Colors.white : Forja.tinta,
              )),
          if (mio)
            const Insignia(Estado('Tu plan', Icons.check_rounded, Forja.verde, Forja.verdeSuave))
          else if (oscuro)
            const Insignia(
                Estado('El más elegido', Icons.local_fire_department_outlined, Forja.ascuaTexto, Forja.ascuaSuave)),
        ]),
        const SizedBox(height: Esp.m),
        Text(plan.precioTexto, style: Txt.cifra.copyWith(fontSize: 42, color: oscuro ? Forja.ascua : Forja.tinta)),
        Text(plan.periodo, style: TextStyle(color: oscuro ? Forja.grisClaro : Forja.gris)),
        const SizedBox(height: Esp.l),
        for (final i in plan.incluye)
          Padding(
            padding: const EdgeInsets.only(bottom: Esp.s),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.check_circle_rounded, size: 18, color: oscuro ? Forja.ascua : Forja.verde),
              const SizedBox(width: Esp.s),
              Expanded(
                child:
                    Text(i, style: TextStyle(fontSize: 14.5, height: 1.35, color: oscuro ? Colors.white : Forja.tinta)),
              ),
            ]),
          ),
        if (socio) ...[
          const SizedBox(height: Esp.l),
          SizedBox(
            width: double.infinity,
            child: mio
                ? OutlinedButton.icon(
                    onPressed: null,
                    style: oscuro ? OutlinedButton.styleFrom(disabledForegroundColor: Forja.grisClaro) : null,
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Es tu plan actual'),
                  )
                : FilledButton(
                    onPressed: () => _elegir(context),
                    child: Text(sesion.usuario?.plan == null ? 'Elegir ${plan.nombre}' : 'Cambiar a ${plan.nombre}'),
                  ),
          ),
        ],
      ]),
    );
  }
}

/// Se abre nada más registrarse: «le saltan los planes del gimnasio».
Future<void> mostrarPlanesBienvenida(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      insetPadding: const EdgeInsets.all(Esp.l),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100, maxHeight: 820),
        child: Cargador<List<Plan>>(
          cargar: sesion.api.planes,
          builder: (context, planes, _) => SingleChildScrollView(
            padding: const EdgeInsets.all(Esp.xl),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Text('¡Bienvenido, ${sesion.usuario?.nombre.split(' ').first ?? ''}! Elige tu plan',
                      style: Txt.titular.copyWith(fontSize: 28)),
                ),
                IconButton(
                  tooltip: 'Elegir más tarde',
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close_rounded),
                ),
              ]),
              const SizedBox(height: Esp.xs),
              const Text('Con un plan puedes reservar clases y entrar con tu pase QR. Puedes cambiarlo cuando quieras.',
                  style: Txt.secundario),
              const SizedBox(height: Esp.xl),
              ListaPlanes(planes: planes, alElegir: () => Navigator.pop(ctx)),
              const SizedBox(height: Esp.l),
              Center(child: TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Elegir más tarde'))),
            ]),
          ),
        ),
      ),
    ),
  );
}
