import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;

final _azar = Random.secure();

Uint8List bytesAleatorios(int n) => Uint8List.fromList(List.generate(n, (_) => _azar.nextInt(256)));

/// Token opaco para sesiones y secretos (32 bytes en base64 url).
String tokenAleatorio([int bytes = 32]) => base64Url.encode(bytesAleatorios(bytes)).replaceAll('=', '');

/// Código de [cifras] dígitos al azar (para el correo de restablecimiento).
String codigoNumerico(int cifras) => List.generate(cifras, (_) => _azar.nextInt(10)).join();

String sha256Hex(String texto) => sha256.convert(utf8.encode(texto)).toString();

/// Compara sin cortar en el primer byte distinto, para no filtrar
/// información por el tiempo de respuesta.
bool igualesSeguro(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var dif = 0;
  for (var i = 0; i < a.length; i++) {
    dif |= a[i] ^ b[i];
  }
  return dif == 0;
}

// ------------------------------------------------------------ contraseñas

/// Iteraciones de PBKDF2-HMAC-SHA256 (recomendación OWASP 2023: 600.000).
/// Las pruebas automáticas la bajan para no tardar minutos.
int iteracionesPbkdf2 = 600000;

List<int> _pbkdf2(List<int> clave, List<int> sal, int iteraciones) {
  final hmac = Hmac(sha256, clave);
  var u = hmac.convert([...sal, 0, 0, 0, 1]).bytes;
  final resultado = List<int>.from(u);
  for (var i = 1; i < iteraciones; i++) {
    u = hmac.convert(u).bytes;
    for (var j = 0; j < resultado.length; j++) {
      resultado[j] ^= u[j];
    }
  }
  return resultado;
}

/// Devuelve «pbkdf2_sha256$iteraciones$sal$hash». Se calcula en otro
/// isolate para no bloquear el servidor mientras tanto.
Future<String> hashContrasena(String contrasena, {int? iteraciones}) async {
  iteraciones ??= iteracionesPbkdf2;
  final sal = bytesAleatorios(16);
  final n = iteraciones;
  final hash = await _turnosHash.ejecutar(() => Isolate.run(() => _pbkdf2(utf8.encode(contrasena), sal, n)));
  return 'pbkdf2_sha256\$$n\$${base64.encode(sal)}\$${base64.encode(hash)}';
}

Future<bool> verificarContrasena(String contrasena, String guardado) async {
  final partes = guardado.split('\$');
  if (partes.length != 4 || partes[0] != 'pbkdf2_sha256') return false;
  final iteraciones = int.tryParse(partes[1]);
  if (iteraciones == null || iteraciones < 1 || iteraciones > 5000000) return false;
  final sal = base64.decode(partes[2]);
  final esperado = base64.decode(partes[3]);
  final hash = await _turnosHash.ejecutar(() => Isolate.run(() => _pbkdf2(utf8.encode(contrasena), sal, iteraciones)));
  return igualesSeguro(hash, esperado);
}

/// El servidor está saturado: se responde 503 en vez de encolar sin fin.
class ServidorOcupado implements Exception {}

/// Limita cuántos trabajos pesados van a la vez (y cuántos esperan), para
/// que una avalancha de inicios de sesión no tumbe el PC.
class Turnos {
  Turnos({required this.aLaVez, required this.enCola});
  final int aLaVez;
  final int enCola;
  int _activos = 0;
  final _espera = <Completer<void>>[];

  Future<T> ejecutar<T>(Future<T> Function() trabajo) async {
    if (_activos >= aLaVez) {
      if (_espera.length >= enCola) throw ServidorOcupado();
      final turno = Completer<void>();
      _espera.add(turno);
      await turno.future;
    } else {
      _activos++;
    }
    try {
      return await trabajo();
    } finally {
      if (_espera.isNotEmpty) {
        _espera.removeAt(0).complete(); // el turno pasa directamente al siguiente
      } else {
        _activos--;
      }
    }
  }
}

final _turnosHash = Turnos(aLaVez: 3, enCola: 30);

