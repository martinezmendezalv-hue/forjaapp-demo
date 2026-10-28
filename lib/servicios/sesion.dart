import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';

/// Sesión de la app: a qué servidor se conecta y quién ha entrado.
///
/// El token de sesión solo vive en memoria: al cerrar la app hay que volver
/// a iniciar sesión. En el dispositivo solo se guardan la dirección del
/// servidor y el último correo usado.
class Sesion extends ChangeNotifier {
  Sesion() : api = ForjaApi(_servidorPorDefecto());

  final ForjaApi api;
  Usuario? usuario;
  String ultimoCorreo = '';

  /// Tras registrarse se enseñan los planes nada más entrar.
  bool mostrarPlanes = false;

  bool get iniciada => usuario != null;
  String get servidor => api.base;

  /// Servidor de ForjaApp en internet (Render + base de datos Neon): funciona
  /// desde cualquier red, con datos móviles o con otra wifi.
  static const servidorNube =
      String.fromEnvironment('SERVIDOR_NUBE', defaultValue: 'https://forjaapp-servidor.onrender.com');

  /// La web que sirve un ForjaApp Servidor (el de la nube o el del PC del
  /// gimnasio) usa siempre ese mismo servidor.
  static bool get _webDeUnServidor =>
      kIsWeb && (Uri.base.scheme == 'http' || Uri.base.scheme == 'https') && !Uri.base.host.endsWith('github.io');

  static String _servidorPorDefecto() => _webDeUnServidor ? Uri.base.origin : servidorNube;

  Future<void> cargar() async {
    try {
      final p = await SharedPreferences.getInstance();
      final guardado = p.getString('servidor');
      if (guardado != null && guardado.isNotEmpty && !_webDeUnServidor) api.base = guardado;
      ultimoCorreo = p.getString('correo') ?? '';
    } catch (_) {}
    notifyListeners();
  }

  /// Normaliza «192.168.1.40» → «http://192.168.1.40:8080».
  static String normalizar(String texto) {
    var t = texto.trim();
    if (t.isEmpty) return t;
    if (!t.startsWith('http://') && !t.startsWith('https://')) t = 'http://$t';
    final u = Uri.tryParse(t);
    if (u == null || u.host.isEmpty) return t;
    // Sin puerto: el del PC del gimnasio es 8080; por https, el normal (443).
    final puerto = u.hasPort ? u.port : (u.scheme == 'http' ? 8080 : null);
    return Uri(scheme: u.scheme, host: u.host, port: puerto)
        .toString()
        .replaceAll(RegExp(r'/$'), '');
  }

  /// Si la dirección es el servidor de la nube de ForjaApp, este equipo o
  /// una red local (192.168…, 10…,
  /// 172.16-31…). Un QR que lleve a otro sitio podría ser una trampa para
  /// robar contraseñas, así que la app avisa antes de usarlo.
  static bool esDeConfianza(String direccion) {
    if (normalizar(direccion) == servidorNube) return true;
    final host = Uri.tryParse(normalizar(direccion))?.host ?? '';
    if (host == 'localhost' || host.endsWith('.local')) return true;
    final p = host.split('.').map(int.tryParse).toList();
    if (p.length != 4 || p.any((n) => n == null || n < 0 || n > 255)) return false;
    final a = p[0]!, b = p[1]!;
    return a == 10 || a == 127 || (a == 192 && b == 168) || (a == 172 && b >= 16 && b <= 31);
  }

  Future<void> cambiarServidor(String direccion) async {
    api.base = normalizar(direccion);
    try {
      (await SharedPreferences.getInstance()).setString('servidor', api.base);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> entrar(String token, Usuario u) async {
    api.token = token;
    usuario = u;
    ultimoCorreo = u.email;
    try {
      (await SharedPreferences.getInstance()).setString('correo', u.email);
    } catch (_) {}
    notifyListeners();
  }

  void actualizar(Usuario u) {
    usuario = u;
    notifyListeners();
  }

  Future<void> salir() async {
    await api.salir();
    api.token = null;
    usuario = null;
    notifyListeners();
  }
}

/// Única sesión de la app.
final sesion = Sesion();
