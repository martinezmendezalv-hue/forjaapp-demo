import 'dart:async';

import 'package:flutter/foundation.dart';

/// Todo lo que muestra la demo vive en memoria: no hay servidor ni base de datos.
/// En el proyecto real esto lo hace la API REST (Spring Boot + PostgreSQL).

enum Tarifa { sala, completa, bono }

extension TarifaTexto on Tarifa {
  String get nombre => switch (this) {
        Tarifa.sala => 'Sala libre',
        Tarifa.completa => 'Completa',
        Tarifa.bono => 'Bono 10 clases',
      };
}

class Socio {
  Socio({
    required this.id,
    required this.nombre,
    required this.tarifa,
    required this.diasSinVenir,
    this.cuotaAlDia = true,
    this.ausenciasMes = 0,
  });

  final int id;
  final String nombre;
  final Tarifa tarifa;
  int diasSinVenir;
  bool cuotaAlDia;
  int ausenciasMes;

  /// RF-06: tres ausencias sin avisar en un mes bloquean las reservas 7 días.
  bool get bloqueado => ausenciasMes >= 3;

  String get iniciales {
    final partes = nombre.split(' ');
    return partes.take(2).map((p) => p[0]).join();
  }
}

class Sesion {
  Sesion({
    required this.id,
    required this.actividad,
    required this.inicio,
    required this.minutos,
    required this.sala,
    required this.instructor,
    required this.aforo,
  });

  final int id;
  final String actividad;
  final DateTime inicio;
  final int minutos;
  final String sala;
  final String instructor;
  final int aforo;
  final List<int> reservas = [];
  final List<int> espera = [];

  int get libres => aforo - reservas.length;
  bool get llena => libres <= 0;
  double get ocupacion => reservas.length / aforo;
}

enum ResultadoAcceso { concedido, cuotaPendiente, qrCaducado, manual }

class Acceso {
  Acceso(this.socio, this.momento, this.resultado);
  final Socio socio;
  final DateTime momento;
  final ResultadoAcceso resultado;

  bool get dentro => resultado == ResultadoAcceso.concedido || resultado == ResultadoAcceso.manual;
}

enum TipoFichaje { entrada, pausa, vuelta, salida }

extension TipoFichajeTexto on TipoFichaje {
  String get nombre => switch (this) {
        TipoFichaje.entrada => 'Entrada',
        TipoFichaje.pausa => 'Pausa',
        TipoFichaje.vuelta => 'Vuelta de pausa',
        TipoFichaje.salida => 'Salida',
      };
}

class Empleado {
  Empleado(this.id, this.nombre, this.puesto);
  final int id;
  final String nombre;
  final String puesto;
}

class Fichaje {
  Fichaje(this.empleado, this.momento, this.tipo, {this.correccion});
  final Empleado empleado;
  final DateTime momento;
  final TipoFichaje tipo;

  /// Si alguien corrige un fichaje, queda rastro de quién y por qué.
  final String? correccion;
}

class Aviso {
  Aviso(this.socioId, this.texto, this.momento);
  final int socioId;
  final String texto;
  final DateTime momento;
}

class ForjaStore extends ChangeNotifier {
  ForjaStore() {
    _cargarDatos();
    _reloj = Timer.periodic(const Duration(seconds: 1), (_) => notifyListeners());
  }

  late final Timer _reloj;
  final List<Socio> socios = [];
  final List<Sesion> sesiones = [];
  final List<Acceso> accesos = [];
  final List<Empleado> empleados = [];
  final List<Fichaje> fichajes = [];
  final List<Aviso> avisos = [];

  /// Mensajes para enseñar como "notificación push" en la pantalla.
  final ValueNotifier<String?> ultimoMensaje = ValueNotifier(null);

