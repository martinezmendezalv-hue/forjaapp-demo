import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_static/shelf_static.dart';

import 'api.dart';
import 'bd.dart';

class ServidorForja {
  ServidorForja._(this.http, this.bd, this.api);
  final HttpServer http;
  final BaseDatos bd;
  final ForjaApi api;

  int get puerto => http.port;

  Future<void> parar() async {
    await http.close(force: true);
    bd.cerrar();
  }

  /// Arranca la API (y la web de ForjaApp si existe [carpetaWeb]) en todas
  /// las interfaces de red del PC, para que entren los móviles del wifi.
  static Future<ServidorForja> arrancar({
    required String rutaBd,
    int puerto = 8080,
    String? carpetaWeb,
    void Function(String linea)? alRegistrar,
  }) async {
    Directory(p.dirname(rutaBd)).createSync(recursive: true);
    final bd = await BaseDatos.abrir(rutaBd);
    final api = ForjaApi(bd, alRegistrar: alRegistrar);

    // /api/* va siempre a la API (sus 404 en JSON no se pierden); el resto, a la web.
    final apiHandler = api.handler;
    Handler web = (Request _) => Response.notFound('No encontrado');
    if (carpetaWeb != null && File(p.join(carpetaWeb, 'index.html')).existsSync()) {
      web = createStaticHandler(carpetaWeb, defaultDocument: 'index.html');
    }
    final handler = const Pipeline()
        .addMiddleware(cabeceras())
        .addHandler((req) => req.url.path.startsWith('api/') ? apiHandler(req) : web(req));
    final http = await shelf_io.serve(handler, InternetAddress.anyIPv4, puerto);
    http.autoCompress = true;
    // No anunciar la versión de Dart en cada respuesta.
    http.serverHeader = 'ForjaApp';
    return ServidorForja._(http, bd, api);
  }
}

/// Carpeta de datos en Windows: %APPDATA%\ForjaApp Servidor
String carpetaDatos() {
  final base = Platform.environment['APPDATA'] ?? Platform.environment['HOME'] ?? Directory.current.path;
  return p.join(base, 'ForjaApp Servidor');
}

/// Direcciones IPv4 del PC en la red local (para conectar el móvil).
Future<List<String>> direccionesLocales() async {
  final lista = <String>[];
  for (final i in await NetworkInterface.list(type: InternetAddressType.IPv4)) {
    for (final a in i.addresses) {
      if (!a.isLoopback && !a.address.startsWith('169.254.')) lista.add(a.address);
    }
  }
  // Primero las de redes domésticas habituales.
  lista.sort((a, b) => (a.startsWith('192.168.') ? 0 : 1).compareTo(b.startsWith('192.168.') ? 0 : 1));
  return lista;
}
