import 'package:postgres/postgres.dart' as pg;
import 'package:sqlite3/sqlite3.dart';

import 'seguridad.dart';

/// Cuenta de gerencia que se crea la primera vez que arranca el servidor.
const correoAdmin = 'martinez.mendez.alv@gmail.com';
const contrasenaInicialAdmin = 'alvaro';
const nombreAdmin = 'Álvaro Martínez';

const roles = ['admin', 'trabajador', 'socio'];
const tiposFichaje = ['entrada', 'pausa', 'vuelta', 'salida'];

String ahoraIso() => DateTime.now().toUtc().toIso8601String();

/// Una fila de la base de datos: columna → valor.
typedef Fila = Map<String, Object?>;

/// Ya hay una cuenta con ese correo (choca con la restricción UNIQUE).
class CorreoRepetido implements Exception {}

/// Acceso a la base de datos. Hay dos: SQLite en el PC del gimnasio
/// ([BaseDatos.abrir]) y Postgres en la nube ([BaseDatos.conectar]). Las
/// consultas son las mismas y van siempre con parámetros (?), nunca
/// concatenando texto del usuario.
abstract class BaseDatos {
  static Future<BaseDatos> abrir(String? ruta, {String contrasenaAdmin = contrasenaInicialAdmin}) async {
    final bd = BaseDatosSqlite._(ruta == null ? sqlite3.openInMemory() : sqlite3.open(ruta));
    await bd._preparar(contrasenaAdmin);
    return bd;
  }

  /// [url] con el formato postgres://usuario:clave@host/base
  static Future<BaseDatos> conectar(String url, {String contrasenaAdmin = contrasenaInicialAdmin}) async {
    final bd = BaseDatosPostgres._(url);
    await bd._preparar(contrasenaAdmin);
    return bd;
  }

  Future<void> cerrar();

  // Las operaciones que cada base de datos hace a su manera.
  Future<List<Fila>> consulta(String sql, [List<Object?> p = const []]);
  Future<int> ejecutar(String sql, [List<Object?> p = const []]); // filas afectadas
  Future<int> insertar(String sql, [List<Object?> p = const []]); // id nuevo
  Future<void> _crearTablas();
  bool _esDuplicado(Object e);

  Future<void> _preparar(String contrasenaAdmin) async {
    await _crearTablas();
    if (await _una("SELECT 1 FROM usuarios WHERE rol = 'admin' LIMIT 1") != null) return;
    await crearUsuario(email: correoAdmin, nombre: nombreAdmin, contrasena: contrasenaAdmin, rol: 'admin');
  }

  Future<Fila?> _una(String sql, [List<Object?> p = const []]) async {
    final r = await consulta(sql, p);
    return r.isEmpty ? null : r.first;
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
    try {
      return await insertar(
        'INSERT INTO usuarios (email, nombre, hash, rol, qr_secreto, creado, creado_por) VALUES (?, ?, ?, ?, ?, ?, ?)',
        [email.trim().toLowerCase(), nombre.trim(), hash, rol, tokenAleatorio(), ahoraIso(), creadoPor],
      );
    } catch (e) {
      if (_esDuplicado(e)) throw CorreoRepetido();
      rethrow;
    }
  }

  Future<bool> existeCorreo(String email) async =>
      await _una('SELECT 1 FROM usuarios WHERE email = ? LIMIT 1', [email.trim().toLowerCase()]) != null;

  Future<Fila?> usuarioPorCorreo(String email) =>
      _una('SELECT * FROM usuarios WHERE email = ?', [email.trim().toLowerCase()]);

  Future<Fila?> usuarioPorId(int id) => _una('SELECT * FROM usuarios WHERE id = ?', [id]);

  Future<List<Fila>> usuarios() => consulta('SELECT * FROM usuarios ORDER BY rol, nombre');

  Future<void> cambiarHash(int id, String hash) => ejecutar('UPDATE usuarios SET hash = ? WHERE id = ?', [hash, id]);

  Future<void> suscribir(int id, String plan) =>
      ejecutar('UPDATE usuarios SET plan = ?, plan_desde = ? WHERE id = ?', [plan, ahoraIso(), id]);

  Future<Map<String, int>> recuento() async {
    final r = (await _una('''
      SELECT
        (SELECT COUNT(*) FROM usuarios WHERE rol = 'socio')       AS socios,
        (SELECT COUNT(*) FROM usuarios WHERE rol = 'trabajador')  AS trabajadores,
        (SELECT COUNT(*) FROM mensajes WHERE leido = 0)           AS mensajes,
        (SELECT COUNT(*) FROM fichajes)                           AS fichajes
    '''))!;
    return {for (final k in ['socios', 'trabajadores', 'mensajes', 'fichajes']) k: (r[k] as num).toInt()};
  }

  // ---------------------------------------------------------- sesiones

  static const duracionSesion = Duration(hours: 12);

