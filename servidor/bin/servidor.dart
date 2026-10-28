// Versión de línea de comandos del servidor (para desarrollo y pruebas):
//   dart run bin/servidor.dart [--puerto 8080] [--bd ruta.db] [--web carpeta]
import 'dart:io';

import 'package:forja_servidor/src/arranque.dart';
import 'package:path/path.dart' as p;

Future<void> main(List<String> args) async {
  String? valor(String nombre) {
    final i = args.indexOf(nombre);
    return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
  }

  final s = await ServidorForja.arrancar(
    rutaBd: valor('--bd') ?? p.join(carpetaDatos(), 'forja.db'),
    puerto: int.tryParse(valor('--puerto') ?? '') ?? 8080,
    carpetaWeb: valor('--web'),
    alRegistrar: (l) => stdout.writeln('${DateTime.now().toIso8601String().substring(11, 19)}  $l'),
  );
  stdout.writeln('ForjaApp Servidor escuchando en el puerto ${s.puerto}');
  for (final ip in await direccionesLocales()) {
    stdout.writeln('  http://$ip:${s.puerto}');
  }
}
