import 'package:flutter/material.dart';

import '../data/store.dart';
import '../theme.dart';

class PantallaAcceso extends StatefulWidget {
  const PantallaAcceso({super.key, required this.store});
  final ForjaStore store;

  @override
  State<PantallaAcceso> createState() => _PantallaAccesoState();
}

class _PantallaAccesoState extends State<PantallaAcceso> {
  Acceso? ultimo;
  int manualId = 5;

  ForjaStore get st => widget.store;

  void _leer(String token) {
    setState(() => ultimo = st.validarQr(token));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: st,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.fromLTRB(36, 30, 36, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Cabecera(
              etiqueta: 'PUNTO DE ACCESO · TABLET DE ENTRADA',
              titulo: 'El socio enseña el QR y el torno se abre',
              subtitulo: 'sin huella dactilar y sin depender del PC viejo',
              colorEtiqueta: Forja.amarillo,
              colorSubtitulo: Forja.ocre,
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 5, child: _tablet()),
                const SizedBox(width: 22),
                Expanded(flex: 4, child: _simulador()),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tablet() {
    final r = ultimo;
    final (Color fondo, Color texto, IconData icono, String titulo, String detalle) = switch (r?.resultado) {
      null => (Forja.marino, Colors.white, Icons.qr_code_scanner_rounded, 'Acerca tu QR',
          'Abre ForjaApp y enseña tu pase al lector'),
      ResultadoAcceso.concedido => (Forja.verde, Colors.white, Icons.check_circle_rounded,
          'Adelante, ${r!.socio.nombre.split(' ').first}', 'Torno abierto · ${horaSeg(r!.momento)}'),
      ResultadoAcceso.manual => (Forja.verde, Colors.white, Icons.how_to_reg_rounded,
          'Entrada registrada', '${r!.socio.nombre} · registrada por recepción'),
      ResultadoAcceso.cuotaPendiente => (Forja.rojo, Colors.white, Icons.cancel_rounded, 'Cuota pendiente',
          '${r!.socio.nombre}: pasa por recepción, por favor'),
      ResultadoAcceso.qrCaducado => (Forja.amarillo, Forja.marino, Icons.timer_off_outlined, 'Código caducado',
          'Ese QR ya no vale. Abre la app y enséñalo de nuevo'),
    };
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF2C3A5E),
        borderRadius: BorderRadius.circular(32),
        boxShadow: const [BoxShadow(color: Color(0x331F2A44), blurRadius: 30, offset: Offset(0, 14))],
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(20)),
        child: Stack(children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(icono, size: 130, color: texto),
                const SizedBox(height: 18),
                Text(titulo,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: texto)),
                const SizedBox(height: 8),
                Text(detalle, textAlign: TextAlign.center, style: TextStyle(fontSize: 18, color: texto)),
              ]),
            ),
          ),
          Positioned(
            left: 20,
            top: 16,
            child: Text('Forja Training Club · ${hora(DateTime.now())}',
                style: TextStyle(color: texto, fontWeight: FontWeight.w700)),
          ),
          if (r != null)
            Positioned(
              right: 12,
              top: 8,
              child: TextButton(
                onPressed: () => setState(() => ultimo = null),
                style: TextButton.styleFrom(foregroundColor: texto),
                child: const Text('Siguiente'),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _simulador() {
    final ventanaAnterior = st.ventanaActual() - 1;
    return ListView(children: [
      Tarjeta(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Simular un socio en la puerta', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('Cada botón «acerca» el QR que tiene ahora ese socio en su móvil.',
              style: TextStyle(color: Forja.gris)),
          const SizedBox(height: 12),
          _boton('Lucía Gómez', 'cuota al día', Icons.check_rounded, Forja.turquesaSuave, Forja.verde,
              () => _leer(st.tokenQr(1))),
          _boton('Raúl Fernández', 'recibo devuelto', Icons.receipt_long_outlined, Forja.coralSuave, Forja.rojo,
              () => _leer(st.tokenQr(7))),
          _boton('Captura antigua de Marcos', 'QR de hace más de 30 s', Icons.screenshot_outlined,
              Forja.amarilloSuave, Forja.ocre, () => _leer(st.tokenQr(2, ventanaAnterior))),
        ]),
      ),
      const SizedBox(height: 16),
      Tarjeta(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Sin móvil o sin Internet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('Recepción registra la entrada a mano y se sincroniza después (RNF-04).',
              style: TextStyle(color: Forja.gris, height: 1.4)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                value: manualId,
                decoration: const InputDecoration(labelText: 'Socio', border: OutlineInputBorder()),
                items: [
                  for (final s in st.socios) DropdownMenuItem(value: s.id, child: Text(s.nombre)),
                ],
                onChanged: (v) => setState(() => manualId = v ?? manualId),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: () => setState(() => ultimo = st.entradaManual(manualId)),
              style: FilledButton.styleFrom(backgroundColor: Forja.marino),
              child: const Text('Registrar'),
            ),
          ]),
        ]),
      ),
      const SizedBox(height: 16),
      const Nota('Por qué QR y no huella:',
          'la AEPD multó con 27.000 € a un gimnasio por exigir la huella para entrar. El QR identifica igual y no trata datos biométricos.'),
    ]);
  }

  Widget _boton(String titulo, String sub, IconData icono, Color fondo, Color color, VoidCallback alPulsar) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: fondo,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: alPulsar,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Icon(icono, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(titulo, style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text(sub, style: const TextStyle(fontSize: 12, color: Forja.gris)),
                ]),
              ),
              Icon(Icons.qr_code_2_rounded, color: color),
            ]),
          ),
        ),
      ),
    );
  }
}
