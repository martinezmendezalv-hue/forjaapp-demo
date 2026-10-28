import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

/// Cuenta de usuario tal y como la devuelve el servidor.
class Usuario {
  Usuario.desdeJson(Map<String, dynamic> j)
      : id = j['id'] as int,
        email = j['email'] as String,
        nombre = j['nombre'] as String,
        rol = j['rol'] as String,
        plan = j['plan'] as String?,
        creado = j['creado'] as String?,
        qrSecreto = j['qrSecreto'] as String?;

  final int id;
  final String email;
  final String nombre;
  final String rol;
  final String? plan;
  final String? creado;
  final String? qrSecreto;

  bool get esAdmin => rol == 'admin';
  bool get esTrabajador => rol == 'trabajador';
  bool get esSocio => rol == 'socio';

  String get nombreRol => switch (rol) {
        'admin' => 'Gerencia',
        'trabajador' => 'Trabajador',
        _ => 'Socio',
      };
}

class Plan {
  Plan.desdeJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        nombre = j['nombre'] as String,
        precio = (j['precio'] as num).toDouble(),
        periodo = j['periodo'] as String,
        incluye = (j['incluye'] as List).cast<String>(),
        destacado = j['destacado'] == true;

  final String id;
  final String nombre;
  final double precio;
  final String periodo;
  final List<String> incluye;
  final bool destacado;

  String get precioTexto => '${precio.toStringAsFixed(2).replaceAll('.', ',')} €';
}

/// Error con un mensaje listo para enseñar al usuario.
class ErrorServidor implements Exception {
  ErrorServidor(this.mensaje, {this.estado = 0});
  final String mensaje;
  final int estado;

  bool get sesionCaducada => estado == 401;

  @override
  String toString() => mensaje;
}

/// Cliente de la API de ForjaApp Servidor.
class ForjaApi {
  ForjaApi(this.base);

  /// Dirección del servidor, por ejemplo http://192.168.1.40:8080
  String base;
  String? token;
  final _http = http.Client();

  /// El servidor gratuito de la nube se duerme si nadie lo usa y tarda
  /// hasta un minuto en despertar: hay que esperarle.
  static const _espera = Duration(seconds: 75);

  Future<dynamic> _pedir(String metodo, String ruta, {Object? cuerpo, bool texto = false}) async {
    if (base.isEmpty) throw ErrorServidor('Primero indica la dirección del servidor.');
    final uri = Uri.parse('$base$ruta');
    final cabeceras = {
      if (cuerpo != null) 'content-type': 'application/json',
      if (token != null) 'authorization': 'Bearer $token',
    };
    http.Response r;
    try {
      final req = http.Request(metodo, uri)..headers.addAll(cabeceras);
      if (cuerpo != null) req.body = jsonEncode(cuerpo);
      r = await http.Response.fromStream(await _http.send(req).timeout(_espera));
    } on TimeoutException {
      throw ErrorServidor('El servidor no responde. Comprueba tu conexión a internet y vuelve a intentarlo.');
    } catch (_) {
      throw ErrorServidor(
          'No se puede conectar con el servidor ($base). Comprueba tu conexión a internet '
          '(si usas el servidor del PC del gimnasio, que esté abierto y estés en su wifi).');
    }
    if (texto && r.statusCode == 200) return utf8.decode(r.bodyBytes);
    dynamic datos;
    try {
      datos = jsonDecode(utf8.decode(r.bodyBytes));
    } catch (_) {
      throw ErrorServidor('Esa dirección no es un ForjaApp Servidor.', estado: r.statusCode);
    }
    if (r.statusCode >= 400) {
      final m = datos is Map && datos['error'] is String ? datos['error'] as String : 'Error ${r.statusCode}.';
      throw ErrorServidor(m, estado: r.statusCode);
    }
    return datos;
  }

  Future<void> comprobar() async {
    final d = await _pedir('GET', '/api/salud');
    if (d is! Map || d['servicio'] != 'ForjaApp Servidor') {
      throw ErrorServidor('Esa dirección no es un ForjaApp Servidor.');
    }
  }

  Future<({String id, Uint8List imagen})> captcha() async {
    final d = await _pedir('GET', '/api/captcha') as Map<String, dynamic>;
    return (id: d['id'] as String, imagen: base64.decode(d['imagen'] as String));
  }

  Future<List<Plan>> planes() async {
    final d = await _pedir('GET', '/api/planes') as Map<String, dynamic>;
    return [for (final p in d['planes'] as List) Plan.desdeJson(p as Map<String, dynamic>)];
  }

  Future<({String token, Usuario usuario})> _conSesion(Future<dynamic> f) async {
    final d = await f as Map<String, dynamic>;
    return (token: d['token'] as String, usuario: Usuario.desdeJson(d['usuario'] as Map<String, dynamic>));
  }

