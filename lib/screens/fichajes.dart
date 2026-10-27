import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/store.dart';
import '../theme.dart';

class PantallaFichajes extends StatelessWidget {
  const PantallaFichajes({super.key, required this.store});
  final ForjaStore store;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.fromLTRB(36, 30, 36, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Cabecera(
              etiqueta: 'FICHAJES · REGISTRO DE JORNADA',
              titulo: 'Adiós a la hoja de firmas',
              subtitulo: 'obligatorio por el art. 34.9 del Estatuto y guardado cuatro años',
              colorEtiqueta: Forja.morado,
              colorTextoEtiqueta: Colors.white,
              colorSubtitulo: Forja.morado,
              accion: OutlinedButton.icon(
                onPressed: () => _exportar(context),
                icon: const Icon(Icons.file_download_outlined),
                label: const Text('Exportar para la inspección'),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 178,
              child: Row(children: [
                for (final e in store.empleados) ...[
                  Expanded(child: _empleado(e)),
                  if (e != store.empleados.last) const SizedBox(width: 14),
                ],
              ]),
            ),
            const SizedBox(height: 18),
            Expanded(child: _registro(context)),
          ],
        ),
      ),
    );
  }

  Widget _empleado(Empleado e) {
    final ultimo = store.ultimoFichaje(e);
    final (String estado, Color fondo, Color color) = switch (ultimo) {
      null || TipoFichaje.salida => ('Fuera', Forja.linea, Forja.gris),
      TipoFichaje.pausa => ('En pausa', Forja.amarilloSuave, Forja.ocre),
      _ => ('Trabajando', Forja.turquesaSuave, Forja.verde),
    };
    return Tarjeta(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Forja.moradoSuave,
            child: Text(e.nombre.split(' ').map((p) => p[0]).take(2).join(),
                style: const TextStyle(color: Forja.morado, fontWeight: FontWeight.w800, fontSize: 13)),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(12)),
            child: Text(estado, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
          ),
        ]),
        const SizedBox(height: 10),
        Text(e.nombre, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        Text(e.puesto, style: const TextStyle(color: Forja.gris, fontSize: 12)),
        const Spacer(),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final t in store.fichajesPosibles(e))
            FilledButton(
              onPressed: () => store.fichar(e, t),
              style: FilledButton.styleFrom(
                backgroundColor: t == TipoFichaje.salida ? Forja.coral : Forja.marino,
                foregroundColor: t == TipoFichaje.salida ? Forja.marino : Colors.white,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: Text(t.nombre),
            ),
        ]),
      ]),
    );
  }

  Widget _registro(BuildContext context) {
    final lista = store.fichajes.reversed.toList();
    return Tarjeta(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(
            child: Text('Registro de hoy', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ),
          Pildora('${lista.length} registros', fondo: Forja.moradoSuave),
        ]),
        const SizedBox(height: 4),
        const Text('Nada se borra: una corrección crea un registro nuevo con quién y por qué.',
            style: TextStyle(color: Forja.gris)),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: Forja.moradoSuave, borderRadius: BorderRadius.circular(10)),
          child: const Row(children: [
            SizedBox(width: 80, child: Text('Hora', style: TextStyle(fontWeight: FontWeight.w700))),
            SizedBox(width: 200, child: Text('Empleado', style: TextStyle(fontWeight: FontWeight.w700))),
            SizedBox(width: 150, child: Text('Tipo', style: TextStyle(fontWeight: FontWeight.w700))),
            Expanded(child: Text('Observaciones', style: TextStyle(fontWeight: FontWeight.w700))),
            SizedBox(width: 90),
          ]),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: lista.length,
            separatorBuilder: (_, __) => const Divider(height: 1, color: Forja.linea),
            itemBuilder: (_, i) {
              final f = lista[i];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(children: [
                  SizedBox(width: 80, child: Text(hora(f.momento), style: const TextStyle(fontWeight: FontWeight.w700))),
                  SizedBox(width: 200, child: Text(f.empleado.nombre)),
                  SizedBox(width: 150, child: Text(f.tipo.nombre)),
                  Expanded(
                    child: Text(f.correccion ?? '—',
                        style: TextStyle(
                          color: f.correccion != null ? Forja.morado : Forja.gris,
                          fontSize: 12,
                        )),
                  ),
                  SizedBox(
                    width: 90,
                    child: f.correccion == null
                        ? TextButton(onPressed: () => _corregir(context, f), child: const Text('Corregir'))
                        : const SizedBox(),
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
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          backgroundColor: Forja.tarjeta,
          title: Text('Corregir ${f.tipo.nombre.toLowerCase()} de ${f.empleado.nombre}'),
          content: SizedBox(
            width: 440,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Hora registrada: ${hora(f.momento)}  →  nueva: ${hora(f.momento.add(Duration(minutes: minutos)))}'),
              Slider(
                value: minutos.toDouble(),
                min: -60,
                max: 60,
                divisions: 24,
                label: '${minutos > 0 ? '+' : ''}$minutos min',
                onChanged: (v) => setSt(() => minutos = v.round()),
              ),
              TextField(controller: motivo, decoration: const InputDecoration(labelText: 'Motivo')),
              const SizedBox(height: 14),
              const Nota('Importante:', 'el registro original no se borra. La inspección ve los dos.'),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                store.corregir(f, f.momento.add(Duration(minutes: minutos)), motivo.text.trim());
                Navigator.pop(ctx);
              },
              child: const Text('Guardar corrección'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportar(BuildContext context) async {
    final csv = store.exportarCsv();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Forja.tarjeta,
        title: const Text('Registro de jornada (CSV)'),
        content: SizedBox(
          width: 640,
          height: 360,
          child: SingleChildScrollView(
            child: SelectableText(csv, style: const TextStyle(fontFamily: 'Consolas', fontSize: 13)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: csv));
              Navigator.pop(ctx);
            },
            child: const Text('Copiar'),
          ),
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
        ],
      ),
    );
  }
}
