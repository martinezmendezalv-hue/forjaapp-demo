import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:forja_servidor/src/api.dart';
import 'package:forja_servidor/src/bd.dart';
import 'package:forja_servidor/src/correo.dart';
import 'package:forja_servidor/src/seguridad.dart';
import 'package:shelf/shelf.dart';

late BaseDatos bd;
late ForjaApi api;
late BuzonFalso buzon;

/// Guarda los correos en vez de enviarlos.
class BuzonFalso implements EnvioCorreo {
  final enviados = <({String para, String texto})>[];

  @override
  Future<void> enviar({required String para, required String asunto, required String texto, required String html}) async =>
      enviados.add((para: para, texto: texto));

  /// El código de 6 cifras del último correo enviado a [para].
  String codigoPara(String para) =>
      RegExp(r'\b(\d{6})\b').firstMatch(enviados.lastWhere((c) => c.para == para).texto)!.group(1)!;
}

Future<({int estado, Map<String, dynamic> json, String texto})> pedir(
  String metodo,
  String ruta, {
  Map<String, Object?>? cuerpo,
  String? token,
}) async {
  final r = await api.handler(Request(
    metodo,
    Uri.parse('http://localhost$ruta'),
    body: cuerpo == null ? null : jsonEncode(cuerpo),
    headers: {
      if (cuerpo != null) 'content-type': 'application/json',
      if (token != null) 'authorization': 'Bearer $token',
    },
  ));
  final texto = await r.readAsString();
  Map<String, dynamic> json = {};
  try {
    json = jsonDecode(texto) as Map<String, dynamic>;
  } catch (_) {}
  return (estado: r.statusCode, json: json, texto: texto);
}

String captcha() => api.captchas.crearConTexto('AB23CD');

Future<String> entrar(String email, String pass) async {
  final r = await pedir('POST', '/api/login',
      cuerpo: {'email': email, 'password': pass, 'captchaId': captcha(), 'captcha': 'ab23cd'});
  expect(r.estado, 200, reason: r.texto);
  return r.json['token'] as String;
}

Future<String> registrar(String email, {String nombre = 'Lucía Gómez'}) async {
  final r = await pedir('POST', '/api/registro', cuerpo: {
    'nombre': nombre,
    'email': email,
    'password': 'Clave1234',
    'password2': 'Clave1234',
    'acepta': true,
    'captchaId': captcha(),
    'captcha': 'AB23CD',
  });
  expect(r.estado, 201, reason: r.texto);
  return r.json['token'] as String;
}

Future<void> crearTrabajador(String admin, String email, {String nombre = 'Ana Martín'}) async {
  final r = await pedir('POST', '/api/usuarios',
      cuerpo: {'nombre': nombre, 'email': email, 'password': 'Trabajo12', 'password2': 'Trabajo12', 'rol': 'trabajador'},
      token: admin);
  expect(r.estado, 201, reason: r.texto);
}