  Future<({String token, Usuario usuario})> registro({
    required String nombre,
    required String email,
    required String password,
    required String password2,
    required bool acepta,
    required String captchaId,
    required String captcha,
  }) =>
      _conSesion(_pedir('POST', '/api/registro', cuerpo: {
        'nombre': nombre,
        'email': email,
        'password': password,
        'password2': password2,
        'acepta': acepta,
        'captchaId': captchaId,
        'captcha': captcha,
      }));

  Future<({String token, Usuario usuario})> login({
    required String email,
    required String password,
    required String captchaId,
    required String captcha,
  }) =>
      _conSesion(_pedir('POST', '/api/login', cuerpo: {
        'email': email,
        'password': password,
        'captchaId': captchaId,
        'captcha': captcha,
      }));

  Future<void> salir() async {
    try {
      await _pedir('POST', '/api/salir');
    } catch (_) {}
  }

  Future<Usuario> yo() async =>
      Usuario.desdeJson((await _pedir('GET', '/api/yo') as Map<String, dynamic>)['usuario'] as Map<String, dynamic>);

  /// Pide el código de restablecimiento. Devuelve el mensaje del servidor.
  Future<String> olvido({required String email, required String captchaId, required String captcha}) async {
    final d = await _pedir('POST', '/api/olvido', cuerpo: {'email': email, 'captchaId': captchaId, 'captcha': captcha});
    return (d as Map)['mensaje'] as String? ?? 'Te hemos enviado un código a tu correo.';
  }

  Future<void> restablecer({
    required String email,
    required String codigo,
    required String nueva,
    required String nueva2,
  }) =>
      _pedir('POST', '/api/restablecer', cuerpo: {'email': email, 'codigo': codigo, 'nueva': nueva, 'nueva2': nueva2});

  Future<void> cambiarContrasena(String actual, String nueva, String nueva2) =>
      _pedir('POST', '/api/contrasena', cuerpo: {'actual': actual, 'nueva': nueva, 'nueva2': nueva2});

  Future<Usuario> suscribir(String plan) async => Usuario.desdeJson(
      (await _pedir('POST', '/api/suscripcion', cuerpo: {'plan': plan}) as Map<String, dynamic>)['usuario']
          as Map<String, dynamic>);

  Future<void> contacto(String asunto, String texto) =>
      _pedir('POST', '/api/contacto', cuerpo: {'asunto': asunto, 'texto': texto});

  Future<List<Map<String, dynamic>>> mensajes() async =>
      ((await _pedir('GET', '/api/mensajes') as Map)['mensajes'] as List).cast<Map<String, dynamic>>();

  Future<void> marcarLeido(int id) => _pedir('POST', '/api/mensajes/$id/leido');

  Future<({List<Usuario> usuarios, Map<String, dynamic> recuento})> usuarios() async {
    final d = await _pedir('GET', '/api/usuarios') as Map<String, dynamic>;
    return (
      usuarios: [for (final u in d['usuarios'] as List) Usuario.desdeJson(u as Map<String, dynamic>)],
      recuento: d['recuento'] as Map<String, dynamic>,
    );
  }

  Future<void> crearCuenta({
    required String nombre,
    required String email,
    required String password,
    required String password2,
    required String rol,
  }) =>
      _pedir('POST', '/api/usuarios',
          cuerpo: {'nombre': nombre, 'email': email, 'password': password, 'password2': password2, 'rol': rol});

  Future<Map<String, dynamic>> fichajes() async => await _pedir('GET', '/api/fichajes') as Map<String, dynamic>;

  Future<void> fichar(int usuarioId, String tipo) =>
      _pedir('POST', '/api/fichajes', cuerpo: {'usuarioId': usuarioId, 'tipo': tipo});

  Future<void> corregir(int id, DateTime momento, String motivo) => _pedir('POST', '/api/fichajes/$id/correccion',
      cuerpo: {'momento': momento.toUtc().toIso8601String(), 'motivo': motivo});

  Future<String> csv() async => await _pedir('GET', '/api/fichajes.csv', texto: true) as String;

  Future<Map<String, dynamic>> validarAcceso(String pase) async =>
      await _pedir('POST', '/api/acceso', cuerpo: {'token': pase}) as Map<String, dynamic>;
}

// ------------------------------------------------------------ pase QR real

const segundosQr = 5;

int ventanaQr() => DateTime.now().millisecondsSinceEpoch ~/ (segundosQr * 1000);

/// Pase firmado con el secreto del socio (lo comprueba el servidor).
String paseQr(Usuario u) {
  final v = ventanaQr();
  final firma =
      Hmac(sha256, utf8.encode(u.qrSecreto ?? '')).convert(utf8.encode('${u.id}:$v')).toString().substring(0, 16);
  return 'FORJA2-${u.id}-$v-$firma';
}