  Future<String> crearSesion(int usuarioId) async {
    await ejecutar('DELETE FROM sesiones WHERE caduca < ?', [ahoraIso()]);
    final token = tokenAleatorio();
    await ejecutar(
      'INSERT INTO sesiones (token_hash, usuario_id, caduca) VALUES (?, ?, ?)',
      [sha256Hex(token), usuarioId, DateTime.now().toUtc().add(duracionSesion).toIso8601String()],
    );
    return token;
  }

  /// Solo se guarda el hash del token: si alguien copia la base de datos
  /// no puede usar las sesiones abiertas.
  Future<Fila?> usuarioDeSesion(String token) => _una('''
      SELECT u.* FROM sesiones s JOIN usuarios u ON u.id = s.usuario_id
      WHERE s.token_hash = ? AND s.caduca > ?
    ''', [sha256Hex(token), ahoraIso()]);

  Future<void> cerrarSesion(String token) => ejecutar('DELETE FROM sesiones WHERE token_hash = ?', [sha256Hex(token)]);

  Future<void> cerrarOtrasSesiones(int usuarioId, String tokenActual) => ejecutar(
        'DELETE FROM sesiones WHERE usuario_id = ? AND token_hash <> ?',
        [usuarioId, sha256Hex(tokenActual)],
      );

  // ---------------------------------------------------------- fichajes

  Future<List<Fila>> fichajes({int? usuarioId}) => consulta('''
      SELECT f.*, u.nombre AS empleado, u.email AS empleado_email, a.nombre AS autor
      FROM fichajes f
      JOIN usuarios u ON u.id = f.usuario_id
      JOIN usuarios a ON a.id = f.autor_id
      ${usuarioId == null ? '' : 'WHERE f.usuario_id = ?'}
      ORDER BY f.momento DESC, f.id DESC
    ''', usuarioId == null ? [] : [usuarioId]);

  Future<Fila?> fichaje(int id) => _una('SELECT * FROM fichajes WHERE id = ?', [id]);

  /// Si ese fichaje ya tiene una corrección (solo se corrige una vez).
  Future<bool> yaCorregido(int id) async =>
      await _una('SELECT 1 FROM fichajes WHERE corrige_a = ? LIMIT 1', [id]) != null;

  Future<String?> ultimoTipo(int usuarioId) async {
    final r = await _una(
      'SELECT tipo FROM fichajes WHERE usuario_id = ? ORDER BY momento DESC, id DESC LIMIT 1',
      [usuarioId],
    );
    return r?['tipo'] as String?;
  }

  Future<int> fichar({
    required int usuarioId,
    required String tipo,
    required int autorId,
    DateTime? momento,
    int? corrigeA,
    String? motivo,
  }) =>
      insertar(
        'INSERT INTO fichajes (usuario_id, tipo, momento, registrado, autor_id, corrige_a, motivo) VALUES (?, ?, ?, ?, ?, ?, ?)',
        [usuarioId, tipo, (momento ?? DateTime.now()).toUtc().toIso8601String(), ahoraIso(), autorId, corrigeA, motivo],
      );

  // ---------------------------------------------------------- mensajes

  Future<void> guardarMensaje({required int usuarioId, required String asunto, required String texto}) => insertar(
        'INSERT INTO mensajes (usuario_id, asunto, texto, fecha) VALUES (?, ?, ?, ?)',
        [usuarioId, asunto, texto, ahoraIso()],
      );

  Future<List<Fila>> mensajes() => consulta('''
      SELECT m.*, u.nombre AS nombre, u.email AS email, u.rol AS rol
      FROM mensajes m LEFT JOIN usuarios u ON u.id = m.usuario_id
      ORDER BY m.fecha DESC
    ''');

  Future<bool> marcarLeido(int id) async => await ejecutar('UPDATE mensajes SET leido = 1 WHERE id = ?', [id]) > 0;

  // ----------------------------------------------------------- accesos

  Future<void> registrarAcceso({int? usuarioId, required String resultado, required int lectorId}) => insertar(
        'INSERT INTO accesos (usuario_id, resultado, fecha, lector_id) VALUES (?, ?, ?, ?)',
        [usuarioId, resultado, ahoraIso(), lectorId],
      );
}

// ===================================================================== SQLite

class BaseDatosSqlite extends BaseDatos {
  BaseDatosSqlite._(this.db);

  final Database db;

  @override
  Future<void> cerrar() async => db.dispose();

  @override
  Future<List<Fila>> consulta(String sql, [List<Object?> p = const []]) async => db.select(sql, p).toList();

  @override
  Future<int> ejecutar(String sql, [List<Object?> p = const []]) async {
    db.execute(sql, p);
    return db.updatedRows;
  }

  @override
  Future<int> insertar(String sql, [List<Object?> p = const []]) async {
    db.execute(sql, p);
    return db.lastInsertRowId;
  }

  @override
  bool _esDuplicado(Object e) => e is SqliteException && e.extendedResultCode == 2067; // SQLITE_CONSTRAINT_UNIQUE

  @override
  Future<void> _crearTablas() async {
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
}

// =================================================================== Postgres

class BaseDatosPostgres extends BaseDatos {
  BaseDatosPostgres._(String url) : _pool = _abrirPool(url);