/// Hash fijo para comparar cuando el usuario no existe: así el tiempo de
/// respuesta no revela qué correos están registrados.
String? _hashSenuelo;
Future<void> trabajoSenuelo(String contrasena) async {
  _hashSenuelo ??= await hashContrasena('senuelo-${tokenAleatorio()}');
  await verificarContrasena(contrasena, _hashSenuelo!);
}

/// Reglas para contraseñas nuevas. Devuelve el error o null si vale.
String? problemaContrasena(String c) {
  if (c.length < 8) return 'La contraseña debe tener al menos 8 caracteres.';
  if (c.length > 128) return 'La contraseña no puede pasar de 128 caracteres.';
  if (!RegExp(r'[A-Za-zÁÉÍÓÚÜÑáéíóúüñ]').hasMatch(c) || !RegExp(r'\d').hasMatch(c)) {
    return 'La contraseña debe combinar letras y números.';
  }
  return null;
}

final _formatoCorreo = RegExp(r"^[A-Za-z0-9._%+\-]{1,64}@[A-Za-z0-9.\-]{1,190}\.[A-Za-z]{2,24}$");
bool correoValido(String c) => c.length <= 254 && _formatoCorreo.hasMatch(c);

// ---------------------------------------------------------------- captcha

/// Sin 0/O, 1/I/L ni 5/S para que se pueda leer sin dudas.
const _alfabetoCaptcha = 'ABCDEFGHJKMNPQRTUVWXYZ2346789';

class _Reto {
  _Reto(this.hash, this.caduca);
  final List<int> hash;
  final DateTime caduca;
}

/// Captchas de un solo uso, en memoria, que caducan a los 5 minutos.
class Captchas {
  final _retos = <String, _Reto>{};
  static const duracion = Duration(minutes: 5);
  static const maximo = 5000;

  /// Crea un reto y devuelve su id y la imagen PNG.
  /// Tope global por minuto: así nadie puede echar del almacén los
  /// captchas de los demás pidiendo miles desde varias IP.
  final _global = LimiteIntentos(maximo: 300, ventana: const Duration(minutes: 1));

  ({String id, Uint8List png}) crear() {
    if (_global.bloqueado('todos')) throw ServidorOcupado();
    _global.fallo('todos');
    _limpiar();
    String texto;
    do {
      texto = List.generate(6, (_) => _alfabetoCaptcha[_azar.nextInt(_alfabetoCaptcha.length)]).join();
    } while (RegExp(r'\d').allMatches(texto).length < 2 || RegExp(r'[A-Z]').allMatches(texto).length < 2);
    final id = tokenAleatorio(16);
    _retos[id] = _Reto(sha256.convert(utf8.encode(texto)).bytes, DateTime.now().add(duracion));
    return (id: id, png: _dibujar(texto));
  }

  /// Solo para las pruebas automáticas: crea un reto con texto conocido.
  String crearConTexto(String texto) {
    final id = tokenAleatorio(16);
    _retos[id] = _Reto(sha256.convert(utf8.encode(texto)).bytes, DateTime.now().add(duracion));
    return id;
  }

  /// Comprueba la respuesta. El reto se borra siempre, acierte o no.
  bool comprobar(String? id, String? respuesta) {
    if (id == null || respuesta == null) return false;
    final reto = _retos.remove(id);
    if (reto == null || reto.caduca.isBefore(DateTime.now())) return false;
    final r = respuesta.trim().toUpperCase();
    if (r.length != 6) return false;
    return igualesSeguro(sha256.convert(utf8.encode(r)).bytes, reto.hash);
  }

  void _limpiar() {
    final ahora = DateTime.now();
    _retos.removeWhere((_, r) => r.caduca.isBefore(ahora));
    if (_retos.length >= maximo) _retos.remove(_retos.keys.first);
  }

