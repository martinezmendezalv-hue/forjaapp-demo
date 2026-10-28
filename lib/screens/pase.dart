import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../servicios/api.dart';
import '../servicios/sesion.dart';
import '../theme.dart';

/// Sección «Mi pase» del socio: QR firmado que cambia cada 5 segundos.
/// Lo valida ForjaApp Servidor cuando se lee en el punto de acceso.
class PantallaPase extends StatefulWidget {
  const PantallaPase({super.key, required this.verPlanes});
  final VoidCallback verPlanes;

  @override
  State<PantallaPase> createState() => _PantallaPaseState();
}

class _PantallaPaseState extends State<PantallaPase> {
  late final Timer _reloj;

  @override
  void initState() {
    super.initState();
    _reloj = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _reloj.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final u = sesion.usuario;
    if (u == null) return const SizedBox.shrink();
    final ms = DateTime.now().millisecondsSinceEpoch % (segundosQr * 1000);
    final queda = 1 - ms / (segundosQr * 1000);
    final conPlan = u.plan != null;
    return LayoutBuilder(builder: (context, c) {
      final lado = (c.maxWidth - Esp.xl * 2).clamp(180.0, 300.0);
      return ColoredBox(
        color: Forja.hierro,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Esp.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(u.nombre,
                    textAlign: TextAlign.center, style: Txt.titular.copyWith(color: Colors.white, fontSize: 30)),
                const SizedBox(height: Esp.xs),
                Text(conPlan ? 'Plan ${u.plan![0].toUpperCase()}${u.plan!.substring(1)}' : 'Sin plan',
                    style: const TextStyle(color: Forja.grisClaro, fontSize: 15)),
                const SizedBox(height: Esp.xl),
                Semantics(
                  label: 'Código QR de entrada. Cambia cada $segundosQr segundos.',
                  child: Container(
                    padding: const EdgeInsets.all(Esp.l),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(Rad.l)),
                    child: QrImageView(data: paseQr(u), size: lado, padding: EdgeInsets.zero),
                  ),
                ),
                const SizedBox(height: Esp.l),
                SizedBox(
                  width: lado + Esp.l * 2,
                  child: LinearProgressIndicator(
                    value: queda,
                    minHeight: 4,
                    color: Forja.ascua,
                    backgroundColor: Forja.hierro3,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: Esp.s),
                Text('Cambia en ${(queda * segundosQr).ceil()} s · una captura no sirve',
                    style: const TextStyle(color: Forja.grisOscuro, fontSize: 13)),
                const SizedBox(height: Esp.xl),
                if (!conPlan) ...[
                  const Nota(
                    'Sin un plan el torno no te deja pasar. Elige uno y tu pase empezará a funcionar al momento.',
                    titulo: 'Te falta un plan.',
                    icono: Icons.credit_card_off_outlined,
                    color: Forja.pajaTexto,
                    fondo: Forja.pajaSuave,
                  ),
                  const SizedBox(height: Esp.m),
                  FilledButton.icon(
                    onPressed: widget.verPlanes,
                    icon: const Icon(Icons.workspace_premium_outlined, size: 18),
                    label: const Text('Ver planes'),
                  ),
                ] else
                  const Text('Acerca el móvil al lector del torno.',
                      textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 16)),
              ]),
            ),
          ),
        ),
      );
    });
  }
}
