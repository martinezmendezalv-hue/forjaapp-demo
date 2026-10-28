import 'dart:async';
import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'bd.dart';
import 'planes.dart';
import 'seguridad.dart';

const versionServidor = '1.0.0';

/// Error que se devuelve al cliente tal cual, con su código HTTP.
class ErrorApi implements Exception {
  ErrorApi(this.estado, this.mensaje);
  final int estado;
  final String mensaje;
}

/// API REST de ForjaApp. Los permisos se comprueban siempre aquí, en el
/// servidor: la app solo esconde botones, no decide quién puede qué.
class ForjaApi {
  ForjaApi(this.bd, {this.alRegistrar, this.trasProxy = false});

  final BaseDatos bd;

  /// El servidor está detrás de un proxy de confianza (Render).
  final bool trasProxy;

  /// Para que la ventana del servidor enseñe la actividad (sin datos personales).
  final void Function(String linea)? alRegistrar;

  final captchas = Captchas();
  // El bloqueo de 5 fallos es por correo y equipo: así nadie puede dejar
  // fuera a la gerencia (su correo es conocido) fallando a propósito desde
  // otro equipo. El tope por correo, más alto, frena los ataques repartidos.
  final _fallosCorreoIp = LimiteIntentos(maximo: 5, ventana: const Duration(minutes: 15));
  final _fallosCorreo = LimiteIntentos(maximo: 30, ventana: const Duration(minutes: 15));
  final _fallosIp = LimiteIntentos(maximo: 20, ventana: const Duration(minutes: 15));
  final _cambiosContrasena = LimiteIntentos(maximo: 5, ventana: const Duration(minutes: 15));
  final _lecturasLector = LimiteIntentos(maximo: 60, ventana: const Duration(minutes: 1));

  /// Última ventana de QR usada por cada socio: un pase solo abre una vez.
  final _ultimaVentanaQr = <int, int>{};
  final _altasIp = LimiteIntentos(maximo: 10, ventana: const Duration(hours: 1));
  final _captchasIp = LimiteIntentos(maximo: 60, ventana: const Duration(minutes: 1));
  final _mensajesUsuario = LimiteIntentos(maximo: 5, ventana: const Duration(hours: 1));

  static const _maxCuerpo = 32 * 1024;

  Handler get handler {
    final r = Router()
      ..get('/api/salud', _salud)
      ..get('/api/captcha', _captcha)
      ..get('/api/planes', _planes)
      ..post('/api/registro', _registro)
      ..post('/api/login', _login)
      ..post('/api/salir', _salir)
      ..get('/api/yo', _yo)
      ..post('/api/contrasena', _cambiarContrasena)
      ..post('/api/suscripcion', _suscribir)
      ..post('/api/contacto', _contacto)
      ..get('/api/mensajes', _mensajes)
      ..post('/api/mensajes/<id|[0-9]{1,9}>/leido', _leido)
      ..get('/api/usuarios', _usuarios)
      ..post('/api/usuarios', _crearCuenta)
      ..get('/api/fichajes', _fichajes)
      ..post('/api/fichajes', _fichar)
      ..post('/api/fichajes/<id|[0-9]{1,9}>/correccion', _corregir)
      ..get('/api/fichajes.csv', _csv)
      ..post('/api/acceso', _validarAcceso)
      ..all('/api/<resto|.*>', (Request _) => _json(404, {'error': 'No existe esa ruta.'}));
    return r.call;
  }

  // ------------------------------------------------------------- utilidades

  static Response _json(int estado, Object cuerpo) => Response(
        estado,
        body: jsonEncode(cuerpo),
        headers: {'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store'},
      );

  String _ip(Request req) {
    // En la nube todas las peticiones llegan desde el proxy de Render: la IP
    // de verdad es la última que él añade a X-Forwarded-For (las anteriores
    // las puede inventar el cliente).
    if (trasProxy) {
      final reenvio = req.headers['x-forwarded-for'];
      if (reenvio != null && reenvio.trim().isNotEmpty) return reenvio.split(',').last.trim();
    }
    final info = req.context['shelf.io.connection_info'];
    try {
      return (info as dynamic).remoteAddress.address as String;
    } catch (_) {
      return 'desconocida';
    }
  }

