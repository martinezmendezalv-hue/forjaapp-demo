import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:qr_flutter/qr_flutter.dart';

import 'src/arranque.dart';
import 'src/bd.dart';

// Colores de Forja (los mismos que la app).
const _hierro = Color(0xFF15181D);
const _hierro2 = Color(0xFF22262E);
const _acero = Color(0xFFEEF1F4);
const _linea = Color(0xFFDDE2E8);
const _tinta = Color(0xFF1B1F27);
const _gris = Color(0xFF5A6270);
const _ascua = Color(0xFFE8611A);
const _ascuaTexto = Color(0xFFB8400D);
const _verde = Color(0xFF1F7A4D);
const _rojo = Color(0xFFB42318);

void main() => runApp(const ServidorApp());

class ServidorApp extends StatelessWidget {
  const ServidorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ForjaApp Servidor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: _ascua, primary: _ascuaTexto, surface: Colors.white),
        scaffoldBackgroundColor: _acero,
      ),
      home: const PantallaServidor(),
    );
  }
}

class PantallaServidor extends StatefulWidget {
  const PantallaServidor({super.key});

  @override
  State<PantallaServidor> createState() => _PantallaServidorState();
}

class _PantallaServidorState extends State<PantallaServidor> {
  static const puerto = 8080;
  ServidorForja? servidor;
  String? error;
  List<String> direcciones = [];
  Map<String, int> recuento = {};
  final actividad = <String>[];
  Timer? _refresco;
  late final String rutaBd = p.join(carpetaDatos(), 'forja.db');

  @override
  void initState() {
    super.initState();
    _arrancar();
  }

  Future<void> _arrancar() async {
    try {
      final web = p.join(File(Platform.resolvedExecutable).parent.path, 'web');
      final s = await ServidorForja.arrancar(
        rutaBd: rutaBd,
        puerto: puerto,
        carpetaWeb: web,
        alRegistrar: _anotar,
      );
      final ips = await direccionesLocales();
      final cuantos = await s.bd.recuento();
      if (!mounted) return;
      setState(() {
        servidor = s;
        direcciones = ips;
        recuento = cuantos;
      });
      _anotar('Servidor en marcha en el puerto $puerto');
      _refresco = Timer.periodic(const Duration(seconds: 3), (_) async {
        final cuantos = await servidor?.bd.recuento();
        if (mounted && cuantos != null) setState(() => recuento = cuantos);
      });
    } on SocketException {
      setState(() => error =
          'El puerto $puerto está ocupado. ¿Hay otro ForjaApp Servidor abierto? Ciérralo y vuelve a abrir este.');
    } catch (e) {
      setState(() => error = 'No se ha podido arrancar el servidor: $e');
    }
  }

  void _anotar(String linea) {
    final h = DateTime.now();
    String d(int n) => n.toString().padLeft(2, '0');
    final texto = '${d(h.hour)}:${d(h.minute)}:${d(h.second)}  $linea';
    if (!mounted) return;
    setState(() {
      actividad.insert(0, texto);
      if (actividad.length > 300) actividad.removeLast();
    });
  }

