import 'package:sqlite3/sqlite3.dart';

import 'seguridad.dart';

/// Cuenta de gerencia que se crea la primera vez que arranca el servidor.
const correoAdmin = 'martinez.mendez.alv@gmail.com';
const _contrasenaInicialAdmin = 'alvaro';
const nombreAdmin = 'Álvaro Martínez';

const roles = ['admin', 'trabajador', 'socio'];
const tiposFichaje = ['entrada', 'pausa', 'vuelta', 'salida'];

String ahoraIso() => DateTime.now().toUtc().toIso8601String();

/// Acceso a la base de datos SQLite. Todas las consultas van con
/// parámetros (?), nunca concatenando texto del usuario.
class BaseDatos {
  BaseDatos._(this.db);

  final Database db;

  static Future<BaseDatos> abrir(String? ruta) async {
    final db = ruta == null ? sqlite3.openInMemory() : sqlite3.open(ruta);
    final bd = BaseDatos._(db);
    bd._crearTablas();
    await bd._crearAdmin();
    return bd;
  }

  void cerrar() => db.dispose();

  void _crearTablas() {
    db.execute('PRAGMA foreign_keys = ON;');
    db.execute('PRAGMA journal_mode = WAL;');
    db.execute('''
      CREATE TABLE IF NOT EXISTS usuarios (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        email       TEXT NOT NULL UNIQUE COLLATE NOCASE,
        nombre      TEXT NOT NULL,
        hash        TEXT NOT NULL,
        rol         TEXT NOT NULL CHECK (rol IN ('admin', 'trabajador', 'socio')),
        plan        TEXT CHECK (plan IN ('comfort', 'premium', 'ultimate')),
        plan_desde  TEXT,
        qr_secreto  TEXT NOT NULL,
        creado      TEXT NOT NULL,
        creado_por  INTEGER REFERENCES usuarios(id)
      );
      CREATE TABLE IF NOT EXISTS sesiones (
        token_hash  TEXT PRIMARY KEY,
        usuario_id  INTEGER NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
        caduca      TEXT NOT NULL
      );
      CREATE TABLE IF NOT EXISTS fichajes (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        usuario_id  INTEGER NOT NULL REFERENCES usuarios(id),
        tipo        TEXT NOT NULL CHECK (tipo IN ('entrada', 'pausa', 'vuelta', 'salida')),
        momento     TEXT NOT NULL,
        registrado  TEXT NOT NULL,
        autor_id    INTEGER NOT NULL REFERENCES usuarios(id),
        corrige_a   INTEGER REFERENCES fichajes(id),
        motivo      TEXT
      );
      CREATE TABLE IF NOT EXISTS mensajes (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        usuario_id  INTEGER REFERENCES usuarios(id),
        asunto      TEXT NOT NULL,
        texto       TEXT NOT NULL,
        fecha       TEXT NOT NULL,
        leido       INTEGER NOT NULL DEFAULT 0
      );
      CREATE TABLE IF NOT EXISTS accesos (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        usuario_id  INTEGER REFERENCES usuarios(id),
        resultado   TEXT NOT NULL,
        fecha       TEXT NOT NULL,
        lector_id   INTEGER REFERENCES usuarios(id)
      );
      -- Registro de jornada: nada se modifica ni se borra, ni siquiera
      -- desde fuera de la app. Una corrección es un registro nuevo.
      CREATE TRIGGER IF NOT EXISTS fichajes_no_se_modifican
        BEFORE UPDATE ON fichajes BEGIN SELECT RAISE(ABORT, 'Los fichajes no se pueden modificar'); END;
      CREATE TRIGGER IF NOT EXISTS fichajes_no_se_borran
        BEFORE DELETE ON fichajes BEGIN SELECT RAISE(ABORT, 'Los fichajes no se pueden borrar'); END;
    ''');
  }

  Future<void> _crearAdmin() async {
    final hay = db.select("SELECT 1 FROM usuarios WHERE rol = 'admin' LIMIT 1");
    if (hay.isNotEmpty) return;
    await crearUsuario(
      email: correoAdmin,
      nombre: nombreAdmin,
      contrasena: _contrasenaInicialAdmin,
      rol: 'admin',
    );
  }

  // --------------------------------------------------------- usuarios

  Future<int> crearUsuario({
    required String email,
    required String nombre,
    required String contrasena,
    required String rol,
    int? creadoPor,
  }) async {
    final hash = await hashContrasena(contrasena);
    db.execute(
      'INSERT INTO usuarios (email, nombre, hash, rol, qr_secreto, creado, creado_por) VALUES (?, ?, ?, ?, ?, ?, ?)',
      [email.trim().toLowerCase(), nombre.trim(), hash, rol, tokenAleatorio(), ahoraIso(), creadoPor],
    );
    return db.lastInsertRowId;
  }

  bool existeCorreo(String email) =>
      db.select('SELECT 1 FROM usuarios WHERE email = ? LIMIT 1', [email.trim().toLowerCase()]).isNotEmpty;

  Row? usuarioPorCorreo(String email) {
    final r = db.select('SELECT * FROM usuarios WHERE email = ?', [email.trim().toLowerCase()]);
    return r.isEmpty ? null : r.first;
  }

  Row? usuarioPorId(int id) {
    final r = db.select('SELECT * FROM usuarios WHERE id = ?', [id]);
    return r.isEmpty ? null : r.first;
  }

