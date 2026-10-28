import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../servicios/sesion.dart';
import '../theme.dart';
import '../widgets/carga.dart';

/// Texto, icono y colores de cada tipo de fichaje.
Estado _estadoTipo(String t) => switch (t) {
      'entrada' => const Estado('Entrada', Icons.login_rounded, Forja.verde, Forja.verdeSuave),
      'pausa' => const Estado('Pausa', Icons.coffee_outlined, Forja.pajaTexto, Forja.pajaSuave),
      'vuelta' => const Estado('Vuelta', Icons.replay_rounded, Forja.temple, Forja.templeSuave),
      _ => const Estado('Salida', Icons.logout_rounded, Forja.gris, Forja.acero),
    };

String _dd(int n) => n.toString().padLeft(2, '0');
String _hora(DateTime d) => '${_dd(d.hour)}:${_dd(d.minute)}';

/// «14:05» si es de hoy; «12/10 14:05» si no.
String _cuando(DateTime d) {
  final h = DateTime.now();
  final hoy = d.year == h.year && d.month == h.month && d.day == h.day;
  return hoy ? _hora(d) : '${_dd(d.day)}/${_dd(d.month)} ${_hora(d)}';
}

/// Un fichaje tal y como llega del servidor.
class _Fichaje {
  _Fichaje(Map<String, dynamic> j)
      : id = j['id'] as int,
        usuarioId = j['usuarioId'] as int,
        empleado = (j['empleado'] as String?) ?? '—',
        tipo = j['tipo'] as String,
        momento = DateTime.parse(j['momento'] as String).toLocal(),
        autor = j['autor'] as String?,
        corrigeA = j['corrigeA'] as int?,
        motivo = j['motivo'] as String?;

  final int id;
  final int usuarioId;
  final String empleado;
  final String tipo;
  final DateTime momento;
  final String? autor;
  final int? corrigeA;
  final String? motivo;
}

/// Sección «Fichajes». Gerencia ve y corrige los de todos; un trabajador
/// solo ve los suyos y no puede cambiarlos (lo comprueba el servidor).
class PantallaFichajes extends StatelessWidget {
  const PantallaFichajes({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      return Cargador<Map<String, dynamic>>(
        cargar: sesion.api.fichajes,
        builder: (context, d, recargar) => _Contenido(datos: d, recargar: recargar, ancho: c.maxWidth),
      );
    });
  }
}

class _Contenido extends StatelessWidget {
  const _Contenido({required this.datos, required this.recargar, required this.ancho});
  final Map<String, dynamic> datos;
  final Future<void> Function() recargar;
  final double ancho;