  /// Lee el JSON del cuerpo con un tamaño máximo.
  static Future<Map<String, dynamic>> _cuerpo(Request req) async {
    final tipo = req.headers['content-type'] ?? '';
    if (!tipo.startsWith('application/json')) throw ErrorApi(415, 'Se esperaba JSON.');
    if ((req.contentLength ?? 0) > _maxCuerpo) throw ErrorApi(413, 'La petición es demasiado grande.');
    final bytes = <int>[];
    await for (final trozo in req.read()) {
      bytes.addAll(trozo);
      if (bytes.length > _maxCuerpo) throw ErrorApi(413, 'La petición es demasiado grande.');
    }
    try {
      final datos = jsonDecode(utf8.decode(bytes));
      if (datos is Map<String, dynamic>) return datos;
    } catch (_) {}
    throw ErrorApi(400, 'El cuerpo de la petición no es un JSON válido.');
  }

  static String _texto(Map<String, dynamic> d, String campo, {int min = 0, int max = 200, String? nombre}) {
    final v = d[campo];
    if (v is! String) throw ErrorApi(400, 'Falta ${nombre ?? campo}.');
    final t = v.trim();
    if (t.length < min) throw ErrorApi(400, min <= 1 ? 'Falta ${nombre ?? campo}.' : '${_mayus(nombre ?? campo)} es demasiado corto.');
    if (t.length > max) throw ErrorApi(400, '${_mayus(nombre ?? campo)} es demasiado largo.');
    if (RegExp(r'[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]').hasMatch(t)) {
      throw ErrorApi(400, '${_mayus(nombre ?? campo)} tiene caracteres no permitidos.');
    }
    return t;
  }

  /// Campo de texto opcional: si llega con otro tipo, se trata como ausente.
  static String? _cadena(Map<String, dynamic> d, String campo) => d[campo] is String ? d[campo] as String : null;