  @override
  void dispose() {
    _refresco?.cancel();
    servidor?.parar();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(children: [
        _cabecera(),
        Expanded(
          child: error != null
              ? _aviso(error!)
              : servidor == null
                  ? const Center(child: CircularProgressIndicator())
                  : Padding(
                      padding: const EdgeInsets.all(24),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        SizedBox(width: 380, child: _conectar()),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(children: [
                            _cifras(),
                            const SizedBox(height: 20),
                            Expanded(child: _actividad()),
                          ]),
                        ),
                      ]),
                    ),
        ),
      ]),
    );
  }

  Widget _cabecera() {
    final ok = servidor != null;
    return Container(
      color: _hierro,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: _hierro2, borderRadius: BorderRadius.circular(10)),
          child: const Text('F', style: TextStyle(color: _ascua, fontSize: 26, fontWeight: FontWeight.w900)),
        ),
        const SizedBox(width: 12),
        const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('ForjaApp Servidor',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
          Text('Base de datos de Forja Training Club en este PC',
              style: TextStyle(color: Color(0xFF8B93A0), fontSize: 13)),
        ]),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: (ok ? _verde : _rojo).withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(children: [
            Icon(ok ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                size: 18, color: ok ? const Color(0xFF6FD3A0) : const Color(0xFFFF9C8F)),
            const SizedBox(width: 6),
            Text(ok ? 'Funcionando · puerto $puerto' : (error == null ? 'Arrancando…' : 'Parado'),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ]),
        ),
      ]),
    );
  }

  Widget _tarjeta({required Widget child, EdgeInsets padding = const EdgeInsets.all(20)}) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _linea),
        ),
        child: child,
      );

  Widget _conectar() {
    final principal = direcciones.isEmpty ? 'http://localhost:$puerto' : 'http://${direcciones.first}:$puerto';
    return _tarjeta(
      child: ListView(children: [
        const Text('Conectar las apps',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _tinta)),
        const SizedBox(height: 4),
        const Text(
          'El móvil tiene que estar en la misma wifi que este PC. En la app, toca «Servidor» en la pantalla de '
          'inicio de sesión y escanea este código o escribe la dirección.',
          style: TextStyle(color: _gris, height: 1.4),
        ),
        const SizedBox(height: 16),
        Center(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(border: Border.all(color: _linea), borderRadius: BorderRadius.circular(12)),
            child: QrImageView(data: principal, size: 200, padding: EdgeInsets.zero),
          ),
        ),
        const SizedBox(height: 16),
        for (final ip in direcciones) _direccion('http://$ip:$puerto'),
        _direccion('http://localhost:$puerto', apoyo: 'Desde este mismo PC'),
        const SizedBox(height: 12),
        const Text(
          'La versión web de ForjaApp también se abre en esas direcciones desde cualquier navegador de la red.',
          style: TextStyle(color: _gris, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => Process.run('explorer', [p.dirname(rutaBd)]),
          icon: const Icon(Icons.folder_open_outlined, size: 18),
          label: const Text('Abrir la carpeta de la base de datos'),
        ),
        const SizedBox(height: 6),
        Text(rutaBd, style: const TextStyle(color: _gris, fontSize: 12)),
      ]),
    );
  }

  Widget _direccion(String url, {String? apoyo}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SelectableText(url, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            if (apoyo != null) Text(apoyo, style: const TextStyle(color: _gris, fontSize: 12)),
          ]),
        ),
        IconButton(
          tooltip: 'Copiar dirección',
          onPressed: () {
            Clipboard.setData(ClipboardData(text: url));
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Copiado: $url')));
          },
          icon: const Icon(Icons.content_copy_rounded, size: 18),
        ),
      ]),
    );
  }

  Widget _cifras() {
    Widget cifra(String texto, String clave, IconData icono) => Expanded(
          child: _tarjeta(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Icon(icono, color: _ascuaTexto),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${recuento[clave] ?? 0}',
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: _tinta)),
                Text(texto, style: const TextStyle(color: _gris, fontSize: 13)),
              ]),
            ]),
          ),
        );
    return Row(children: [
      cifra('Socios', 'socios', Icons.groups_2_outlined),
      const SizedBox(width: 12),
      cifra('Trabajadores', 'trabajadores', Icons.badge_outlined),
      const SizedBox(width: 12),
      cifra('Mensajes sin leer', 'mensajes', Icons.mark_email_unread_outlined),
      const SizedBox(width: 12),
      cifra('Fichajes', 'fichajes', Icons.fact_check_outlined),
    ]);
  }

  Widget _actividad() {
    return _tarjeta(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Actividad', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _tinta)),
        const SizedBox(height: 4),
        const Text('Sin contraseñas ni datos personales: solo lo que pasa.', style: TextStyle(color: _gris, fontSize: 13)),
        const Divider(height: 24),
        Expanded(
          child: actividad.isEmpty
              ? const Center(child: Text('Aún no hay actividad.', style: TextStyle(color: _gris)))
              : ListView.builder(
                  itemCount: actividad.length,
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Text(actividad[i],
                        style: const TextStyle(fontFamily: 'Consolas', fontSize: 13, color: _tinta)),
                  ),
                ),
        ),
        const Divider(height: 20),
        const Text('Cuenta de gerencia: $correoAdmin', style: TextStyle(color: _gris, fontSize: 12)),
      ]),
    );
  }

  Widget _aviso(String texto) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: _rojo),
            const SizedBox(height: 12),
            Text(texto, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, color: _tinta)),
          ]),
        ),
      );
}