  @override
  Widget build(BuildContext context) {
    final admin = datos['puedeModificar'] == true;
    final fichajes = [for (final f in datos['fichajes'] as List) _Fichaje(f as Map<String, dynamic>)]
      ..sort((a, b) => b.momento.compareTo(a.momento));
    final plantilla = (datos['plantilla'] as List).cast<Map<String, dynamic>>();
    final corregidos = {
      for (final f in fichajes)
        if (f.corrigeA != null) f.corrigeA!
    };
    final amplio = ancho >= 760;
    // La tabla necesita sitio para sus columnas; si no, cada fichaje va en dos líneas.
    final tabla = ancho >= 900;

    var trabajando = 0, pausa = 0, fuera = 0;
    for (final p in plantilla) {
      switch (p['ultimo']) {
        case 'entrada' || 'vuelta':
          trabajando++;
        case 'pausa':
          pausa++;
        default:
          fuera++;
      }
    }

    final exportar = OutlinedButton.icon(
      onPressed: () => _exportar(context),
      icon: const Icon(Icons.file_download_outlined, size: 20),
      label: const Text('Exportar para la inspección'),
    );

    return RefreshIndicator(
      onRefresh: recargar,
      child: ListView(padding: margenSeccion(ancho), children: [
        if (amplio) ...[
          CabeceraPanel(
            antetitulo: 'Fichajes · registro de jornada',
            titulo: admin ? 'El equipo' : 'Mi jornada',
            acciones: [if (admin) exportar],
          ),
          const SizedBox(height: Esp.xl),
        ],
        if (!admin) ...[
          const Nota(
            'Solo gerencia puede registrar o corregir fichajes. Si ves un error, avísala desde «Contacto».',
            titulo: 'Solo lectura.',
            icono: Icons.lock_outline_rounded,
          ),
          const SizedBox(height: Esp.l),
        ],
        if (admin) ...[
          _rejilla(minimo: 160, hijos: [
            Indicador(
              valor: '$trabajando',
              texto: 'Trabajando ahora',
              icono: Icons.work_outline_rounded,
              color: Forja.verde,
              detalle: 'de ${plantilla.length} personas',
            ),
            Indicador(
              valor: '$pausa',
              texto: 'En pausa',
              icono: Icons.coffee_outlined,
              color: Forja.pajaTexto,
              detalle: 'Descanso en curso',
            ),
            Indicador(
              valor: '$fuera',
              texto: 'Fuera de turno',
              icono: Icons.nightlight_outlined,
              color: Forja.gris,
              detalle: 'Sin fichar o ya han salido',
            ),
            Indicador(
              valor: '${fichajes.length}',
              texto: 'Registros',
              icono: Icons.fact_check_outlined,
              color: Forja.temple,
              detalle: corregidos.isEmpty ? 'Sin correcciones' : '${corregidos.length} con corrección',
            ),
          ]),
          const SizedBox(height: Esp.l),
        ],
        _rejilla(minimo: 260, hijos: [
          for (final p in plantilla)
            _Empleado(
              p: p,
              ultimo: fichajes.where((f) => f.usuarioId == p['id']).firstOrNull,
              puedeFichar: admin,
              alFichar: recargar,
            ),
        ]),
        const SizedBox(height: Esp.l),
        if (admin && !amplio) ...[
          SizedBox(width: double.infinity, child: exportar),
          const SizedBox(height: Esp.l),
        ],
        Tarjeta(
          padding: EdgeInsets.fromLTRB(amplio ? Esp.xl : Esp.l, 20, amplio ? Esp.xl : Esp.l, Esp.m),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            TituloBloque(admin ? 'Registro' : 'Mis fichajes',
                apoyo: 'Nada se borra: corregir crea un registro nuevo que dice quién lo cambió y por qué.'),
            const SizedBox(height: Esp.m),
            if (tabla)
              CabeceraTabla(columnas: [
                (110, 'HORA'),
                if (admin) (200, 'EMPLEADO'),
                (150, 'TIPO'),
                (null, 'OBSERVACIONES'),
                if (admin) (120, ''),
              ]),
            if (fichajes.isEmpty)
              const EstadoVacio(
                icono: Icons.schedule_rounded,
                titulo: 'Aún no hay fichajes',
                texto: 'Los fichajes aparecerán aquí en cuanto se registren.',
              ),
            for (final (i, f) in fichajes.indexed) ...[
              if (i > 0) const Divider(),
              _Fila(
                f: f,
                amplio: tabla,
                admin: admin,
                corregido: corregidos.contains(f.id),
                alCorregir: () => _corregir(context, f),
              ),
            ],
          ]),
        ),
      ]),
    );
  }

  /// Reparte los hijos en columnas de al menos [minimo] px; en el móvil, uno por fila.
  Widget _rejilla({required double minimo, required List<Widget> hijos}) {
    return LayoutBuilder(builder: (context, c) {
      var columnas = (c.maxWidth / minimo).floor().clamp(1, 4);
      // Cuatro tarjetas van en 4, 2 o 1 columnas: nunca una sola en la última fila.
      if (hijos.length == 4 && columnas == 3) columnas = 2;
      final w = (c.maxWidth - Esp.l * (columnas - 1)) / columnas;
      return Wrap(spacing: Esp.l, runSpacing: Esp.l, children: [
        for (final h in hijos) SizedBox(width: w, child: h),
      ]);
    });
  }

  Future<void> _corregir(BuildContext context, _Fichaje f) async {
    final motivo = TextEditingController(text: 'Se olvidó de fichar a su hora');
    var minutos = -10;
    final hecho = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          final nueva = f.momento.add(Duration(minutes: minutos));
          final futura = nueva.isAfter(DateTime.now());
          return AlertDialog(
            title: const Text('Corregir fichaje'),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${_estadoTipo(f.tipo).texto} de ${f.empleado}', style: Txt.secundario.copyWith(fontSize: 14)),
                  const SizedBox(height: Esp.l),
                  Container(
                    padding: const EdgeInsets.all(Esp.l),
                    decoration: BoxDecoration(color: Forja.acero, borderRadius: BorderRadius.circular(Rad.m)),
                    child: Wrap(
                      spacing: Esp.l,
                      runSpacing: Esp.s,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('REGISTRADA', style: Txt.etiqueta),
                          Text(_hora(f.momento),
                              style: Txt.cifra
                                  .copyWith(fontSize: 30, color: Forja.gris, decoration: TextDecoration.lineThrough)),
                        ]),
                        const Icon(Icons.arrow_forward_rounded, color: Forja.gris),
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('CORRECTA', style: Txt.etiqueta),
                          Text(_hora(nueva), style: Txt.cifra.copyWith(fontSize: 30, color: Forja.ascuaTexto)),
                        ]),
                        Text('${minutos > 0 ? '+' : ''}$minutos min', style: Txt.cuerpoFuerte),
                      ],
                    ),
                  ),
                  Slider(
                    value: minutos.toDouble(),
                    min: -60,
                    max: 60,
                    divisions: 24,
                    label: '${minutos > 0 ? '+' : ''}$minutos min',
                    semanticFormatterCallback: (v) => '${v.round()} minutos',
                    onChanged: (v) => setSt(() => minutos = v.round()),
                  ),
                  if (futura)
                    const Padding(
                      padding: EdgeInsets.only(bottom: Esp.s),
                      child: Text('No se puede fichar en el futuro.', style: TextStyle(color: Forja.rojo)),
                    ),
                  TextField(
                    controller: motivo,
                    maxLength: 200,
                    decoration: const InputDecoration(labelText: 'Motivo de la corrección'),
                  ),
                  const SizedBox(height: Esp.s),
                  const Nota('El registro original se conserva. La inspección de trabajo verá los dos.',
                      icono: Icons.lock_outline_rounded),
                ]),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              FilledButton(
                onPressed: futura
                    ? null
                    : () async {
                        final ok = await intentar(ctx, () => sesion.api.corregir(f.id, nueva, motivo.text.trim()),
                            exito: 'Corrección guardada.');
                        if (ok && ctx.mounted) Navigator.pop(ctx, true);
                      },
                child: const Text('Guardar corrección'),
              ),
            ],
          );
        },
      ),
    );
    motivo.dispose();
    if (hecho == true) await recargar();
  }

  Future<void> _exportar(BuildContext context) async {
    String? csv;
    if (!await intentar(context, () async => csv = await sesion.api.csv()) || !context.mounted) return;
    final texto = csv!;
    final filas = texto.trim().split('\n').length - 1;
    var copiado = false;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Registro de jornada'),
          content: SizedBox(
            width: 720,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$filas registros en CSV, listos para entregar a la inspección de trabajo.',
                  style: Txt.secundario.copyWith(fontSize: 14)),
              const SizedBox(height: Esp.l),
              Flexible(
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 320),
                  width: double.infinity,
                  padding: const EdgeInsets.all(Esp.l),
                  decoration: BoxDecoration(color: Forja.hierro, borderRadius: BorderRadius.circular(Rad.m)),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      texto,
                      style: const TextStyle(
                        fontFamily: 'Consolas',
                        fontFamilyFallback: ['Courier New', 'monospace'],
                        fontSize: 13,
                        height: 1.5,
                        color: Forja.grisClaro,
                      ),
                    ),
                  ),
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
            FilledButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: texto));
                setSt(() => copiado = true);
              },
              icon: Icon(copiado ? Icons.check_rounded : Icons.content_copy_rounded, size: 18),
              label: Text(copiado ? 'Copiado' : 'Copiar al portapapeles'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Empleado extends StatefulWidget {
  const _Empleado({required this.p, required this.ultimo, required this.puedeFichar, required this.alFichar});
  final Map<String, dynamic> p;
  final _Fichaje? ultimo;
  final bool puedeFichar;
  final Future<void> Function() alFichar;

  @override
  State<_Empleado> createState() => _EmpleadoState();
}

class _EmpleadoState extends State<_Empleado> {
  bool enviando = false;

  Future<void> _fichar(String tipo) async {
    setState(() => enviando = true);
    final ok = await intentar(context, () => sesion.api.fichar(widget.p['id'] as int, tipo));
    if (ok) await widget.alFichar();
    if (mounted) setState(() => enviando = false);
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.ultimo;
    final nombre = widget.p['nombre'] as String;
    final Estado estado = switch (f?.tipo) {
      null => const Estado('Sin fichar', Icons.nightlight_outlined, Forja.gris, Forja.acero),
      'salida' => Estado('Salió a las ${_cuando(f!.momento)}', Icons.nightlight_outlined, Forja.gris, Forja.acero),
      'pausa' =>
        Estado('En pausa desde ${_cuando(f!.momento)}', Icons.coffee_outlined, Forja.pajaTexto, Forja.pajaSuave),
      _ => Estado('Trabajando desde ${_cuando(f!.momento)}', Icons.work_outline_rounded, Forja.verde, Forja.verdeSuave),
    };
    final posibles = (widget.p['posibles'] as List).cast<String>();
    return Tarjeta(
      padding: const EdgeInsets.all(Esp.l),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Avatar(nombre, tam: 38, fondo: Forja.templeSuave, color: Forja.temple),
          const SizedBox(width: Esp.s),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(nombre, maxLines: 1, overflow: TextOverflow.ellipsis, style: Txt.cuerpoFuerte),
              Text(widget.p['rol'] == 'admin' ? 'Gerencia' : 'Trabajador',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: Txt.secundario.copyWith(fontSize: 12.5)),
            ]),
          ),
        ]),
        const SizedBox(height: Esp.m),
        AnimatedSwitcher(duration: Mov.medio, child: Insignia(estado, key: ValueKey(estado.texto))),
        if (widget.puedeFichar) ...[
          const SizedBox(height: Esp.m),
          Row(children: [
            for (final t in posibles) ...[
              Expanded(
                child: Tooltip(
                  message: 'Registrar ${_estadoTipo(t).texto.toLowerCase()} de $nombre',
                  child: t == 'salida'
                      ? OutlinedButton(
                          onPressed: enviando ? null : () => _fichar(t),
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6)),
                          child: _etiqueta(t),
                        )
                      : FilledButton(
                          onPressed: enviando ? null : () => _fichar(t),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            backgroundColor: t == 'pausa' ? Forja.hierro : Forja.ascuaTexto,
                          ),
                          child: _etiqueta(t),
                        ),
                ),
              ),
              if (t != posibles.last) const SizedBox(width: Esp.s),
            ],
          ]),
        ],
      ]),
    );
  }

  Widget _etiqueta(String t) => FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(_estadoTipo(t).icono, size: 17),
          const SizedBox(width: 6),
          Text(t == 'vuelta' ? 'Volver' : _estadoTipo(t).texto),
        ]),
      );
}

