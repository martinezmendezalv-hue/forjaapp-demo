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
    store.ultimoMensaje.addListener(() {
      final m = store.ultimoMensaje.value;
      if (m == null) return;
      messengerKey.currentState
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.notifications_active_outlined, color: Forja.amarillo, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(m)),
          ]),
          duration: const Duration(seconds: 4),
          width: 560,
        ));
    });
  }

  @override
  void dispose() {
    store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ForjaApp · Demo',
      debugShowCheckedModeBanner: false,
      theme: Forja.tema(),
      scaffoldMessengerKey: messengerKey,
      home: Inicio(store: store),
    );
  }
}

class Inicio extends StatefulWidget {
  const Inicio({super.key, required this.store});
  final ForjaStore store;

  @override
  State<Inicio> createState() => _InicioState();
}

class _InicioState extends State<Inicio> {
  int seccion = 0;

  static const _secciones = [
    (Icons.phone_iphone_rounded, 'App del socio', Forja.coral),
    (Icons.dashboard_outlined, 'Recepción', Forja.turquesa),
    (Icons.qr_code_scanner_rounded, 'Punto de acceso', Forja.amarillo),
    (Icons.badge_outlined, 'Fichajes', Forja.morado),
  ];

  @override
  Widget build(BuildContext context) {
    final pantallas = [
      PantallaSocio(store: widget.store),
      PantallaRecepcion(store: widget.store),
      PantallaAcceso(store: widget.store),
      PantallaFichajes(store: widget.store),
    ];
    return Scaffold(
      body: Row(
        children: [
          _menu(),
          Expanded(
            child: Stack(
              children: [
                Positioned(
                  right: -140,
                  top: -160,
                  child: Container(
                    width: 420,
                    height: 420,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: [Forja.coralSuave, Forja.turquesaSuave, Forja.amarilloSuave, Forja.moradoSuave][seccion],
                    ),
                  ),
                ),
                Positioned.fill(child: pantallas[seccion]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _menu() {
    return Container(
      width: 240,
      color: Forja.marino,
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: Forja.coral, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.fitness_center_rounded, color: Forja.marino, size: 22),
            ),
            const SizedBox(width: 10),
            const Text('ForjaApp', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 6),
          const Text('Forja Training Club · Guadalajara',
              style: TextStyle(color: Color(0xFFB7BED0), fontSize: 12)),
          const SizedBox(height: 32),
          for (var i = 0; i < _secciones.length; i++) _botonMenu(i),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFF2C3A5E), borderRadius: BorderRadius.circular(12)),
            child: const Text(
              'Demo con datos de ejemplo. No hay servidor ni datos reales: todo se guarda en memoria mientras la app está abierta.',
              style: TextStyle(color: Color(0xFFDDE4F5), fontSize: 12, height: 1.4),
            ),
          ),
          const SizedBox(height: 12),
          const Text('Proyecto 2.º DAM · Álvaro Martínez',
              style: TextStyle(color: Color(0xFF8E97AD), fontSize: 11)),
        ],
      ),
    );
  }

  Widget _botonMenu(int i) {
    final (icono, texto, color) = _secciones[i];
    final activo = i == seccion;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: activo ? const Color(0xFF2C3A5E) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => seccion = i),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: Icon(icono, size: 17, color: color == Forja.morado ? Colors.white : Forja.marino),
              ),
              const SizedBox(width: 12),
              Text(texto,
                  style: TextStyle(
                    color: activo ? Colors.white : const Color(0xFFB7BED0),
                    fontWeight: activo ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 15,
                  )),
            ]),
          ),
        ),
      ),
    );
  }
}