  final pg.Pool<void> _pool;

  static pg.Pool<void> _abrirPool(String url) {
    final u = Uri.parse(url);
    if (u.scheme != 'postgres' && u.scheme != 'postgresql') {
      throw ArgumentError('DATABASE_URL tiene que empezar por postgres://');
    }
    final i = u.userInfo.indexOf(':');
    final usuario = i < 0 ? u.userInfo : u.userInfo.substring(0, i);
    final clave = i < 0 ? null : u.userInfo.substring(i + 1);
    final local = u.host == 'localhost' || u.host == '127.0.0.1';
    return pg.Pool.withEndpoints(
      [
        pg.Endpoint(
          host: u.host,
          port: u.hasPort ? u.port : 5432,
          database: u.pathSegments.isEmpty ? 'postgres' : u.pathSegments.first,
          username: Uri.decodeComponent(usuario),
          password: clave == null ? null : Uri.decodeComponent(clave),
        ),
      ],
      settings: pg.PoolSettings(
        maxConnectionCount: 4,
        // Neon apaga la base de datos cuando no se usa: las conexiones viejas
        // se renuevan en vez de fallar.
        maxConnectionAge: const Duration(minutes: 4),
        connectTimeout: const Duration(seconds: 30),
        queryTimeout: const Duration(seconds: 20),
        // Fuera de este PC, siempre cifrado y comprobando el certificado.
        sslMode: local ? pg.SslMode.disable : pg.SslMode.verifyFull,
      ),
    );
  }

  static pg.Sql _sql(String sql) => pg.Sql.indexed(sql, substitution: '?');

  @override
  Future<void> cerrar() => _pool.close();

  @override
  Future<List<Fila>> consulta(String sql, [List<Object?> p = const []]) async {
    final r = await _pool.execute(_sql(sql), parameters: p);
    return [for (final fila in r) fila.toColumnMap()];
  }

  @override
  Future<int> ejecutar(String sql, [List<Object?> p = const []]) async =>
      (await _pool.execute(_sql(sql), parameters: p)).affectedRows;

  @override
  Future<int> insertar(String sql, [List<Object?> p = const []]) async {
    final r = await _pool.execute(_sql('$sql RETURNING id'), parameters: p);
    return r.first.first as int;
  }

  @override
  bool _esDuplicado(Object e) => e is pg.ServerException && e.code == '23505'; // unique_violation

  @override
  Future<void> _crearTablas() async {
    // Varias sentencias seguidas solo se admiten sin parámetros (simple query).
    for (final sql in _esquemaPostgres) {
      await _pool.execute(sql, ignoreRows: true, queryMode: pg.QueryMode.simple);
    }
  }
}

const _esquemaPostgres = [
  '''
  CREATE TABLE IF NOT EXISTS usuarios (
    id          INTEGER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    email       TEXT NOT NULL UNIQUE CHECK (email = lower(email)),
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
    id          INTEGER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    usuario_id  INTEGER NOT NULL REFERENCES usuarios(id),
    tipo        TEXT NOT NULL CHECK (tipo IN ('entrada', 'pausa', 'vuelta', 'salida')),
    momento     TEXT NOT NULL,
    registrado  TEXT NOT NULL,
    autor_id    INTEGER NOT NULL REFERENCES usuarios(id),
    corrige_a   INTEGER REFERENCES fichajes(id),
    motivo      TEXT
  );
  CREATE TABLE IF NOT EXISTS mensajes (
    id          INTEGER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    usuario_id  INTEGER REFERENCES usuarios(id),
    asunto      TEXT NOT NULL,
    texto       TEXT NOT NULL,
    fecha       TEXT NOT NULL,
    leido       INTEGER NOT NULL DEFAULT 0
  );
  CREATE TABLE IF NOT EXISTS accesos (
    id          INTEGER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    usuario_id  INTEGER REFERENCES usuarios(id),
    resultado   TEXT NOT NULL,
    fecha       TEXT NOT NULL,
    lector_id   INTEGER REFERENCES usuarios(id)
  );
  CREATE INDEX IF NOT EXISTS fichajes_usuario ON fichajes (usuario_id, momento);
  CREATE INDEX IF NOT EXISTS sesiones_usuario ON sesiones (usuario_id);
  ''',
  // Registro de jornada: nada se modifica ni se borra, ni siquiera desde
  // fuera de la app. Una corrección es un registro nuevo.
  r'''
  CREATE OR REPLACE FUNCTION fichajes_inmutables() RETURNS trigger LANGUAGE plpgsql AS $$
  BEGIN
    RAISE EXCEPTION 'Los fichajes no se pueden modificar ni borrar';
  END $$;
  ''',
  r'''
  DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'fichajes_no_se_tocan') THEN
      CREATE TRIGGER fichajes_no_se_tocan BEFORE UPDATE OR DELETE ON fichajes
        FOR EACH ROW EXECUTE FUNCTION fichajes_inmutables();
    END IF;
  END $$;
  ''',
];
