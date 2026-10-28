import 'package:flutter/material.dart';

import '../servicios/sesion.dart';
import '../theme.dart';
import '../widgets/carga.dart';
import 'cuenta.dart' show CampoContrasena;

String _fecha(String? iso) {
  final d = DateTime.tryParse(iso ?? '')?.toLocal();
  if (d == null) return '';
  String dd(int n) => n.toString().padLeft(2, '0');
  return '${dd(d.day)}/${dd(d.month)}/${d.year} ${dd(d.hour)}:${dd(d.minute)}';
}

Estado _estadoRol(String rol) => switch (rol) {
      'admin' => const Estado('Gerencia', Icons.admin_panel_settings_outlined, Forja.ascuaTexto, Forja.ascuaSuave),
      'trabajador' => const Estado('Trabajador', Icons.badge_outlined, Forja.temple, Forja.templeSuave),
      _ => const Estado('Socio', Icons.person_outline_rounded, Forja.verde, Forja.verdeSuave),
    };

// ------------------------------------------------------------------ usuarios

/// Sección «Usuarios» (solo gerencia): cuentas y alta de trabajadores.
class PantallaUsuarios extends StatelessWidget {
  const PantallaUsuarios({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final ancho = c.maxWidth >= 760;
      return Cargador(
        cargar: sesion.api.usuarios,
        builder: (context, d, recargar) {
          final crear = FilledButton.icon(
            onPressed: () async {
              if (await _nuevaCuenta(context) == true) recargar();
            },
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
            label: const Text('Abrir cuenta'),
          );
          return RefreshIndicator(
            onRefresh: recargar,
            child: ListView(padding: margenSeccion(c.maxWidth), children: [
              if (ancho) ...[
                CabeceraPanel(antetitulo: 'Gerencia', titulo: 'Usuarios', acciones: [crear]),
                const SizedBox(height: Esp.xl),
              ] else ...[
                SizedBox(width: double.infinity, child: crear),
                const SizedBox(height: Esp.l),
              ],
              Wrap(spacing: Esp.m, runSpacing: Esp.m, children: [
                _cifra('Socios', d.recuento['socios'], Icons.groups_2_outlined),
                _cifra('Trabajadores', d.recuento['trabajadores'], Icons.badge_outlined),
              ]),
              const SizedBox(height: Esp.l),
              Tarjeta(
                padding: const EdgeInsets.symmetric(vertical: Esp.s),
                child: Column(children: [
                  for (final (i, u) in d.usuarios.indexed) ...[
                    if (i > 0) const Divider(height: 1),
                    ListTile(
                      leading: Avatar(u.nombre),
                      title: Text(u.nombre, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        [u.email, if (u.plan != null) 'Plan ${u.plan}'].join(' · '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Insignia(_estadoRol(u.rol)),
                    ),
                  ],
                ]),
              ),
            ]),
          );
        },
      );
    });
  }

  Widget _cifra(String texto, Object? n, IconData icono) => SizedBox(
        width: 200,
        child: Tarjeta(
          padding: const EdgeInsets.all(Esp.l),
          child: Row(children: [
            Icon(icono, color: Forja.ascuaTexto),
            const SizedBox(width: Esp.m),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${n ?? 0}', style: Txt.cifra.copyWith(fontSize: 28)),
              Text(texto, style: Txt.secundario),
            ]),
          ]),
        ),
      );
}

Future<bool?> _nuevaCuenta(BuildContext context) =>
    showDialog<bool>(context: context, builder: (_) => const _NuevaCuenta());

class _NuevaCuenta extends StatefulWidget {
  const _NuevaCuenta();

  @override
  State<_NuevaCuenta> createState() => _NuevaCuentaState();
}

class _NuevaCuentaState extends State<_NuevaCuenta> {
  final nombre = TextEditingController();
  final email = TextEditingController();
  final pass = TextEditingController();
  final pass2 = TextEditingController();
  String rol = 'trabajador';
  bool enviando = false;

