import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/store.dart';
import '../theme.dart';

/// Texto, icono y colores de cada tipo de fichaje.
Estado _estadoTipo(TipoFichaje t) => switch (t) {
      TipoFichaje.entrada => Estado(t.nombre, Icons.login_rounded, Forja.verde, Forja.verdeSuave),
      TipoFichaje.pausa => Estado(t.nombre, Icons.coffee_outlined, Forja.pajaTexto, Forja.pajaSuave),
      TipoFichaje.vuelta => Estado(t.nombre, Icons.replay_rounded, Forja.temple, Forja.templeSuave),
      TipoFichaje.salida => Estado(t.nombre, Icons.logout_rounded, Forja.gris, Forja.acero),
    };

class PantallaFichajes extends StatelessWidget {
  const PantallaFichajes({super.key, required this.store});
  final ForjaStore store;

  Fichaje? _ultimo(Empleado e) {
    for (final f in store.fichajes.reversed) {
      if (f.empleado.id == e.id) return f;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        var trabajando = 0, pausa = 0, fuera = 0;
        for (final e in store.empleados) {
          switch (store.ultimoFichaje(e)) {
            case TipoFichaje.entrada || TipoFichaje.vuelta:
              trabajando++;
            case TipoFichaje.pausa:
              pausa++;
            default:
              fuera++;
          }
        }
        final correcciones = store.fichajes.where((f) => f.correccion != null).length;
        return Padding(
          padding: const EdgeInsets.fromLTRB(Esp.xxl, Esp.xl, Esp.xxl, Esp.xl),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CabeceraPanel(
              antetitulo: 'Fichajes · registro de jornada',
              titulo: 'El equipo hoy',
              acciones: [
                OutlinedButton.icon(
                  onPressed: () => _exportar(context),
                  icon: const Icon(Icons.file_download_outlined, size: 20),
                  label: const Text('Exportar para la inspección'),
                ),
              ],
            ),
            const SizedBox(height: Esp.xl),
            Row(children: [
              Expanded(
                child: Indicador(
                  valor: '$trabajando',
                  texto: 'Trabajando ahora',
                  icono: Icons.work_outline_rounded,
                  color: Forja.verde,
                  detalle: 'de ${store.empleados.length} personas',
                ),
              ),
              const SizedBox(width: Esp.l),
              Expanded(
                child: Indicador(
                  valor: '$pausa',
                  texto: 'En pausa',
                  icono: Icons.coffee_outlined,
                  color: Forja.pajaTexto,
                  detalle: 'Descanso en curso',
                ),
              ),
              const SizedBox(width: Esp.l),
              Expanded(
                child: Indicador(
                  valor: '$fuera',
                  texto: 'Fuera de turno',
                  icono: Icons.nightlight_outlined,
                  color: Forja.gris,
                  detalle: 'Sin fichar o ya han salido',
                ),
              ),
              const SizedBox(width: Esp.l),
              Expanded(
                child: Indicador(
                  valor: '${store.fichajes.length}',
                  texto: 'Registros hoy',
                  icono: Icons.fact_check_outlined,
                  color: Forja.temple,
                  detalle: correcciones == 0 ? 'Sin correcciones' : '$correcciones con corrección',
                ),
              ),
            ]),
            const SizedBox(height: Esp.l),
            SizedBox(
              height: 172,
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (final e in store.empleados) ...[
                  Expanded(child: _empleado(e)),
                  if (e != store.empleados.last) const SizedBox(width: Esp.m),
                ],
              ]),
            ),
            const SizedBox(height: Esp.l),
            Expanded(child: _registro(context)),
          ]),
        );
      },
    );
  }

  Widget _empleado(Empleado e) {
    final f = _ultimo(e);
    final Estado estado = switch (f?.tipo) {
      null => const Estado('Sin fichar', Icons.nightlight_outlined, Forja.gris, Forja.acero),
      TipoFichaje.salida =>
        Estado('Salió a las ${hora(f!.momento)}', Icons.nightlight_outlined, Forja.gris, Forja.acero),
      TipoFichaje.pausa =>
        Estado('En pausa desde ${hora(f!.momento)}', Icons.coffee_outlined, Forja.pajaTexto, Forja.pajaSuave),
      _ => Estado('Trabajando desde ${hora(f!.momento)}', Icons.work_outline_rounded, Forja.verde, Forja.verdeSuave),
    };
    final posibles = store.fichajesPosibles(e);
    return Tarjeta(
      padding: const EdgeInsets.all(Esp.l),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Avatar(e.nombre, tam: 38, fondo: Forja.templeSuave, color: Forja.temple),
          const SizedBox(width: Esp.s),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(e.nombre, maxLines: 1, overflow: TextOverflow.ellipsis, style: Txt.cuerpoFuerte),
              Text(e.puesto,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: Txt.secundario.copyWith(fontSize: 12.5)),
            ]),
          ),
        ]),
        const SizedBox(height: Esp.m),
        AnimatedSwitcher(duration: Mov.medio, child: Insignia(estado, key: ValueKey(estado.texto))),
        const Spacer(),
        Row(children: [
          for (final t in posibles) ...[
            Expanded(
              child: Tooltip(
                message: 'Registrar ${t.nombre.toLowerCase()} de ${e.nombre}',
                child: t == TipoFichaje.salida
                    ? OutlinedButton(
                        onPressed: () => store.fichar(e, t),
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6)),
                        child: _etiquetaBoton(t),
                      )
                    : FilledButton(
                        onPressed: () => store.fichar(e, t),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          backgroundColor: t == TipoFichaje.pausa ? Forja.hierro : Forja.ascuaTexto,
                        ),
                        child: _etiquetaBoton(t),
                      ),
              ),
            ),
            if (t != posibles.last) const SizedBox(width: Esp.s),
          ],
        ]),
      ]),
    );
  }

  Widget _etiquetaBoton(TipoFichaje t) {
    final texto = t == TipoFichaje.vuelta ? 'Volver' : t.nombre;
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(_estadoTipo(t).icono, size: 17),
        const SizedBox(width: 6),
        Text(texto),
      ]),
    );
  }

  Widget _registro(BuildContext context) {
    // Más recientes arriba por hora del fichaje (una corrección se coloca en su hora real).
    final lista = store.fichajes.reversed.toList()..sort((a, b) => b.momento.compareTo(a.momento));
    return Tarjeta(
      padding: const EdgeInsets.fromLTRB(Esp.xl, 20, Esp.xl, Esp.m),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const TituloBloque('Registro de hoy',
            apoyo: 'Nada se borra: corregir crea un registro nuevo que dice quién lo cambió y por qué.'),
        const SizedBox(height: Esp.m),
        const CabeceraTabla(columnas: [
          (80, 'HORA'),
          (200, 'EMPLEADO'),
          (170, 'TIPO'),
          (null, 'OBSERVACIONES'),
          (120, ''),
        ]),
        Expanded(
          child: lista.isEmpty
              ? const Center(
                  child: EstadoVacio(
                    icono: Icons.schedule_rounded,
                    titulo: 'Nadie ha fichado todavía',
                    texto: 'Los fichajes del día aparecerán aquí.',
                  ),
                )
              : ListView.separated(
                  itemCount: lista.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (_, i) {
                    final f = lista[i];
                    final corregido = f.correccion != null;
                    return FilaTabla(
                      child: Row(children: [
                        SizedBox(width: 80, child: Text(hora(f.momento), style: Txt.hora.copyWith(fontSize: 16))),
                        SizedBox(
                          width: 200,
                          child: Row(children: [
                            Avatar(f.empleado.nombre, tam: 26, fondo: Forja.acero, color: Forja.tinta),
                            const SizedBox(width: Esp.s),
                            Expanded(
                                child: Text(f.empleado.nombre, overflow: TextOverflow.ellipsis, style: Txt.cuerpo)),
                          ]),
                        ),
                        SizedBox(
                          width: 170,
                          child: Align(alignment: Alignment.centerLeft, child: Insignia(_estadoTipo(f.tipo))),
                        ),
                        Expanded(
                          child: corregido
                              ? Row(children: [
                                  const Icon(Icons.edit_note_rounded, size: 18, color: Forja.temple),
                                  const SizedBox(width: Esp.xs),
                                  Expanded(
                                    child: Text(f.correccion!,
                                        style:
                                            Txt.secundario.copyWith(color: Forja.temple, fontWeight: FontWeight.w500)),
                                  ),
                                ])
                              : const Text('Fichado en el terminal', style: Txt.secundario),
                        ),
                        SizedBox(
                          width: 120,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: corregido
                                ? null
                                : TextButton.icon(
                                    onPressed: () => _corregir(context, f),
                                    icon: const Icon(Icons.edit_outlined, size: 16),
                                    label: const Text('Corregir'),
                                  ),
                          ),
                        ),
                      ]),
                    );
                  },
                ),
        ),
      ]),
    );
  }

  Future<void> _corregir(BuildContext context, Fichaje f) async {
    final motivo = TextEditingController(text: 'Se olvidó de fichar a su hora');
    var minutos = -10;
    String? error;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          final nueva = f.momento.add(Duration(minutes: minutos));
          return AlertDialog(
            title: const Text('Corregir fichaje'),
            content: SizedBox(
              width: 480,
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${f.tipo.nombre} de ${f.empleado.nombre}', style: Txt.secundario.copyWith(fontSize: 14)),
                const SizedBox(height: Esp.l),
                Container(
                  padding: const EdgeInsets.all(Esp.l),
                  decoration: BoxDecoration(color: Forja.acero, borderRadius: BorderRadius.circular(Rad.m)),
                  child: Row(children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('REGISTRADA', style: Txt.etiqueta),
                      Text(hora(f.momento),
                          style: Txt.cifra
                              .copyWith(fontSize: 30, color: Forja.gris, decoration: TextDecoration.lineThrough)),
                    ]),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: Esp.xl),
                      child: Icon(Icons.arrow_forward_rounded, color: Forja.gris),
                    ),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('CORRECTA', style: Txt.etiqueta),
                      Text(hora(nueva), style: Txt.cifra.copyWith(fontSize: 30, color: Forja.ascuaTexto)),
                    ]),
                    const Spacer(),
                    Text('${minutos > 0 ? '+' : ''}$minutos min', style: Txt.cuerpoFuerte),
                  ]),
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
                TextField(
                  controller: motivo,
                  onChanged: (_) {
                    if (error != null) setSt(() => error = null);
                  },
                  decoration: InputDecoration(labelText: 'Motivo de la corrección', errorText: error),
                ),
                const SizedBox(height: Esp.l),
                const Nota('El registro original se conserva. La inspección de trabajo verá los dos.',
                    icono: Icons.lock_outline_rounded),
              ]),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(Esp.xl, 0, Esp.xl, 20),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              FilledButton(
                onPressed: () {
                  if (motivo.text.trim().isEmpty) {
                    setSt(() => error = 'Indica el motivo: cada cambio tiene que quedar justificado.');
                    return;
                  }
                  store.corregir(f, nueva, motivo.text.trim());
                  Navigator.pop(ctx);
                },
                child: const Text('Guardar corrección'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _exportar(BuildContext context) async {
    final csv = store.exportarCsv();
    final filas = csv.trim().split('\n').length - 1;
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
              Container(
                height: 320,
                width: double.infinity,
                padding: const EdgeInsets.all(Esp.l),
                decoration: BoxDecoration(color: Forja.hierro, borderRadius: BorderRadius.circular(Rad.m)),
                child: SingleChildScrollView(
                  child: SelectableText(
                    csv,
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
            ]),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(Esp.xl, 0, Esp.xl, 20),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
            FilledButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: csv));
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
