import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../data/store.dart';
import '../theme.dart';

class PantallaSocio extends StatefulWidget {
  const PantallaSocio({super.key, required this.store});
  final ForjaStore store;

  @override
  State<PantallaSocio> createState() => _PantallaSocioState();
}

class _PantallaSocioState extends State<PantallaSocio> {
  int socioId = 1; // Lucía, primera en la lista de espera de las 19:00
  int pestana = 0;

  ForjaStore get st => widget.store;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: st,
      builder: (context, _) {
        final so = st.socio(socioId);
        return Padding(
          padding: const EdgeInsets.fromLTRB(36, 30, 36, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Cabecera(
                etiqueta: 'APP DEL SOCIO · ANDROID E iOS',
                titulo: 'Reservar una clase en tres toques',
                subtitulo: 'así lo ve el socio en su móvil',
              ),
              const SizedBox(height: 20),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _movil(so),
                    const SizedBox(width: 28),
                    Expanded(child: _ladoDerecho(so)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --------------------------------------------------------------- móvil

  Widget _movil(Socio so) {
    return Container(
      width: 380,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Forja.marino,
        borderRadius: BorderRadius.circular(44),
        boxShadow: const [BoxShadow(color: Color(0x331F2A44), blurRadius: 30, offset: Offset(0, 14))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(34),
        child: Container(
          color: Forja.crema,
          child: Column(
            children: [
              _barraEstado(),
              _cabeceraApp(so),
              Expanded(
                child: switch (pestana) {
                  0 => _clases(so),
                  1 => _misReservas(so),
                  2 => _qr(so),
                  _ => _avisos(so),
                },
              ),
              _navegacion(so),
            ],
          ),
        ),
      ),
    );
  }

  Widget _barraEstado() {
    final ahora = DateTime.now();
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 4),
      child: Row(children: [
        Text(hora(ahora), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        const Spacer(),
        const Icon(Icons.signal_cellular_alt, size: 15),
        const SizedBox(width: 4),
        const Icon(Icons.wifi, size: 15),
        const SizedBox(width: 4),
        const Icon(Icons.battery_5_bar, size: 15),
      ]),
    );
  }

  Widget _cabeceraApp(Socio so) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 10),
      child: Row(children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: Forja.coral,
          child: Text(so.iniciales, style: const TextStyle(color: Forja.marino, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Hola, ${so.nombre.split(' ').first}',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            Text('Tarifa ${so.tarifa.nombre}', style: const TextStyle(fontSize: 12, color: Forja.gris)),
          ]),
        ),
        const Icon(Icons.fitness_center_rounded, color: Forja.rojo),
      ]),
    );
  }

  Widget _clases(Socio so) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 4, 4, 8),
          child: Text('Clases de hoy', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        ),
        if (so.bloqueado)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Nota('Reservas bloqueadas:', '3 ausencias sin avisar este mes. Se desbloquean en 7 días.',
                fondo: Forja.coralSuave),
          ),
        for (final s in st.sesiones) _tarjetaClase(so, s),
      ],
    );
  }

  Widget _tarjetaClase(Socio so, Sesion s) {
    final reservada = s.reservas.contains(so.id);
    final puestoEspera = s.espera.indexOf(so.id) + 1;
    final pasada = s.inicio.isBefore(DateTime.now());
    Widget boton;
    if (reservada) {
      boton = OutlinedButton(
        onPressed: () => st.cancelar(so.id, s.id),
        style: OutlinedButton.styleFrom(foregroundColor: Forja.rojo, side: const BorderSide(color: Forja.coral)),
        child: const Text('Cancelar'),
      );
    } else if (puestoEspera > 0) {
      boton = OutlinedButton(
        onPressed: () => st.cancelar(so.id, s.id),
        child: Text('En espera ($puestoEspera.º)'),
      );
    } else {
      boton = FilledButton(
        onPressed: pasada
            ? null
            : () {
                final error = st.reservar(so.id, s.id);
                if (error != null) _aviso(error);
              },
        style: FilledButton.styleFrom(
          backgroundColor: s.llena ? Forja.amarillo : Forja.marino,
          foregroundColor: s.llena ? Forja.marino : Colors.white,
        ),
        child: Text(s.llena ? 'Lista de espera' : 'Reservar'),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Tarjeta(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Container(
            width: 54,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: reservada ? Forja.turquesaSuave : Forja.coralSuave,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(hora(s.inicio),
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.actividad, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              Text(
                pasada
                    ? 'Terminada'
                    : s.llena
                        ? 'Completa · ${s.espera.length} en espera'
                        : '${s.libres} plazas libres · ${s.instructor}',
                style: TextStyle(fontSize: 12, color: s.llena ? Forja.rojo : Forja.gris),
              ),
            ]),
          ),
          boton,
        ]),
      ),
    );
  }

  Widget _misReservas(Socio so) {
    final mias = st.sesiones.where((s) => s.reservas.contains(so.id) || s.espera.contains(so.id)).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 4, 4, 8),
          child: Text('Mis reservas', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        ),
        if (mias.isEmpty)
          const Nota('Nada por aquí.', 'Reserva una clase desde la pestaña Clases.')
        else
          for (final s in mias) _tarjetaClase(so, s),
        const SizedBox(height: 6),
        const Nota('Recuerda:', 'puedes cancelar sin penalización hasta 2 horas antes de la clase.'),
      ],
    );
  }

  Widget _qr(Socio so) {
    final restantes = st.segundosRestantesQr();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
      child: Column(
        children: [
          const Text('Tu pase de entrada', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Tarjeta(
            padding: const EdgeInsets.all(14),
            child: QrImageView(
              data: st.tokenQr(so.id),
              size: 210,
              eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Forja.marino),
              dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Forja.marino),
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: restantes / 30,
              minHeight: 8,
              backgroundColor: Forja.coralSuave,
              color: Forja.coral,
            ),
          ),
          const SizedBox(height: 6),
          Text('Cambia en $restantes s', style: const TextStyle(fontSize: 12, color: Forja.gris)),
          const SizedBox(height: 12),
          const Nota('¿Por qué cambia?', 'Así una captura de pantalla deja de servir enseguida. Nada de huella dactilar.'),
          if (!so.cuotaAlDia) ...[
            const SizedBox(height: 8),
            const Nota('Cuota pendiente:', 'pásate por recepción para regularizar el recibo.', fondo: Forja.coralSuave),
          ],
        ],
      ),
    );
  }

  Widget _avisos(Socio so) {
    final mios = st.avisos.where((a) => a.socioId == so.id).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 4, 4, 8),
          child: Text('Avisos', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        ),
        if (mios.isEmpty) const Nota('Sin avisos.', 'Aquí llegan las plazas liberadas y los cambios de horario.'),
        for (final a in mios)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Tarjeta(
              padding: const EdgeInsets.all(12),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const IconoCirculo(Icons.notifications_active_outlined,
                    fondo: Forja.amarilloSuave, color: Forja.ocre, tam: 34),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(a.texto, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(hora(a.momento), style: const TextStyle(fontSize: 11, color: Forja.gris)),
                  ]),
                ),
              ]),
            ),
          ),
      ],
    );
  }

  Widget _navegacion(Socio so) {
    final noLeidos = st.avisos.where((a) => a.socioId == so.id).length;
    return NavigationBar(
      height: 64,
      backgroundColor: Forja.tarjeta,
      indicatorColor: Forja.coralSuave,
      selectedIndex: pestana,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      onDestinationSelected: (i) => setState(() => pestana = i),
      destinations: [
        const NavigationDestination(icon: Icon(Icons.calendar_month_outlined), label: 'Clases'),
        const NavigationDestination(icon: Icon(Icons.event_available_outlined), label: 'Reservas'),
        const NavigationDestination(icon: Icon(Icons.qr_code_2_rounded), label: 'Mi QR'),
        NavigationDestination(
          icon: Badge(
            isLabelVisible: noLeidos > 0,
            label: Text('$noLeidos'),
            child: const Icon(Icons.notifications_outlined),
          ),
          label: 'Avisos',
        ),
      ],
    );
  }

  // ------------------------------------------------------- lado derecho

  Widget _ladoDerecho(Socio so) {
    final ciclo = st.sesion(4);
    return ListView(
      children: [
        Tarjeta(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Ver la app como…', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('Cambia de socio para probar cada caso.', style: TextStyle(color: Forja.gris)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final id in [1, 2, 3, 7, 10])
                  ChoiceChip(
                    label: Text(st.socio(id).nombre),
                    selected: socioId == id,
                    selectedColor: Forja.coralSuave,
                    onSelected: (_) => setState(() {
                      socioId = id;
                      pestana = 0;
                    }),
                  ),
              ],
            ),
          ]),
        ),
        const SizedBox(height: 16),
        Tarjeta(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const IconoCirculo(Icons.swap_horiz_rounded),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Prueba la lista de espera', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ),
              Pildora('RF-04', fondo: Forja.amarillo),
            ]),
            const SizedBox(height: 10),
            Text(
              'El ciclo de las 19:00 está lleno (${ciclo.reservas.length}/${ciclo.aforo}). '
              'En espera: ${ciclo.espera.isEmpty ? 'nadie' : ciclo.espera.map((id) => st.socio(id).nombre).join(', ')}.',
              style: const TextStyle(height: 1.4),
            ),
            const SizedBox(height: 12),
            const Text(
              '1. Entra como Marcos Herrero y cancela su clase de las 19:00.\n'
              '2. La plaza pasa sola a Lucía Gómez, la primera de la lista.\n'
              '3. Vuelve a Lucía: le ha llegado un aviso y ya tiene la reserva.',
              style: TextStyle(height: 1.6),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Tarjeta(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const IconoCirculo(Icons.block_rounded, fondo: Forja.moradoSuave, color: Forja.morado),
                const SizedBox(height: 10),
                const Text('Pablo Ruiz', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                const Text('Tiene 3 ausencias este mes: no puede reservar durante 7 días (RF-06).',
                    style: TextStyle(color: Forja.gris, height: 1.4)),
              ]),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Tarjeta(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const IconoCirculo(Icons.receipt_long_outlined, fondo: Forja.turquesaSuave, color: Forja.verde),
                const SizedBox(height: 10),
                const Text('Raúl Fernández', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                const Text('Recibo devuelto: su QR funciona, pero el torno no le abre. Pruébalo en Punto de acceso.',
                    style: TextStyle(color: Forja.gris, height: 1.4)),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 16),
        const Nota('En el proyecto real:',
            'esta app se hace en Flutter para Android e iOS y habla con la API REST (Spring Boot) por HTTPS.'),
      ],
    );
  }

  void _aviso(String texto) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto), width: 520));
  }
}