  @override
  void dispose() {
    _reloj.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------- datos

  void _cargarDatos() {
    final nombres = [
      ('Lucía Gómez', Tarifa.completa, 1),
      ('Marcos Herrero', Tarifa.completa, 0),
      ('Pablo Ruiz', Tarifa.completa, 3),
      ('Elena Sanz', Tarifa.bono, 2),
      ('Javier Moreno', Tarifa.sala, 25),
      ('Carmen López', Tarifa.completa, 0),
      ('Raúl Fernández', Tarifa.sala, 4),
      ('Nuria Castillo', Tarifa.completa, 32),
      ('Andrés Pérez', Tarifa.bono, 1),
      ('Sara Domínguez', Tarifa.completa, 6),
      ('Iván Torres', Tarifa.sala, 22),
      ('Marta Navarro', Tarifa.completa, 0),
      ('Óscar Gil', Tarifa.completa, 2),
      ('Laura Vidal', Tarifa.bono, 9),
    ];
    for (var i = 0; i < nombres.length; i++) {
      final (n, t, d) = nombres[i];
      socios.add(Socio(id: i + 1, nombre: n, tarifa: t, diasSinVenir: d));
    }
    socio(3).ausenciasMes = 3; // Pablo: bloqueado por no venir
    socio(7).cuotaAlDia = false; // Raúl: recibo devuelto

    final hoy = DateTime.now();
    DateTime a(int h, int m) => DateTime(hoy.year, hoy.month, hoy.day, h, m);
    sesiones.addAll([
      Sesion(id: 1, actividad: 'Ciclo indoor', inicio: a(7, 30), minutos: 45, sala: 'Sala ciclo', instructor: 'Dani', aforo: 18),
      Sesion(id: 2, actividad: 'Pilates', inicio: a(10, 0), minutos: 55, sala: 'Sala dirigidas', instructor: 'Irene', aforo: 22),
      Sesion(id: 3, actividad: 'Body pump', inicio: a(18, 0), minutos: 55, sala: 'Sala dirigidas', instructor: 'Dani', aforo: 22),
      Sesion(id: 4, actividad: 'Ciclo indoor', inicio: a(19, 0), minutos: 45, sala: 'Sala ciclo', instructor: 'Irene', aforo: 18),
      Sesion(id: 5, actividad: 'HIIT', inicio: a(20, 0), minutos: 45, sala: 'Sala dirigidas', instructor: 'Dani', aforo: 22),
      Sesion(id: 6, actividad: 'Yoga', inicio: a(21, 0), minutos: 60, sala: 'Sala dirigidas', instructor: 'Irene', aforo: 22),
    ]);
    // Ocupación de ejemplo. Los ids > 14 son socios que no salen en la lista.
    void llenar(int sesionId, int cuantos, {List<int> incluir = const []}) {
      final s = sesion(sesionId);
      s.reservas.addAll(incluir);
      var extra = 100;
      while (s.reservas.length < cuantos) {
        s.reservas.add(extra++);
      }
    }

    llenar(1, 11);
    llenar(2, 14, incluir: [4]);
    llenar(3, 17, incluir: [6, 13]);
    llenar(4, 18, incluir: [2, 12]); // llena: Marcos tiene plaza
    sesion(4).espera.addAll([1, 10]); // Lucía es la primera en la lista
    llenar(5, 22, incluir: [9]);
    sesion(5).espera.add(14);
    llenar(6, 9);

    empleados.addAll([
      Empleado(1, 'Ana Martín', 'Recepción (mañana)'),
      Empleado(2, 'Rubén Calvo', 'Recepción (tarde)'),
      Empleado(3, 'Dani Ortega', 'Instructor'),
      Empleado(4, 'Irene Soto', 'Instructora'),
      Empleado(5, 'Hugo Prieto', 'Monitor de sala'),
    ]);
    fichajes.addAll([
      Fichaje(empleados[0], a(6, 52), TipoFichaje.entrada),
      Fichaje(empleados[4], a(7, 1), TipoFichaje.entrada),
      Fichaje(empleados[2], a(7, 10), TipoFichaje.entrada),
      Fichaje(empleados[0], a(10, 30), TipoFichaje.pausa),
      Fichaje(empleados[0], a(10, 50), TipoFichaje.vuelta),
    ]);

    final semilla = [1, 2, 5, 9, 12, 6, 13];
    for (var i = 0; i < semilla.length; i++) {
      accesos.add(Acceso(socio(semilla[i]), a(7 + i, 5 + i * 7), ResultadoAcceso.concedido));
    }
  }

  Socio socio(int id) => socios.firstWhere((s) => s.id == id);
  Sesion sesion(int id) => sesiones.firstWhere((s) => s.id == id);

  // ------------------------------------------------------------- reservas

  String? reservar(int socioId, int sesionId) {
    final s = sesion(sesionId);
    final so = socio(socioId);
    if (so.bloqueado) {
      return 'Reservas bloqueadas 7 días: 3 ausencias sin avisar este mes.';
    }
    if (so.tarifa == Tarifa.sala) {
      return 'La tarifa Sala libre no incluye clases dirigidas.';
    }
    if (s.reservas.contains(socioId) || s.espera.contains(socioId)) return null;
    if (s.llena) {
      s.espera.add(socioId);
      _mensaje('Clase completa: estás en la lista de espera (puesto ${s.espera.length}).');
    } else {
      s.reservas.add(socioId);
      _mensaje('Reserva confirmada: ${s.actividad} a las ${_h(s.inicio)}.');
    }
    notifyListeners();
    return null;
  }

  /// RF-04: si alguien cancela, la plaza pasa al primero de la lista y se le avisa.
  void cancelar(int socioId, int sesionId) {
    final s = sesion(sesionId);
    if (s.espera.remove(socioId)) {
      _mensaje('Has salido de la lista de espera.');
      notifyListeners();
      return;
    }
    if (!s.reservas.remove(socioId)) return;
    if (s.espera.isNotEmpty) {
      final siguiente = s.espera.removeAt(0);
      s.reservas.add(siguiente);
      final texto = '¡Tienes plaza! ${s.actividad} a las ${_h(s.inicio)}. Alguien ha cancelado.';
      avisos.insert(0, Aviso(siguiente, texto, DateTime.now()));
      _mensaje('Plaza liberada: ${socio(siguiente).nombre} pasa de la lista de espera a la clase y recibe un aviso.');
    } else {
      _mensaje('Reserva cancelada.');
    }
    notifyListeners();
  }

  // ----------------------------------------------------------------- QR

  /// RF-07: el código cambia cada 30 segundos.
  int ventanaActual() => DateTime.now().millisecondsSinceEpoch ~/ 30000;

  int segundosRestantesQr() => 30 - (DateTime.now().second % 30);

  String tokenQr(int socioId, [int? ventana]) {
    final v = ventana ?? ventanaActual();
    final control = ((socioId * 7919) ^ (v * 104729)) % 99991;
    return 'FORJA-$socioId-$v-$control';
  }

  /// Lo que haría el servidor al recibir el QR leído en la tablet de entrada.
  Acceso validarQr(String token) {
    final partes = token.split('-');
    final id = int.parse(partes[1]);
    final v = int.parse(partes[2]);
    final so = socio(id);
    ResultadoAcceso r;
    if (v != ventanaActual() || token != tokenQr(id, v)) {
      r = ResultadoAcceso.qrCaducado;
    } else if (!so.cuotaAlDia) {
      r = ResultadoAcceso.cuotaPendiente;
    } else {
      r = ResultadoAcceso.concedido;
      so.diasSinVenir = 0;
    }
    final acc = Acceso(so, DateTime.now(), r);
    accesos.insert(0, acc);
    notifyListeners();
    return acc;
  }

  Acceso entradaManual(int socioId) {
    final so = socio(socioId);
    so.diasSinVenir = 0;
    final acc = Acceso(so, DateTime.now(), ResultadoAcceso.manual);
    accesos.insert(0, acc);
    notifyListeners();
    return acc;
  }

  // ------------------------------------------------------------ fichajes

  TipoFichaje? ultimoFichaje(Empleado e) {
    for (final f in fichajes.reversed) {
      if (f.empleado.id == e.id) return f.tipo;
    }
    return null;
  }

  List<TipoFichaje> fichajesPosibles(Empleado e) => switch (ultimoFichaje(e)) {
        null || TipoFichaje.salida => [TipoFichaje.entrada],
        TipoFichaje.entrada || TipoFichaje.vuelta => [TipoFichaje.pausa, TipoFichaje.salida],
        TipoFichaje.pausa => [TipoFichaje.vuelta],
      };

  void fichar(Empleado e, TipoFichaje tipo) {
    fichajes.add(Fichaje(e, DateTime.now(), tipo));
    _mensaje('${e.nombre}: ${tipo.nombre.toLowerCase()} registrada a las ${_h(DateTime.now())}.');
    notifyListeners();
  }

  /// Corregir no borra nada: se añade un registro nuevo que dice quién y por qué.
  void corregir(Fichaje original, DateTime nuevaHora, String motivo) {
    fichajes.add(Fichaje(
      original.empleado,
      nuevaHora,
      original.tipo,
      correccion: 'Corrige la ${original.tipo.nombre.toLowerCase()} de las ${_h(original.momento)} · gerencia · $motivo',
    ));
    _mensaje('Corrección guardada. El registro original se conserva.');
    notifyListeners();
  }

  String exportarCsv() {
    final b = StringBuffer('empleado;puesto;tipo;fecha_hora;correccion\n');
    for (final f in fichajes) {
      final m = f.momento;
      b.writeln('${f.empleado.nombre};${f.empleado.puesto};${f.tipo.nombre};'
          '${m.year}-${_2(m.month)}-${_2(m.day)} ${_2(m.hour)}:${_2(m.minute)};${f.correccion ?? ''}');
    }
    return b.toString();
  }

  // -------------------------------------------------------------- panel

  Socio altaSocio(String nombre, Tarifa tarifa) {
    final s = Socio(id: socios.length + 1, nombre: nombre, tarifa: tarifa, diasSinVenir: 0);
    socios.add(s);
    _mensaje('Alta de $nombre. Ya puede descargar la app y reservar.');
    notifyListeners();
    return s;
  }

  List<Socio> get inactivos => socios.where((s) => s.diasSinVenir >= 21).toList();

  int get entradasHoy => accesos.where((a) => a.dentro).length;

  int get enEspera => sesiones.fold(0, (t, s) => t + s.espera.length);

  double get ocupacionMedia =>
      sesiones.fold<double>(0, (t, s) => t + s.ocupacion) / sesiones.length;

  void avisarInactivo(Socio s) {
    avisos.insert(0, Aviso(s.id, 'Te echamos de menos. Esta semana tienes una clase de prueba gratis.', DateTime.now()));
    _mensaje('Aviso enviado a ${s.nombre}.');
    notifyListeners();
  }

  // --------------------------------------------------------------- util

  void _mensaje(String m) {
    ultimoMensaje.value = null;
    ultimoMensaje.value = m;
  }

  static String _2(int n) => n.toString().padLeft(2, '0');
  static String _h(DateTime t) => '${_2(t.hour)}:${_2(t.minute)}';
}