  List<Row> usuarios() => db.select('SELECT * FROM usuarios ORDER BY rol, nombre').toList();

  void cambiarHash(int id, String hash) => db.execute('UPDATE usuarios SET hash = ? WHERE id = ?', [hash, id]);

  void suscribir(int id, String plan) =>
      db.execute('UPDATE usuarios SET plan = ?, plan_desde = ? WHERE id = ?', [plan, ahoraIso(), id]);

  Map<String, int> recuento() {
    final r = db.select('''
      SELECT
        (SELECT COUNT(*) FROM usuarios WHERE rol = 'socio')       AS socios,
        (SELECT COUNT(*) FROM usuarios WHERE rol = 'trabajador')  AS trabajadores,
        (SELECT COUNT(*) FROM mensajes WHERE leido = 0)           AS mensajes,
        (SELECT COUNT(*) FROM fichajes)                           AS fichajes
    ''').first;
    return {for (final k in ['socios', 'trabajadores', 'mensajes', 'fichajes']) k: r[k] as int};
  }

  // ---------------------------------------------------------- sesiones

  static const duracionSesion = Duration(hours: 12);

  String crearSesion(int usuarioId) {
    db.execute("DELETE FROM sesiones WHERE caduca < ?", [ahoraIso()]);
    final token = tokenAleatorio();
    db.execute(
      'INSERT INTO sesiones (token_hash, usuario_id, caduca) VALUES (?, ?, ?)',
      [sha256Hex(token), usuarioId, DateTime.now().toUtc().add(duracionSesion).toIso8601String()],
    );
    return token;
  }

  /// Solo se guarda el hash del token: si alguien copia la base de datos
  /// no puede usar las sesiones abiertas.
  Row? usuarioDeSesion(String token) {
    final r = db.select('''
      SELECT u.* FROM sesiones s JOIN usuarios u ON u.id = s.usuario_id
      WHERE s.token_hash = ? AND s.caduca > ?
    ''', [sha256Hex(token), ahoraIso()]);
    return r.isEmpty ? null : r.first;
  }

  void cerrarSesion(String token) => db.execute('DELETE FROM sesiones WHERE token_hash = ?', [sha256Hex(token)]);

  void cerrarOtrasSesiones(int usuarioId, String tokenActual) => db.execute(
        'DELETE FROM sesiones WHERE usuario_id = ? AND token_hash <> ?',
        [usuarioId, sha256Hex(tokenActual)],
      );

  // ---------------------------------------------------------- fichajes

  List<Row> fichajes({int? usuarioId}) => db.select('''
      SELECT f.*, u.nombre AS empleado, u.email AS empleado_email, a.nombre AS autor
      FROM fichajes f
      JOIN usuarios u ON u.id = f.usuario_id
      JOIN usuarios a ON a.id = f.autor_id
      ${usuarioId == null ? '' : 'WHERE f.usuario_id = ?'}
      ORDER BY f.momento DESC, f.id DESC
    ''', usuarioId == null ? [] : [usuarioId]).toList();

  Row? fichaje(int id) {
    final r = db.select('SELECT * FROM fichajes WHERE id = ?', [id]);
    return r.isEmpty ? null : r.first;
  }

  /// Si ese fichaje ya tiene una corrección (solo se corrige una vez).
  bool yaCorregido(int id) => db.select('SELECT 1 FROM fichajes WHERE corrige_a = ? LIMIT 1', [id]).isNotEmpty;

  String? ultimoTipo(int usuarioId) {
    final r = db.select(
      'SELECT tipo FROM fichajes WHERE usuario_id = ? ORDER BY momento DESC, id DESC LIMIT 1',
      [usuarioId],
    );
    return r.isEmpty ? null : r.first['tipo'] as String;
  }

  int fichar({required int usuarioId, required String tipo, required int autorId, DateTime? momento, int? corrigeA, String? motivo}) {
    db.execute(
      'INSERT INTO fichajes (usuario_id, tipo, momento, registrado, autor_id, corrige_a, motivo) VALUES (?, ?, ?, ?, ?, ?, ?)',
      [usuarioId, tipo, (momento ?? DateTime.now()).toUtc().toIso8601String(), ahoraIso(), autorId, corrigeA, motivo],
    );
    return db.lastInsertRowId;
  }

  // ---------------------------------------------------------- mensajes

  void guardarMensaje({required int usuarioId, required String asunto, required String texto}) => db.execute(
        'INSERT INTO mensajes (usuario_id, asunto, texto, fecha) VALUES (?, ?, ?, ?)',
        [usuarioId, asunto, texto, ahoraIso()],
      );

  List<Row> mensajes() => db.select('''
      SELECT m.*, u.nombre AS nombre, u.email AS email, u.rol AS rol
      FROM mensajes m LEFT JOIN usuarios u ON u.id = m.usuario_id
      ORDER BY m.fecha DESC
    ''').toList();

  bool marcarLeido(int id) {
    db.execute('UPDATE mensajes SET leido = 1 WHERE id = ?', [id]);
    return db.updatedRows > 0;
  }

  // ----------------------------------------------------------- accesos

  void registrarAcceso({int? usuarioId, required String resultado, required int lectorId}) => db.execute(
        'INSERT INTO accesos (usuario_id, resultado, fecha, lector_id) VALUES (?, ?, ?, ?)',
        [usuarioId, resultado, ahoraIso(), lectorId],
      );
}