  Uint8List _dibujar(String texto) {
    const ancho = 240, alto = 80;
    final lienzo = img.Image(width: ancho, height: alto);
    img.fill(lienzo, color: img.ColorRgb8(236 + _azar.nextInt(16), 238 + _azar.nextInt(14), 242));
    // Ruido de fondo
    for (var i = 0; i < 900; i++) {
      final g = 150 + _azar.nextInt(90);
      lienzo.setPixelRgb(_azar.nextInt(ancho), _azar.nextInt(alto), g, g, g);
    }
    for (var i = 0; i < 6; i++) {
      img.drawLine(lienzo,
          x1: _azar.nextInt(ancho),
          y1: _azar.nextInt(alto),
          x2: _azar.nextInt(ancho),
          y2: _azar.nextInt(alto),
          color: img.ColorRgb8(120 + _azar.nextInt(100), 120 + _azar.nextInt(100), 120 + _azar.nextInt(100)),
          thickness: 1 + _azar.nextInt(2));
    }
    // Cada letra con su giro y su altura
    var x = 10;
    for (final letra in texto.split('')) {
      final caja = img.Image(width: 44, height: 56, numChannels: 4);
      final color = img.ColorRgb8(20 + _azar.nextInt(90), 20 + _azar.nextInt(90), 40 + _azar.nextInt(110));
      img.drawString(caja, letra, font: img.arial48, x: 6, y: 2, color: color);
      final girada = img.copyRotate(caja, angle: _azar.nextInt(56) - 28);
      img.compositeImage(lienzo, girada, dstX: x - 4, dstY: 2 + _azar.nextInt(14) - 4);
      x += 34 + _azar.nextInt(6);
    }
    // Líneas por encima de las letras
    for (var i = 0; i < 3; i++) {
      final y0 = 15 + _azar.nextInt(alto - 30);
      img.drawLine(lienzo,
          x1: 0,
          y1: y0,
          x2: ancho,
          y2: y0 + _azar.nextInt(30) - 15,
          color: img.ColorRgb8(60 + _azar.nextInt(80), 60 + _azar.nextInt(80), 60 + _azar.nextInt(80)),
          thickness: 2);
    }
    return img.encodePng(lienzo);
  }
}

// ------------------------------------------------------------ intentos

/// Límite de intentos fallidos por clave (correo o IP) en una ventana.
class LimiteIntentos {
  LimiteIntentos({required this.maximo, required this.ventana});
  final int maximo;
  final Duration ventana;
  final _fallos = <String, List<DateTime>>{};

  bool bloqueado(String clave) {
    final lista = _fallos[clave];
    if (lista == null) return false;
    final desde = DateTime.now().subtract(ventana);
    lista.removeWhere((t) => t.isBefore(desde));
    return lista.length >= maximo;
  }

  static const _maxClaves = 20000;

  void fallo(String clave) {
    if (_fallos.length >= _maxClaves && !_fallos.containsKey(clave)) {
      // Primero se olvida lo caducado; si aún hay demasiadas, las más antiguas.
      // Nunca se vacía todo: eso desbloquearía a quien está bloqueado.
      final desde = DateTime.now().subtract(ventana);
      _fallos.removeWhere((_, l) => l.every((t) => t.isBefore(desde)));
      while (_fallos.length >= _maxClaves) {
        _fallos.remove(_fallos.keys.first);
      }
    }
    final lista = _fallos[clave] ??= [];
    lista.add(DateTime.now());
    if (lista.length > maximo * 4) lista.removeAt(0);
  }

  void limpiar(String clave) => _fallos.remove(clave);
}

// --------------------------------------------------------------- pase QR

/// Pase QR de un socio: «FORJA2-id-ventana-firma». La firma es un
/// HMAC-SHA256 con un secreto propio de cada socio, así que no se puede
/// fabricar el pase de otra persona aunque se conozca el formato.
const segundosQr = 5;

int ventanaQr([DateTime? t]) => (t ?? DateTime.now()).millisecondsSinceEpoch ~/ (segundosQr * 1000);

String firmaQr(String secreto, int usuarioId, int ventana) =>
    Hmac(sha256, utf8.encode(secreto)).convert(utf8.encode('$usuarioId:$ventana')).toString().substring(0, 16);
