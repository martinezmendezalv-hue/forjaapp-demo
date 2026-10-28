// Versión de línea de comandos del servidor (para desarrollo y para la nube):
//   dart run bin/servidor.dart [--puerto 8080] [--bd ruta.db] [--web carpeta]
//
// En la nube (Render) se configura con variables de entorno:
//   PORT               puerto en el que escuchar (lo pone Render)
//   DATABASE_URL       postgres://… de Neon; sin ella se usa SQLite
//   ADMIN_CONTRASENA   contraseña inicial de la gerencia (solo la primera vez)
//   PBKDF2_ITERACIONES iteraciones del hash de contraseñas
//   TRAS_PROXY=1       la IP del cliente viene en X-Forwarded-For
//   BREVO_API_KEY y CORREO_REMITENTE  para enviar el código de «he olvidado
//                      mi contraseña» (el remitente tiene que estar validado en Brevo)
import 'dart:io';

import 'package:forja_servidor/src/arranque.dart';
import 'package:forja_servidor/src/bd.dart';
import 'package:forja_servidor/src/correo.dart';
import 'package:forja_servidor/src/seguridad.dart';
import 'package:path/path.dart' as p;

Future<void> main(List<String> args) async {
  String? valor(String nombre) {
    final i = args.indexOf(nombre);
    return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
  }

  final env = Platform.environment;
  String? variable(String nombre) => (env[nombre] ?? '').trim().isEmpty ? null : env[nombre]!.trim();

  final iteraciones = int.tryParse(variable('PBKDF2_ITERACIONES') ?? '');
  if (iteraciones != null && iteraciones >= 100000) iteracionesPbkdf2 = iteraciones;

  final claveBrevo = variable('BREVO_API_KEY');
  final remitente = variable('CORREO_REMITENTE');
  final correo = claveBrevo == null || remitente == null ? null : CorreoBrevo(clave: claveBrevo, remitente: remitente);

  final s = await ServidorForja.arrancar(
    rutaBd: valor('--bd') ?? p.join(carpetaDatos(), 'forja.db'),
    urlPostgres: variable('DATABASE_URL'),
    contrasenaAdmin: variable('ADMIN_CONTRASENA') ?? contrasenaInicialAdmin,
    trasProxy: variable('TRAS_PROXY') == '1',
    correo: correo,
    puerto: int.tryParse(valor('--puerto') ?? variable('PORT') ?? '') ?? 8080,
    carpetaWeb: valor('--web'),
    alRegistrar: (l) => stdout.writeln('${DateTime.now().toIso8601String().substring(11, 19)}  $l'),
  );
  stdout.writeln('ForjaApp Servidor escuchando en el puerto ${s.puerto} '
      '(${variable('DATABASE_URL') == null ? 'SQLite' : 'Postgres'}, '
      '${correo == null ? 'sin envío de correos' : 'correos con Brevo'})');
  for (final ip in await direccionesLocales()) {
    stdout.writeln('  http://$ip:${s.puerto}');
  }
}