  static String _mayus(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  static String? _token(Request req) {
    final a = req.headers['authorization'];
    if (a == null || !a.startsWith('Bearer ')) return null;
    final t = a.substring(7).trim();
    return t.isEmpty || t.length > 200 ? null : t;
  }

  Future<Fila> _sesion(Request req, {List<String>? roles}) async {
    final t = _token(req);
    final u = t == null ? null : await bd.usuarioDeSesion(t);
    if (u == null) throw ErrorApi(401, 'Tu sesión ha caducado. Vuelve a iniciar sesión.');
    if (roles != null && !roles.contains(u['rol'])) throw ErrorApi(403, 'Tu cuenta no tiene permiso para esto.');
    return u;
  }

  static Map<String, Object?> _usuarioJson(Fila u, {bool conSecreto = false}) => {
        'id': u['id'],
        'email': u['email'],
        'nombre': u['nombre'],
        'rol': u['rol'],
        'plan': u['plan'],
        'planDesde': u['plan_desde'],
        'creado': u['creado'],
        if (conSecreto && u['rol'] == 'socio') 'qrSecreto': u['qr_secreto'],
      };

  /// Envuelve cada ruta: convierte ErrorApi en respuesta y oculta los
  /// errores internos (sin trazas al cliente).
  Future<Response> _seguro(Request req, FutureOr<Response> Function() f) async {
    try {
      return await f();
    } on ErrorApi catch (e) {
      return _json(e.estado, {'error': e.mensaje});
    } on ServidorOcupado {
      return _json(503, {'error': 'El servidor está ocupado. Inténtalo de nuevo en unos segundos.'});
    } catch (e) {
      alRegistrar?.call('Error interno en ${req.url.path}: ${e.runtimeType}');
      return _json(500, {'error': 'Error interno del servidor.'});
    }
  }

  // ------------------------------------------------------------- públicas

  Response _salud(Request req) =>
      _json(200, {'ok': true, 'servicio': 'ForjaApp Servidor', 'version': versionServidor});

  Future<Response> _captcha(Request req) => _seguro(req, () async {
        final ip = _ip(req);
        if (_captchasIp.bloqueado(ip)) throw ErrorApi(429, 'Demasiadas peticiones. Espera un minuto.');
        _captchasIp.fallo(ip); // cuenta todas las peticiones de captcha
        final c = captchas.crear();
        return _json(200, {'id': c.id, 'imagen': base64.encode(c.png)});
      });

  Response _planes(Request req) => _json(200, {'planes': [for (final p in planes) p.toJson()]});

  Future<Response> _registro(Request req) => _seguro(req, () async {
        final ip = _ip(req);
        if (_altasIp.bloqueado(ip)) throw ErrorApi(429, 'Se han creado demasiadas cuentas desde este equipo. Espera una hora.');
        final d = await _cuerpo(req);
        if (!captchas.comprobar(_cadena(d, 'captchaId'), _cadena(d, 'captcha'))) {
          throw ErrorApi(400, 'El código de verificación no es correcto o ha caducado. Escribe el nuevo.');
        }
        final nombre = _texto(d, 'nombre', min: 2, max: 60, nombre: 'el nombre');
        final email = _texto(d, 'email', min: 3, max: 254, nombre: 'el correo').toLowerCase();
        final pass = d['password'];
        final pass2 = d['password2'];
        if (!correoValido(email)) throw ErrorApi(400, 'El correo no tiene un formato válido.');
        if (pass is! String || pass2 is! String) throw ErrorApi(400, 'Falta la contraseña.');
        final problema = problemaContrasena(pass);
        if (problema != null) throw ErrorApi(400, problema);
        if (pass != pass2) throw ErrorApi(400, 'Las contraseñas no coinciden.');
        if (d['acepta'] != true) throw ErrorApi(400, 'Tienes que aceptar las condiciones para crear la cuenta.');
        if (await bd.existeCorreo(email)) throw ErrorApi(409, 'Ya hay una cuenta con ese correo. Inicia sesión.');

        // Quien se registra solo es socio: los demás roles los da la gerencia.
        final int id;
        try {
          id = await bd.crearUsuario(email: email, nombre: nombre, contrasena: pass, rol: 'socio');
        } on CorreoRepetido {
          // Dos altas a la vez con el mismo correo: la segunda choca con UNIQUE.
          throw ErrorApi(409, 'Ya hay una cuenta con ese correo. Inicia sesión.');
        }
        _altasIp.fallo(ip);
        alRegistrar?.call('Nueva cuenta de socio (#$id)');
        final token = await bd.crearSesion(id);
        return _json(201, {'token': token, 'usuario': _usuarioJson((await bd.usuarioPorId(id))!, conSecreto: true)});
      });

  Future<Response> _login(Request req) => _seguro(req, () async {
        final ip = _ip(req);
        final d = await _cuerpo(req);
        final email = (_cadena(d, 'email') ?? '').trim().toLowerCase();
        if (email.length > 254) throw ErrorApi(400, 'Escribe tu correo y tu contraseña.');
        final correoIp = '$email|$ip';
        if (_fallosIp.bloqueado(ip) || _fallosCorreoIp.bloqueado(correoIp) || _fallosCorreo.bloqueado(email)) {
          throw ErrorApi(429, 'Demasiados intentos fallidos. Espera 15 minutos antes de volver a probar.');
        }
        if (!captchas.comprobar(_cadena(d, 'captchaId'), _cadena(d, 'captcha'))) {
          throw ErrorApi(400, 'El código de verificación no es correcto o ha caducado. Escribe el nuevo.');
        }
        final pass = d['password'];
        if (email.isEmpty || pass is! String || pass.isEmpty || pass.length > 128) {
          throw ErrorApi(400, 'Escribe tu correo y tu contraseña.');
        }
        final u = await bd.usuarioPorCorreo(email);
        final ok = u == null
            ? await trabajoSenuelo(pass).then((_) => false)
            : await verificarContrasena(pass, u['hash'] as String);
        if (!ok) {
          _fallosIp.fallo(ip);
          _fallosCorreoIp.fallo(correoIp);
          _fallosCorreo.fallo(email);
          alRegistrar?.call('Inicio de sesión fallido');
          // Mismo mensaje exista o no la cuenta: no se revela qué correos hay.
          throw ErrorApi(401, 'Correo o contraseña incorrectos. Si no tienes cuenta, regístrate primero.');
        }
        _fallosCorreoIp.limpiar(correoIp);
        alRegistrar?.call('Sesión iniciada (#${u!['id']}, ${u['rol']})');
        return _json(200, {'token': await bd.crearSesion(u!['id'] as int), 'usuario': _usuarioJson(u, conSecreto: true)});
      });

  // ---------------------------------------------------------- con sesión

  Future<Response> _salir(Request req) => _seguro(req, () async {
        final t = _token(req);
        if (t != null) await bd.cerrarSesion(t);
        return _json(200, {'ok': true});
      });

  Future<Response> _yo(Request req) => _seguro(req, () async => _json(200, {'usuario': _usuarioJson(await _sesion(req), conSecreto: true)}));

  Future<Response> _cambiarContrasena(Request req) => _seguro(req, () async {
        final u = await _sesion(req);
        final d = await _cuerpo(req);
        final actual = d['actual'], nueva = d['nueva'], nueva2 = d['nueva2'];
        if (actual is! String || nueva is! String || nueva2 is! String) throw ErrorApi(400, 'Faltan datos.');
        if (_cambiosContrasena.bloqueado('${u['id']}')) throw ErrorApi(429, 'Demasiados intentos. Espera 15 minutos.');
        if (actual.length > 128) throw ErrorApi(400, 'La contraseña actual no es correcta.');
        if (!await verificarContrasena(actual, u['hash'] as String)) {
          _cambiosContrasena.fallo('${u['id']}');
          throw ErrorApi(400, 'La contraseña actual no es correcta.');
        }
        final problema = problemaContrasena(nueva);
        if (problema != null) throw ErrorApi(400, problema);
        if (nueva != nueva2) throw ErrorApi(400, 'Las contraseñas nuevas no coinciden.');
        await bd.cambiarHash(u['id'] as int, await hashContrasena(nueva));
        await bd.cerrarOtrasSesiones(u['id'] as int, _token(req)!);
        alRegistrar?.call('Contraseña cambiada (#${u['id']})');
        return _json(200, {'ok': true});
      });

  Future<Response> _suscribir(Request req) => _seguro(req, () async {
        final u = await _sesion(req, roles: ['socio']);
        final d = await _cuerpo(req);
        final plan = planPorId(_cadena(d, 'plan'));
        if (plan == null) throw ErrorApi(400, 'Ese plan no existe.');
        await bd.suscribir(u['id'] as int, plan.id);
        alRegistrar?.call('Suscripción ${plan.nombre} (#${u['id']})');
        return _json(200, {'usuario': _usuarioJson((await bd.usuarioPorId(u['id'] as int))!, conSecreto: true)});
      });

  Future<Response> _contacto(Request req) => _seguro(req, () async {
        final u = await _sesion(req);
        final clave = 'contacto:${u['id']}';
        if (_mensajesUsuario.bloqueado(clave)) throw ErrorApi(429, 'Has enviado muchos mensajes seguidos. Espera un poco.');
        final d = await _cuerpo(req);
        final asunto = _texto(d, 'asunto', min: 3, max: 80, nombre: 'el asunto');
        final texto = _texto(d, 'texto', min: 10, max: 2000, nombre: 'el mensaje');
        await bd.guardarMensaje(usuarioId: u['id'] as int, asunto: asunto, texto: texto);
        _mensajesUsuario.fallo(clave);
        alRegistrar?.call('Mensaje nuevo para gerencia');
        return _json(201, {'ok': true});
      });

  // ------------------------------------------------------------ gerencia

  Future<Response> _mensajes(Request req) => _seguro(req, () async {
        await _sesion(req, roles: ['admin']);
        return _json(200, {
          'mensajes': [
            for (final m in await bd.mensajes())
              {
                'id': m['id'],
                'asunto': m['asunto'],
                'texto': m['texto'],
                'fecha': m['fecha'],
                'leido': m['leido'] == 1,
                'nombre': m['nombre'],
                'email': m['email'],
                'rol': m['rol'],
              }
          ]
        });
      });

  Future<Response> _leido(Request req, String id) => _seguro(req, () async {
        await _sesion(req, roles: ['admin']);
        if (!await bd.marcarLeido(int.parse(id))) throw ErrorApi(404, 'Ese mensaje no existe.');
        return _json(200, {'ok': true});
      });

  Future<Response> _usuarios(Request req) => _seguro(req, () async {
        await _sesion(req, roles: ['admin']);
        return _json(200, {
          'usuarios': [for (final u in await bd.usuarios()) _usuarioJson(u)],
          'recuento': await bd.recuento(),
        });
      });

  Future<Response> _crearCuenta(Request req) => _seguro(req, () async {
        final admin = await _sesion(req, roles: ['admin']);
        final d = await _cuerpo(req);
        final nombre = _texto(d, 'nombre', min: 2, max: 60, nombre: 'el nombre');
        final email = _texto(d, 'email', min: 3, max: 254, nombre: 'el correo').toLowerCase();
        final rol = d['rol'];
        final pass = d['password'], pass2 = d['password2'];
        // Desde gerencia se abren cuentas de trabajador (o de socio). No se
        // pueden crear más administradores desde la app.
        if (rol != 'trabajador' && rol != 'socio') throw ErrorApi(400, 'El rol tiene que ser trabajador o socio.');
        if (!correoValido(email)) throw ErrorApi(400, 'El correo no tiene un formato válido.');
        if (pass is! String || pass2 is! String) throw ErrorApi(400, 'Falta la contraseña.');
        final problema = problemaContrasena(pass);
        if (problema != null) throw ErrorApi(400, problema);
        if (pass != pass2) throw ErrorApi(400, 'Las contraseñas no coinciden.');
        if (await bd.existeCorreo(email)) throw ErrorApi(409, 'Ya hay una cuenta con ese correo.');
        final id = await bd.crearUsuario(
            email: email, nombre: nombre, contrasena: pass, rol: rol as String, creadoPor: admin['id'] as int);
        alRegistrar?.call('Gerencia crea cuenta de $rol (#$id)');
        return _json(201, {'usuario': _usuarioJson((await bd.usuarioPorId(id))!)});
      });

  // ------------------------------------------------------------ fichajes

  static Map<String, Object?> _fichajeJson(Fila f) => {
        'id': f['id'],
        'usuarioId': f['usuario_id'],
        'empleado': f['empleado'],
        'tipo': f['tipo'],
        'momento': f['momento'],
        'registrado': f['registrado'],
        'autor': f['autor'],
        'corrigeA': f['corrige_a'],
        'motivo': f['motivo'],
      };

  /// Tipos de fichaje permitidos según el último (mismas reglas que la demo).
  static List<String> posibles(String? ultimo) => switch (ultimo) {
        null || 'salida' => ['entrada'],
        'entrada' || 'vuelta' => ['pausa', 'salida'],
        'pausa' => ['vuelta'],
        _ => ['entrada'],
      };

  Future<Response> _fichajes(Request req) => _seguro(req, () async {
        final u = await _sesion(req, roles: ['admin', 'trabajador']);
        // Un trabajador solo ve sus propios fichajes.
        final propios = u['rol'] == 'trabajador';
        final lista = await bd.fichajes(usuarioId: propios ? u['id'] as int : null);
        final plantilla = propios
            ? [u]
            : (await bd.usuarios()).where((x) => x['rol'] == 'trabajador' || x['rol'] == 'admin').toList();
        return _json(200, {
          'fichajes': [for (final f in lista) _fichajeJson(f)],
          'plantilla': [
            for (final p in plantilla)
              {
                'id': p['id'],
                'nombre': p['nombre'],
                'email': p['email'],
                'rol': p['rol'],
                'ultimo': await bd.ultimoTipo(p['id'] as int),
                'posibles': posibles(await bd.ultimoTipo(p['id'] as int)),
              }
          ],
          'puedeModificar': !propios,
        });
      });

  Future<Response> _fichar(Request req) => _seguro(req, () async {
        final admin = await _sesion(req, roles: ['admin']);
        final d = await _cuerpo(req);
        final id = d['usuarioId'];
        final tipo = d['tipo'];
        if (id is! int || tipo is! String || !tiposFichaje.contains(tipo)) throw ErrorApi(400, 'Datos de fichaje no válidos.');
        final empleado = await bd.usuarioPorId(id);
        if (empleado == null || empleado['rol'] == 'socio') throw ErrorApi(404, 'Ese empleado no existe.');
        if (!posibles(await bd.ultimoTipo(id)).contains(tipo)) {
          throw ErrorApi(409, 'Ese fichaje no encaja con el anterior (${await bd.ultimoTipo(id) ?? 'ninguno'}).');
        }
        await bd.fichar(usuarioId: id, tipo: tipo, autorId: admin['id'] as int);
        return _json(201, {'ok': true});
      });

  Future<Response> _corregir(Request req, String idTexto) => _seguro(req, () async {
        final admin = await _sesion(req, roles: ['admin']);
        final original = await bd.fichaje(int.parse(idTexto));
        if (original == null) throw ErrorApi(404, 'Ese fichaje no existe.');
        // Se corrige siempre el registro original y una sola vez: así una
        // cadena de correcciones no puede ir moviendo un fichaje sin límite.
        if (original['corrige_a'] != null) throw ErrorApi(409, 'Eso ya es una corrección: corrige el registro original.');
        if (await bd.yaCorregido(original['id'] as int)) throw ErrorApi(409, 'Ese fichaje ya se corrigió.');
        final d = await _cuerpo(req);
        final motivo = _texto(d, 'motivo', min: 3, max: 200, nombre: 'el motivo');
        final momento = DateTime.tryParse(d['momento'] is String ? d['momento'] as String : '');
        if (momento == null) throw ErrorApi(400, 'La hora corregida no es válida.');
        final antes = DateTime.parse(original['momento'] as String);
        if (momento.difference(antes).inHours.abs() > 24) throw ErrorApi(400, 'La corrección no puede mover el fichaje más de 24 horas.');
        if (momento.isAfter(DateTime.now().add(const Duration(minutes: 1)))) {
          throw ErrorApi(400, 'No se puede fichar en el futuro.');
        }
        await bd.fichar(
          usuarioId: original['usuario_id'] as int,
          tipo: original['tipo'] as String,
          autorId: admin['id'] as int,
          momento: momento,
          corrigeA: original['id'] as int,
          motivo: motivo,
        );
        return _json(201, {'ok': true});
      });

  /// Evita que una celda se ejecute como fórmula al abrir el CSV en Excel.
  static String _celda(Object? v) {
    var t = (v ?? '').toString().replaceAll(RegExp(r'[\r\n;]'), ' ');
    if (t.isNotEmpty && '=+-@\t'.contains(t[0])) t = "'$t";
    return t;
  }

  Future<Response> _csv(Request req) => _seguro(req, () async {
        await _sesion(req, roles: ['admin']);
        final b = StringBuffer('empleado;correo;tipo;fecha_hora;registrado;autor;corrige_a;motivo\n');
        for (final f in (await bd.fichajes()).reversed) {
          b.writeln([
            f['empleado'],
            f['empleado_email'],
            f['tipo'],
            f['momento'],
            f['registrado'],
            f['autor'],
            f['corrige_a'],
            f['motivo'],
          ].map(_celda).join(';'));
        }
        return Response.ok(b.toString(), headers: {
          'content-type': 'text/csv; charset=utf-8',
          'content-disposition': 'attachment; filename="registro-jornada.csv"',
          'cache-control': 'no-store',
        });
      });

  // --------------------------------------------------------------- acceso

  Future<Response> _validarAcceso(Request req) => _seguro(req, () async {
        final lector = await _sesion(req, roles: ['admin', 'trabajador']);
        final clave = '${lector['id']}';
        if (_lecturasLector.bloqueado(clave)) throw ErrorApi(429, 'Demasiadas lecturas seguidas. Espera un momento.');
        _lecturasLector.fallo(clave);
        final d = await _cuerpo(req);
        final token = d['token'];
        if (token is! String || token.length > 100) throw ErrorApi(400, 'Pase no válido.');
        final p = token.split('-');
        final uid = p.length == 4 && p[0] == 'FORJA2' ? int.tryParse(p[1]) : null;
        final ventana = uid == null ? null : int.tryParse(p[2]);
        final socio = uid == null ? null : await bd.usuarioPorId(uid);
        if (socio == null || ventana == null || socio['rol'] != 'socio') {
          return _json(200, {'resultado': 'desconocido'});
        }
        final firmaOk = igualesSeguro(
          utf8.encode(firmaQr(socio['qr_secreto'] as String, uid!, ventana)),
          utf8.encode(p[3]),
        );
        if (!firmaOk) return _json(200, {'resultado': 'desconocido'});
        final edad = ventanaQr() - ventana;
        final String resultado;
        // Un código vale una sola vez: una foto del QR no deja pasar a otro
        // aunque se enseñe dentro de los mismos segundos.
        final yaUsado = ventana <= (_ultimaVentanaQr[uid] ?? -1);
        if (edad < -1 || edad > 1 || yaUsado) {
          resultado = 'qrCaducado';
        } else if (socio['plan'] == null) {
          resultado = 'cuotaPendiente';
        } else {
          resultado = 'concedido';
          _ultimaVentanaQr[uid] = ventana;
        }
        await bd.registrarAcceso(usuarioId: uid, resultado: resultado, lectorId: lector['id'] as int);
        return _json(200, {
          'resultado': resultado,
          'socio': {'id': uid, 'nombre': socio['nombre'], 'plan': socio['plan']},
        });
      });
}

/// Web publicada en GitHub Pages, que también puede usar este servidor.
const origenPages = 'https://martinezmendezalv-hue.github.io';

/// Orígenes web que pueden llamar a la API desde el navegador: la propia
/// web que sirve el servidor, la de GitHub Pages y localhost (desarrollo).
/// Las apps de Windows y Android no envían Origin y no necesitan CORS.
bool origenPermitido(String origen, String? host) {
  if (origen == origenPages) return true;
  final u = Uri.tryParse(origen);
  if (u == null || (u.scheme != 'http' && u.scheme != 'https')) return false;
  if (u.host == 'localhost' || u.host == '127.0.0.1') return true;
  return host != null && (origen == 'http://$host' || origen == 'https://$host');
}

/// Política de contenido para la web de ForjaApp (Flutter carga CanvasKit
/// y las fuentes de reserva desde gstatic.com).
const _csp = "default-src 'self'; "
    "script-src 'self' 'wasm-unsafe-eval' https://www.gstatic.com; "
    "connect-src 'self' https://www.gstatic.com https://fonts.gstatic.com; "
    "font-src 'self' data: https://fonts.gstatic.com; "
    "style-src 'self' 'unsafe-inline'; "
    "img-src 'self' data: blob:; "
    "worker-src 'self' blob:; "
    "object-src 'none'; base-uri 'self'; form-action 'self'; frame-ancestors 'none'";

/// Cabeceras comunes: CORS solo para orígenes conocidos y cabeceras de seguridad.
Middleware cabeceras() => (inner) => (req) async {
      final origen = req.headers['origin'];
      final cors = <String, String>{
        'vary': 'origin',
        if (origen != null && origenPermitido(origen, req.headers['host'])) ...{
          'access-control-allow-origin': origen,
          'access-control-allow-methods': 'GET, POST, OPTIONS',
          'access-control-allow-headers': 'authorization, content-type',
          'access-control-allow-private-network': 'true',
          'access-control-max-age': '600',
        },
      };
      final api = req.url.path.startsWith('api/');
      final seguridad = {
        'x-content-type-options': 'nosniff',
        'x-frame-options': 'DENY',
        'referrer-policy': 'no-referrer',
        'permissions-policy': 'geolocation=(), microphone=()',
        'cross-origin-opener-policy': 'same-origin',
        'content-security-policy': api ? "default-src 'none'; frame-ancestors 'none'" : _csp,
        if (api) 'cross-origin-resource-policy': 'same-site',
      };
      if (req.method == 'OPTIONS') return Response(204, headers: {...cors, ...seguridad});
      final r = await inner(req);
      return r.change(headers: {...cors, ...seguridad});
    };