  @override
  void dispose() {
    for (final c in [nombre, email, pass, pass2]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _crear() async {
    if (enviando) return;
    setState(() => enviando = true);
    final ok = await intentar(
      context,
      () => sesion.api.crearCuenta(
        nombre: nombre.text.trim(),
        email: email.text.trim(),
        password: pass.text,
        password2: pass2.text,
        rol: rol,
      ),
      exito: 'Cuenta creada para ${nombre.text.trim()}.',
    );
    if (!mounted) return;
    setState(() => enviando = false);
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Abrir una cuenta'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'trabajador', label: Text('Trabajador'), icon: Icon(Icons.badge_outlined)),
                ButtonSegment(value: 'socio', label: Text('Socio'), icon: Icon(Icons.person_outline_rounded)),
              ],
              selected: {rol},
              onSelectionChanged: (s) => setState(() => rol = s.first),
            ),
            const SizedBox(height: Esp.l),
            TextField(
              controller: nombre,
              textInputAction: TextInputAction.next,
              decoration:
                  const InputDecoration(labelText: 'Nombre y apellidos', prefixIcon: Icon(Icons.person_outline)),
            ),
            const SizedBox(height: Esp.m),
            TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Correo', prefixIcon: Icon(Icons.alternate_email_rounded)),
            ),
            const SizedBox(height: Esp.m),
            CampoContrasena(
              controller: pass,
              etiqueta: 'Contraseña inicial',
              ayuda: 'Mínimo 8 caracteres, con letras y números.',
            ),
            const SizedBox(height: Esp.m),
            CampoContrasena(controller: pass2, etiqueta: 'Repite la contraseña', alEnviar: _crear),
            const SizedBox(height: Esp.m),
            Nota(rol == 'trabajador'
                ? 'Un trabajador ve la recepción, el punto de acceso y su propio fichaje, pero no puede modificarlo.'
                : 'Un socio ve su app, los planes y el contacto con gerencia.'),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: enviando ? null : () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: enviando ? null : _crear, child: const Text('Crear cuenta')),
      ],
    );
  }
}

// ------------------------------------------------------------------ mensajes

/// Sección «Mensajes» (solo gerencia): lo que llega desde «Contacto».
class PantallaMensajes extends StatelessWidget {
  const PantallaMensajes({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      return Cargador<List<Map<String, dynamic>>>(
        cargar: sesion.api.mensajes,
        builder: (context, mensajes, recargar) {
          final sinLeer = mensajes.where((m) => m['leido'] != true).length;
          return RefreshIndicator(
            onRefresh: recargar,
            child: ListView(padding: margenSeccion(c.maxWidth), children: [
              if (c.maxWidth >= 760) ...[
                CabeceraPanel(antetitulo: 'Gerencia', titulo: 'Mensajes', acciones: [
                  OutlinedButton.icon(
                    onPressed: recargar,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Actualizar'),
                  ),
                ]),
                const SizedBox(height: Esp.xl),
              ],
              Text(sinLeer == 0 ? 'Todo leído' : '$sinLeer sin leer', style: Txt.etiqueta),
              const SizedBox(height: Esp.m),
              if (mensajes.isEmpty)
                const Tarjeta(
                  child: EstadoVacio(
                    icono: Icons.inbox_outlined,
                    titulo: 'Bandeja vacía',
                    texto: 'Aquí llegan los mensajes que mandan socios y trabajadores desde «Contacto».',
                  ),
                ),
              for (final m in mensajes) ...[
                _Mensaje(m: m, alLeer: recargar),
                const SizedBox(height: Esp.m),
              ],
            ]),
          );
        },
      );
    });
  }
}

class _Mensaje extends StatelessWidget {
  const _Mensaje({required this.m, required this.alLeer});
  final Map<String, dynamic> m;
  final Future<void> Function() alLeer;

  @override
  Widget build(BuildContext context) {
    final leido = m['leido'] == true;
    final nombre = (m['nombre'] as String?) ?? 'Cuenta borrada';
    return Tarjeta(
      borde: leido ? Forja.linea : Forja.ascua,
      padding: const EdgeInsets.all(Esp.l),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Avatar(nombre, tam: 36),
          const SizedBox(width: Esp.m),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(m['asunto'] as String? ?? '', style: Txt.cuerpoFuerte),
              Text('$nombre · ${m['email'] ?? ''}',
                  style: Txt.secundario, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(_fecha(m['fecha'] as String?), style: Txt.secundario.copyWith(fontSize: 12)),
            ]),
          ),
          if (m['rol'] is String) Insignia(_estadoRol(m['rol'] as String)),
        ]),
        const SizedBox(height: Esp.m),
        SelectableText(m['texto'] as String? ?? '', style: Txt.cuerpo),
        if (!leido) ...[
          const SizedBox(height: Esp.m),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () async {
                if (await intentar(context, () => sesion.api.marcarLeido(m['id'] as int))) alLeer();
              },
              icon: const Icon(Icons.done_all_rounded, size: 18),
              label: const Text('Marcar como leído'),
            ),
          ),
        ],
      ]),
    );
  }
}