class _Fila extends StatelessWidget {
  const _Fila({
    required this.f,
    required this.amplio,
    required this.admin,
    required this.corregido,
    required this.alCorregir,
  });
  final _Fichaje f;
  final bool amplio;
  final bool admin;
  final bool corregido;
  final VoidCallback alCorregir;

  Widget _observaciones() {
    if (f.corrigeA != null) {
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.edit_note_rounded, size: 18, color: Forja.temple),
        const SizedBox(width: Esp.xs),
        Expanded(
          child: Text('Corrige el registro ${f.corrigeA}: ${f.motivo ?? ''} (${f.autor ?? 'gerencia'})',
              style: Txt.secundario.copyWith(color: Forja.temple, fontWeight: FontWeight.w500)),
        ),
      ]);
    }
    if (corregido) {
      return Text('Corregido más tarde', style: Txt.secundario.copyWith(decoration: TextDecoration.lineThrough));
    }
    return Text(f.autor == null ? 'Fichado en el terminal' : 'Registrado por ${f.autor}', style: Txt.secundario);
  }

  @override
  Widget build(BuildContext context) {
    final puedeCorregir = admin && f.corrigeA == null && !corregido;
    final boton = TextButton.icon(
      onPressed: alCorregir,
      icon: const Icon(Icons.edit_outlined, size: 16),
      label: const Text('Corregir'),
    );
    if (!amplio) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: Esp.xs),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(_cuando(f.momento), style: Txt.hora.copyWith(fontSize: 16)),
            const SizedBox(width: Esp.s),
            Flexible(child: Insignia(_estadoTipo(f.tipo))),
            const Spacer(),
            if (puedeCorregir) boton,
          ]),
          if (admin) Text(f.empleado, style: Txt.cuerpoFuerte),
          const SizedBox(height: 2),
          _observaciones(),
        ]),
      );
    }
    return FilaTabla(
      child: Row(children: [
        SizedBox(width: 110, child: Text(_cuando(f.momento), style: Txt.hora.copyWith(fontSize: 16))),
        if (admin)
          SizedBox(
            width: 200,
            child: Row(children: [
              Avatar(f.empleado, tam: 26, fondo: Forja.acero, color: Forja.tinta),
              const SizedBox(width: Esp.s),
              Expanded(child: Text(f.empleado, overflow: TextOverflow.ellipsis, style: Txt.cuerpo)),
            ]),
          ),
        SizedBox(width: 150, child: Align(alignment: Alignment.centerLeft, child: Insignia(_estadoTipo(f.tipo)))),
        Expanded(child: _observaciones()),
        if (admin)
          SizedBox(
            width: 120,
            child: Align(alignment: Alignment.centerRight, child: puedeCorregir ? boton : null),
          ),
      ]),
    );
  }
}
