import 'package:flutter/material.dart';

import '../main.dart' show avisar;
import '../servicios/api.dart';
import '../servicios/sesion.dart';
import '../theme.dart';

/// Carga datos del servidor y pinta carga, error (con reintento) o contenido.
class Cargador<T> extends StatefulWidget {
  const Cargador({super.key, required this.cargar, required this.builder});
  final Future<T> Function() cargar;
  final Widget Function(BuildContext context, T datos, Future<void> Function() recargar) builder;

  @override
  State<Cargador<T>> createState() => _CargadorState<T>();
}

class _CargadorState<T> extends State<Cargador<T>> {
  T? datos;
  String? error;
  bool cargando = true;

  @override
  void initState() {
    super.initState();
    recargar();
  }

  Future<void> recargar() async {
    setState(() {
      cargando = datos == null;
      error = null;
    });
    try {
      final d = await widget.cargar();
      if (mounted) setState(() => datos = d);
    } on ErrorServidor catch (e) {
      if (e.sesionCaducada) {
        await sesion.salir();
        return;
      }
      if (mounted) setState(() => error = e.mensaje);
    } finally {
      if (mounted) setState(() => cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (cargando && datos == null) return const Center(child: CircularProgressIndicator());
    if (error != null && datos == null) {
      return Center(
        child: SingleChildScrollView(
          child: EstadoVacio(
            icono: Icons.cloud_off_rounded,
            titulo: 'No se ha podido cargar',
            texto: error!,
            accion: OutlinedButton.icon(
              onPressed: recargar,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Reintentar'),
            ),
          ),
        ),
      );
    }
    return widget.builder(context, datos as T, recargar);
  }
}

/// Ejecuta una acción contra el servidor y avisa del error si falla.
Future<bool> intentar(BuildContext context, Future<void> Function() accion, {String? exito}) async {
  final m = ScaffoldMessenger.maybeOf(context);
  try {
    await accion();
    if (exito != null) avisar(m, exito);
    return true;
  } on ErrorServidor catch (e) {
    if (e.sesionCaducada) {
      await sesion.salir();
    } else {
      avisar(m, e.mensaje, error: true);
    }
    return false;
  }
}

/// Margen exterior de las secciones según el ancho disponible.
EdgeInsets margenSeccion(double ancho) =>
    ancho < 760 ? const EdgeInsets.all(Esp.l) : const EdgeInsets.fromLTRB(Esp.xxl, Esp.xl, Esp.xxl, Esp.xl);