void main() {
  setUp(() async {
    iteracionesPbkdf2 = 1000;
    // Con FORJA_PG_PRUEBAS=postgres://… las mismas pruebas van contra
    // Postgres (se vacía la base de datos antes de cada una).
    final pgUrl = Platform.environment['FORJA_PG_PRUEBAS'];
    if (pgUrl == null) {
      bd = await BaseDatos.abrir(null);
    } else {
      final limpia = await BaseDatos.conectar(pgUrl);
      await limpia.ejecutar('DROP TABLE IF EXISTS restablecimientos, accesos, mensajes, fichajes, sesiones, usuarios CASCADE');
      await limpia.cerrar();
      bd = await BaseDatos.conectar(pgUrl);
    }
    buzon = BuzonFalso();
    api = ForjaApi(bd, correo: buzon);
  });
  tearDown(() => bd.cerrar());

  test('la cuenta de gerencia existe y entra con su contraseña', () async {
    final t = await entrar(correoAdmin, 'alvaro');
    final yo = await pedir('GET', '/api/yo', token: t);
    expect(yo.json['usuario']['rol'], 'admin');
    expect((yo.json['usuario'] as Map).containsKey('qrSecreto'), isFalse);
  });

  test('sin registrarse no se puede iniciar sesión', () async {
    final r = await pedir('POST', '/api/login',
        cuerpo: {'email': 'nadie@forja.es', 'password': 'Clave1234', 'captchaId': captcha(), 'captcha': 'AB23CD'});
    expect(r.estado, 401);
    expect(r.json['error'], contains('regístrate'));
  });

  test('el captcha es obligatorio, de un solo uso y no vale uno inventado', () async {
    final id = captcha();
    final mal = await pedir('POST', '/api/login',
        cuerpo: {'email': correoAdmin, 'password': 'alvaro', 'captchaId': id, 'captcha': 'XXXXXX'});
    expect(mal.estado, 400);
    final reusado = await pedir('POST', '/api/login',
        cuerpo: {'email': correoAdmin, 'password': 'alvaro', 'captchaId': id, 'captcha': 'AB23CD'});
    expect(reusado.estado, 400);
    final sin = await pedir('POST', '/api/login', cuerpo: {'email': correoAdmin, 'password': 'alvaro'});
    expect(sin.estado, 400);
  });

  test('el captcha es una imagen PNG y la respuesta no lleva el texto', () async {
    final r = await pedir('GET', '/api/captcha');
    expect(r.estado, 200);
    final png = base64.decode(r.json['imagen'] as String);
    expect(png.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
    expect(r.json.keys.toSet(), {'id', 'imagen'});
  });

  test('el registro valida contraseñas y condiciones, y siempre crea un socio', () async {
    Future<int> intento(Map<String, Object?> cambios) async {
      final base = <String, Object?>{
        'nombre': 'Pablo Ruiz',
        'email': 'pablo@forja.es',
        'password': 'Clave1234',
        'password2': 'Clave1234',
        'acepta': true,
        'captchaId': captcha(),
        'captcha': 'AB23CD',
      }..addAll(cambios);
      return (await pedir('POST', '/api/registro', cuerpo: base)).estado;
    }

    expect(await intento({'password2': 'Otra1234'}), 400);
    expect(await intento({'password': 'corta1', 'password2': 'corta1'}), 400);
    expect(await intento({'password': 'sololetras', 'password2': 'sololetras'}), 400);
    expect(await intento({'acepta': false}), 400);
    expect(await intento({'email': 'no-es-un-correo'}), 400);
    expect(await intento({'rol': 'admin'}), 201, reason: 'el rol enviado se ignora');
    final t = await entrar('pablo@forja.es', 'Clave1234');
    final yo = await pedir('GET', '/api/yo', token: t);
    expect(yo.json['usuario']['rol'], 'socio');
    expect(await intento({}), 409, reason: 'el correo ya existe');
  });

  test('cinco contraseñas mal seguidas bloquean el correo', () async {
    for (var i = 0; i < 5; i++) {
      final r = await pedir('POST', '/api/login',
          cuerpo: {'email': correoAdmin, 'password': 'mal$i', 'captchaId': captcha(), 'captcha': 'AB23CD'});
      expect(r.estado, 401);
    }
    final r = await pedir('POST', '/api/login',
        cuerpo: {'email': correoAdmin, 'password': 'alvaro', 'captchaId': captcha(), 'captcha': 'AB23CD'});
    expect(r.estado, 429);
  });

  test('solo gerencia abre cuentas y no puede crear otro admin', () async {
    final admin = await entrar(correoAdmin, 'alvaro');
    final socio = await registrar('lucia@forja.es');
    final cuenta = {
      'nombre': 'Ana Martín',
      'email': 'ana@forja.es',
      'password': 'Recepcion1',
      'password2': 'Recepcion1',
      'rol': 'trabajador',
    };
    expect((await pedir('POST', '/api/usuarios', cuerpo: cuenta, token: socio)).estado, 403);
    expect((await pedir('POST', '/api/usuarios', cuerpo: {...cuenta, 'rol': 'admin'}, token: admin)).estado, 400);
    expect((await pedir('POST', '/api/usuarios', cuerpo: cuenta, token: admin)).estado, 201);
    expect((await pedir('GET', '/api/usuarios', token: socio)).estado, 403);
    expect((await pedir('GET', '/api/usuarios')).estado, 401);
  });

  test('fichajes: gerencia ficha y corrige; el trabajador solo ve los suyos', () async {
    final admin = await entrar(correoAdmin, 'alvaro');
    await crearTrabajador(admin, 'ana@forja.es');
    await crearTrabajador(admin, 'hugo@forja.es', nombre: 'Hugo Prieto');
    final ana = (await bd.usuarioPorCorreo('ana@forja.es'))!['id'] as int;
    final hugo = (await bd.usuarioPorCorreo('hugo@forja.es'))!['id'] as int;
    expect((await pedir('POST', '/api/fichajes', cuerpo: {'usuarioId': ana, 'tipo': 'entrada'}, token: admin)).estado, 201);
    expect((await pedir('POST', '/api/fichajes', cuerpo: {'usuarioId': hugo, 'tipo': 'entrada'}, token: admin)).estado, 201);
    expect((await pedir('POST', '/api/fichajes', cuerpo: {'usuarioId': ana, 'tipo': 'vuelta'}, token: admin)).estado, 409);

    final tAna = await entrar('ana@forja.es', 'Trabajo12');
    final suyos = await pedir('GET', '/api/fichajes', token: tAna);
    expect(suyos.estado, 200);
    expect((suyos.json['fichajes'] as List).every((f) => f['usuarioId'] == ana), isTrue);
    expect(suyos.json['puedeModificar'], isFalse);
    expect((await pedir('POST', '/api/fichajes', cuerpo: {'usuarioId': ana, 'tipo': 'salida'}, token: tAna)).estado, 403);
    final idFichaje = (suyos.json['fichajes'] as List).first['id'] as int;
    final correccion = {
      'momento': DateTime.now().subtract(const Duration(minutes: 10)).toUtc().toIso8601String(),
      'motivo': 'Llegó antes',
    };
    expect((await pedir('POST', '/api/fichajes/$idFichaje/correccion', cuerpo: correccion, token: tAna)).estado, 403);
    expect((await pedir('POST', '/api/fichajes/$idFichaje/correccion', cuerpo: correccion, token: admin)).estado, 201);
    final todos = await pedir('GET', '/api/fichajes', token: admin);
    expect((todos.json['fichajes'] as List).where((f) => f['usuarioId'] == ana).length, 2);

    final socio = await registrar('lucia@forja.es');
    expect((await pedir('GET', '/api/fichajes', token: socio)).estado, 403);
  });

  test('la base de datos no deja modificar ni borrar fichajes', () async {
    final admin = (await bd.usuarioPorCorreo(correoAdmin))!['id'] as int;
    final id = await bd.fichar(usuarioId: admin, tipo: 'entrada', autorId: admin);
    await expectLater(bd.ejecutar("UPDATE fichajes SET tipo = 'salida' WHERE id = ?", [id]), throwsA(anything));
    await expectLater(bd.ejecutar('DELETE FROM fichajes WHERE id = ?', [id]), throwsA(anything));
  });

  test('dos altas a la vez con el mismo correo: la segunda es CorreoRepetido', () async {
    await bd.crearUsuario(email: 'doble@forja.es', nombre: 'Uno', contrasena: 'Clave1234', rol: 'socio');
    await expectLater(
      bd.crearUsuario(email: 'DOBLE@forja.es', nombre: 'Dos', contrasena: 'Clave1234', rol: 'socio'),
      throwsA(isA<CorreoRepetido>()),
    );
  });

  Future<({int estado, Map<String, dynamic> json, String texto})> olvido(String email) =>
      pedir('POST', '/api/olvido', cuerpo: {'email': email, 'captchaId': captcha(), 'captcha': 'AB23CD'});

  Future<({int estado, Map<String, dynamic> json, String texto})> restablecer(String email, String codigo,
          [String nueva = 'Nueva2024x']) =>
      pedir('POST', '/api/restablecer', cuerpo: {'email': email, 'codigo': codigo, 'nueva': nueva, 'nueva2': nueva});

  test('he olvidado mi contraseña: llega un código al correo y con él se pone otra', () async {
    final viejo = await registrar('lucia@forja.es');
    final r = await olvido('lucia@forja.es');
    expect(r.estado, 200, reason: r.texto);
    await Future<void>.delayed(Duration.zero); // el envío no se espera
    expect(buzon.enviados.single.para, 'lucia@forja.es');
    final codigo = buzon.codigoPara('lucia@forja.es');

    final otro = codigo == '000000' ? '111111' : '000000';
    expect((await restablecer('lucia@forja.es', otro)).estado, 400);
    expect((await restablecer('lucia@forja.es', codigo)).estado, 200);
    // La contraseña cambia en la base de datos y las sesiones abiertas se cierran.
    expect((await pedir('GET', '/api/yo', token: viejo)).estado, 401);
    await entrar('lucia@forja.es', 'Nueva2024x');
    final conVieja = await pedir('POST', '/api/login',
        cuerpo: {'email': 'lucia@forja.es', 'password': 'Clave1234', 'captchaId': captcha(), 'captcha': 'AB23CD'});
    expect(conVieja.estado, 401);
    // El código solo sirve una vez.
    expect((await restablecer('lucia@forja.es', codigo, 'Otra2024xx')).estado, 400);
  });

  test('olvido: no revela si el correo existe y exige captcha', () async {
    final r = await olvido('nadie@forja.es');
    expect(r.estado, 200);
    await Future<void>.delayed(Duration.zero);
    expect(buzon.enviados, isEmpty);
    final sinCaptcha = await pedir('POST', '/api/olvido', cuerpo: {'email': 'nadie@forja.es'});
    expect(sinCaptcha.estado, 400);
    expect((await restablecer('nadie@forja.es', '123456')).estado, 400);
  });

  test('olvido: cinco códigos mal anulan el código y hay tope de correos', () async {
    await registrar('lucia@forja.es');
    await olvido('lucia@forja.es');
    await Future<void>.delayed(Duration.zero);
    final codigo = buzon.codigoPara('lucia@forja.es');
    final malo = codigo == '000000' ? '111111' : '000000';
    for (var i = 0; i < 5; i++) {
      expect((await restablecer('lucia@forja.es', malo)).estado, 400);
    }
    expect((await restablecer('lucia@forja.es', codigo)).estado, 400, reason: 'tras 5 fallos ya no vale');
    await olvido('lucia@forja.es');
    await olvido('lucia@forja.es');
    expect((await olvido('lucia@forja.es')).estado, 429, reason: 'máximo 3 correos por hora');
  });

  test('sin envío de correos configurado, olvido responde 503', () async {
    final sinCorreo = ForjaApi(bd);
    final r = await sinCorreo.handler(Request('POST', Uri.parse('http://localhost/api/olvido'),
        body: jsonEncode({'email': 'a@forja.es', 'captchaId': sinCorreo.captchas.crearConTexto('AB23CD'), 'captcha': 'AB23CD'}),
        headers: {'content-type': 'application/json'}));
    expect(r.statusCode, 503);
  });

  test('el CSV neutraliza fórmulas de hoja de cálculo', () async {
    final admin = await entrar(correoAdmin, 'alvaro');
    await crearTrabajador(admin, 'x@forja.es', nombre: '=HYPERLINK("http://x")');
    final id = (await bd.usuarioPorCorreo('x@forja.es'))!['id'] as int;
    await pedir('POST', '/api/fichajes', cuerpo: {'usuarioId': id, 'tipo': 'entrada'}, token: admin);
    final csv = await pedir('GET', '/api/fichajes.csv', token: admin);
    expect(csv.estado, 200);
    expect(csv.texto, contains("'=HYPERLINK"));
    expect(csv.texto, isNot(contains('\n=HYPERLINK')));
  });

  test('pase QR: vale el vigente, no uno falsificado ni uno antiguo', () async {
    final admin = await entrar(correoAdmin, 'alvaro');
    final tSocio = await registrar('lucia@forja.es');
    final yo = (await pedir('GET', '/api/yo', token: tSocio)).json['usuario'];
    final id = yo['id'] as int;
    final secreto = yo['qrSecreto'] as String;
    String pase(int v, [String? s]) => 'FORJA2-$id-$v-${firmaQr(s ?? secreto, id, v)}';

    var r = await pedir('POST', '/api/acceso', cuerpo: {'token': pase(ventanaQr())}, token: admin);
    expect(r.json['resultado'], 'cuotaPendiente', reason: 'aún no tiene plan');
    await pedir('POST', '/api/suscripcion', cuerpo: {'plan': 'premium'}, token: tSocio);
    r = await pedir('POST', '/api/acceso', cuerpo: {'token': pase(ventanaQr())}, token: admin);
    expect(r.json['resultado'], 'concedido');
    r = await pedir('POST', '/api/acceso', cuerpo: {'token': pase(ventanaQr() - 6)}, token: admin);
    expect(r.json['resultado'], 'qrCaducado');
    r = await pedir('POST', '/api/acceso', cuerpo: {'token': pase(ventanaQr(), 'secreto-falso')}, token: admin);
    expect(r.json['resultado'], 'desconocido');
    expect((await pedir('POST', '/api/acceso', cuerpo: {'token': pase(ventanaQr())}, token: tSocio)).estado, 403);
  });

  test('contacto: el mensaje llega solo a gerencia', () async {
    final admin = await entrar(correoAdmin, 'alvaro');
    final socio = await registrar('lucia@forja.es');
    final r = await pedir('POST', '/api/contacto',
        cuerpo: {'asunto': 'Horario de verano', 'texto': '¿Abrís en agosto por las tardes?'}, token: socio);
    expect(r.estado, 201);
    expect((await pedir('GET', '/api/mensajes', token: socio)).estado, 403);
    final m = await pedir('GET', '/api/mensajes', token: admin);
    expect((m.json['mensajes'] as List).single['asunto'], 'Horario de verano');
  });

  test('cerrar sesión invalida el token y no se filtran errores internos', () async {
    final t = await entrar(correoAdmin, 'alvaro');
    await pedir('POST', '/api/salir', token: t);
    expect((await pedir('GET', '/api/yo', token: t)).estado, 401);
    final raro = await pedir('POST', '/api/login');
    expect(raro.estado, 415);
    expect(raro.texto, isNot(contains('Exception')));
  });

  test('cambiar la contraseña exige la actual y cierra las otras sesiones', () async {
    final t1 = await entrar(correoAdmin, 'alvaro');
    final t2 = await entrar(correoAdmin, 'alvaro');
    final mal = await pedir('POST', '/api/contrasena',
        cuerpo: {'actual': 'otra', 'nueva': 'Nueva1234', 'nueva2': 'Nueva1234'}, token: t1);
    expect(mal.estado, 400);
    final bien = await pedir('POST', '/api/contrasena',
        cuerpo: {'actual': 'alvaro', 'nueva': 'Nueva1234', 'nueva2': 'Nueva1234'}, token: t1);
    expect(bien.estado, 200);
    expect((await pedir('GET', '/api/yo', token: t2)).estado, 401);
    expect((await pedir('GET', '/api/yo', token: t1)).estado, 200);
  });

  test('un pase QR solo abre una vez (una foto no sirve)', () async {
    final admin = await entrar(correoAdmin, 'alvaro');
    final tSocio = await registrar('lucia@forja.es');
    await pedir('POST', '/api/suscripcion', cuerpo: {'plan': 'comfort'}, token: tSocio);
    final yo = (await pedir('GET', '/api/yo', token: tSocio)).json['usuario'];
    final id = yo['id'] as int;
    final v = ventanaQr();
    final pase = 'FORJA2-$id-$v-${firmaQr(yo['qrSecreto'] as String, id, v)}';
    expect((await pedir('POST', '/api/acceso', cuerpo: {'token': pase}, token: admin)).json['resultado'], 'concedido');
    expect((await pedir('POST', '/api/acceso', cuerpo: {'token': pase}, token: admin)).json['resultado'], 'qrCaducado');
  });

  test('un fichaje se corrige una sola vez y siempre desde el original', () async {
    final admin = await entrar(correoAdmin, 'alvaro');
    await crearTrabajador(admin, 'ana@forja.es');
    final ana = (await bd.usuarioPorCorreo('ana@forja.es'))!['id'] as int;
    await pedir('POST', '/api/fichajes', cuerpo: {'usuarioId': ana, 'tipo': 'entrada'}, token: admin);
    final original = ((await pedir('GET', '/api/fichajes', token: admin)).json['fichajes'] as List).first['id'] as int;
    final cuerpo = {
      'momento': DateTime.now().subtract(const Duration(minutes: 20)).toUtc().toIso8601String(),
      'motivo': 'Llegó antes',
    };
    expect((await pedir('POST', '/api/fichajes/$original/correccion', cuerpo: cuerpo, token: admin)).estado, 201);
    expect((await pedir('POST', '/api/fichajes/$original/correccion', cuerpo: cuerpo, token: admin)).estado, 409);
    final correccion = ((await pedir('GET', '/api/fichajes', token: admin)).json['fichajes'] as List)
        .firstWhere((f) => f['corrigeA'] == original)['id'] as int;
    expect((await pedir('POST', '/api/fichajes/$correccion/correccion', cuerpo: cuerpo, token: admin)).estado, 409);
  });

  test('CORS solo para orígenes conocidos y CSP en todas las respuestas', () async {
    final h = const Pipeline().addMiddleware(cabeceras()).addHandler(api.handler);
    Future<Response> con(String origen) => Future.value(h(Request('GET', Uri.parse('http://192.168.1.40:8080/api/salud'),
        headers: {'origin': origen, 'host': '192.168.1.40:8080'})));
    expect((await con('https://malo.example')).headers['access-control-allow-origin'], isNull);
    expect((await con('http://192.168.1.40:8080')).headers['access-control-allow-origin'], 'http://192.168.1.40:8080');
    expect((await con(origenPages)).headers['access-control-allow-origin'], origenPages);
    expect((await con('http://localhost:5000')).headers['content-security-policy'], contains("default-src 'none'"));
  });

  test('datos con tipos raros dan 400, no un error interno', () async {
    final r = await pedir('POST', '/api/login', cuerpo: {'email': 5, 'password': [], 'captchaId': 7, 'captcha': {}});
    expect(r.estado, 400);
  });
}
