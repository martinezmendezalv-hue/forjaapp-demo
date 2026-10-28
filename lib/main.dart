import 'package:flutter/material.dart';

import 'data/store.dart';
import 'screens/acceso.dart';
import 'screens/contacto.dart';
import 'screens/cuenta.dart';
import 'screens/fichajes.dart';
import 'screens/gerencia.dart';
import 'screens/pase.dart';
import 'screens/planes.dart';
import 'screens/recepcion.dart';
import 'servicios/api.dart';
import 'servicios/sesion.dart' show sesion;
import 'theme.dart';
import 'widgets/actualizacion.dart';
import 'widgets/carga.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await sesion.cargar();
  runApp(const ForjaApp());
}

class ForjaApp extends StatefulWidget {
  const ForjaApp({super.key});

  @override
  State<ForjaApp> createState() => _ForjaAppState();
}

class _ForjaAppState extends State<ForjaApp> {
  final store = ForjaStore();
  final messengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    store.ultimoMensaje.addListener(_mostrarMensaje);
  }

  void _mostrarMensaje() {
    final m = store.ultimoMensaje.value;
    if (m == null) return;
    avisar(messengerKey.currentState, m);
  }

  @override
  void dispose() {
    store.ultimoMensaje.removeListener(_mostrarMensaje);
    store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ForjaApp',
      debugShowCheckedModeBanner: false,
      theme: Forja.tema(),
      scaffoldMessengerKey: messengerKey,
      home: Arranque(store: store),
    );
  }
}

/// Notificación flotante de la app. Con [error] sale en rojo.
void avisar(ScaffoldMessengerState? m, String texto, {bool error = false}) {
  m
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      backgroundColor: error ? Forja.rojo : Forja.hierro,
      content: Row(children: [
        Icon(error ? Icons.error_outline_rounded : Icons.notifications_active_outlined,
            color: error ? Colors.white : Forja.ascua, size: 20),
        const SizedBox(width: Esp.m),
        Expanded(child: Text(texto)),
      ]),
      duration: const Duration(seconds: 4),
      width: 560,
      showCloseIcon: true,
      closeIconColor: Colors.white,
    ));
}

/// Pantalla de carga breve al abrir la app; después, inicio de sesión o la app.
class Arranque extends StatefulWidget {
  const Arranque({super.key, required this.store});
  final ForjaStore store;

  @override
  State<Arranque> createState() => _ArranqueState();
}

class _ArranqueState extends State<Arranque> {
  bool listo = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1100), () {
      if (mounted) setState(() => listo = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: sesion,
      builder: (context, _) {
        final u = sesion.usuario;
        return AvisoActualizacion(
          child: AnimatedSwitcher(
            duration: Mov.largo,
            child: !listo
                ? const _Bienvenida()
                : u == null
                    // Sin sesión no se ve nada de la app: primero hay que entrar.
                    ? const PantallaCuenta(key: ValueKey('cuenta'))
                    : Inicio(key: ValueKey('inicio-${u.id}'), store: widget.store),
          ),
        );
      },
    );
  }
}

class _Bienvenida extends StatelessWidget {
  const _Bienvenida();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Forja.hierro,
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Logo(tam: 88),
          SizedBox(height: Esp.xl),
          Text('FORJA TRAINING CLUB',
              style: TextStyle(
                  fontFamily: Forja.display,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 3,
                  color: Colors.white)),
          SizedBox(height: Esp.l),
          SizedBox(
            width: 160,
            child: LinearProgressIndicator(
              minHeight: 3,
              color: Forja.ascua,
              backgroundColor: Forja.hierro3,
              semanticsLabel: 'Cargando los datos del club',
            ),
          ),
        ]),
      ),
    );
  }
}

/// Secciones de la app y qué roles las ven. Lo que se enseña aquí es solo
/// comodidad: el servidor vuelve a comprobar el rol en cada petición.
enum _Seccion {
  pase('pase', Icons.qr_code_2_outlined, Icons.qr_code_2_rounded, 'Mi pase', 'QR de entrada', {'socio'}),
  recepcion('recepcion', Icons.space_dashboard_outlined, Icons.space_dashboard_rounded, 'Recepción',
      'Ocupación y socios', {'admin', 'trabajador'}),
  acceso('acceso', Icons.qr_code_scanner_outlined, Icons.qr_code_scanner_rounded, 'Punto de acceso', 'Tablet del torno',
      {'admin', 'trabajador'}),
  fichajes('fichajes', Icons.badge_outlined, Icons.badge_rounded, 'Fichajes', 'Registro de jornada',
      {'admin', 'trabajador'}),
  usuarios('usuarios', Icons.manage_accounts_outlined, Icons.manage_accounts_rounded, 'Usuarios',
      'Cuentas y trabajadores', {'admin'}),
  mensajes('mensajes', Icons.mail_outline_rounded, Icons.mail_rounded, 'Mensajes', 'Bandeja de contacto', {'admin'}),
  planes('planes', Icons.workspace_premium_outlined, Icons.workspace_premium_rounded, 'Planes', 'Cuotas y suscripción',
      {'admin', 'trabajador', 'socio'}),
  contacto('contacto', Icons.support_agent_outlined, Icons.support_agent_rounded, 'Contacto', 'Escribe a gerencia',
      {'trabajador', 'socio'});

  const _Seccion(this.id, this.icono, this.iconoActivo, this.titulo, this.descripcion, this.roles);
  final String id;
  final IconData icono;
  final IconData iconoActivo;
  final String titulo;
  final String descripcion;
  final Set<String> roles;

  String tituloPara(Usuario u) => this == fichajes && u.esTrabajador ? 'Mis fichajes' : titulo;
}

class Inicio extends StatefulWidget {
  const Inicio({super.key, required this.store});
  final ForjaStore store;

  @override
  State<Inicio> createState() => _InicioState();
}

class _InicioState extends State<Inicio> {
  late final Usuario u = sesion.usuario!;
  late final List<_Seccion> secciones = [
    for (final s in _Seccion.values)
      if (s.roles.contains(u.rol)) s
  ];

  /// En la web se puede abrir una sección directamente: ?seccion=recepcion
  late _Seccion seccion = secciones.firstWhere(
    (s) => s.id == Uri.base.queryParameters['seccion'],
    orElse: () => secciones.first,
  );

  @override
  void initState() {
    super.initState();
    if (sesion.mostrarPlanes) {
      sesion.mostrarPlanes = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) mostrarPlanesBienvenida(context);
      });
    }
  }

  void _ir(_Seccion s) => setState(() => seccion = s);

  Widget _pantalla() => switch (seccion) {
        _Seccion.pase => PantallaPase(verPlanes: () => _ir(_Seccion.planes)),
        _Seccion.recepcion => const PantallaRecepcion(),
        _Seccion.acceso => const PantallaAcceso(),
        _Seccion.fichajes => const PantallaFichajes(),
        _Seccion.usuarios => const PantallaUsuarios(),
        _Seccion.mensajes => const PantallaMensajes(),
        _Seccion.planes => const PantallaPlanes(),
        _Seccion.contacto => const PantallaContacto(),
      };

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final estrecho = c.maxWidth < 900;
      final contenido = AnimatedSwitcher(
        duration: Mov.medio,
        switchInCurve: Mov.curva,
        transitionBuilder: (child, a) => FadeTransition(
          opacity: a,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.015), end: Offset.zero).animate(a),
            child: child,
          ),
        ),
        child: KeyedSubtree(key: ValueKey(seccion), child: SizedBox.expand(child: _pantalla())),
      );
      if (estrecho) {
        // En pantallas estrechas (el móvil) el menú pasa a un cajón.
        return Scaffold(
          appBar: AppBar(
            backgroundColor: Forja.hierro,
            foregroundColor: Colors.white,
            titleSpacing: 0,
            title: Row(children: [
              const Logo(tam: 30),
              const SizedBox(width: Esp.m),
              Flexible(
                child: Text(seccion.tituloPara(u),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: Forja.display, fontWeight: FontWeight.w700, fontSize: 22)),
              ),
            ]),
            actions: [_MenuCuenta(u: u, claro: true), const SizedBox(width: Esp.xs)],
          ),
          drawer: Drawer(
            backgroundColor: Forja.hierro,
            child: SafeArea(child: _menu(cerrarAlElegir: true)),
          ),
          // SafeArea deja libre la barra de gestos de Android.
          body: SafeArea(top: false, child: contenido),
        );
      }
      return Scaffold(
        body: Row(children: [
          SizedBox(width: 248, child: ColoredBox(color: Forja.hierro, child: _menu())),
          Expanded(
            child: Column(children: [
              _barraSuperior(),
              Expanded(child: contenido),
            ]),
          ),
        ]),
      );
    });
  }

  Widget _barraSuperior() {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final ahora = DateTime.now();
        final f = fechaLarga(ahora);
        return Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: Esp.xxl),
          decoration: const BoxDecoration(
            color: Forja.superficie,
            border: Border(bottom: BorderSide(color: Forja.linea)),
          ),
          child: Row(children: [
            const Icon(Icons.location_on_outlined, size: 18, color: Forja.gris),
            const SizedBox(width: Esp.xs),
            const Flexible(
              child:
                  Text('Forja Training Club · Guadalajara', style: Txt.cuerpoFuerte, overflow: TextOverflow.ellipsis),
            ),
            const Spacer(),
            Text('${f[0].toUpperCase()}${f.substring(1)}', style: Txt.secundario.copyWith(fontSize: 14)),
            const SizedBox(width: Esp.m),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Forja.acero, borderRadius: BorderRadius.circular(Rad.s)),
              child: Text(horaSeg(ahora), style: Txt.hora.copyWith(fontSize: 16)),
            ),
            const SizedBox(width: Esp.l),
            const SizedBox(height: 28, child: VerticalDivider()),
            const SizedBox(width: Esp.s),
            _MenuCuenta(u: u),
          ]),
        );
      },
    );
  }

  Widget _menu({bool cerrarAlElegir = false}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Esp.l, Esp.xl, Esp.l, Esp.l),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: Esp.s),
          child: Row(children: [
            Logo(tam: 42),
            SizedBox(width: Esp.m),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('FORJA',
                  style: TextStyle(
                      fontFamily: Forja.display,
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.5,
                      height: 1)),
              Text('TRAINING CLUB',
                  style: TextStyle(
                      fontFamily: Forja.display,
                      color: Forja.grisOscuro,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2.4)),
            ]),
          ]),
        ),
        const SizedBox(height: Esp.xxl),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: Esp.s),
          child: Text('SECCIONES',
              style: TextStyle(color: Forja.grisOscuro, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1.4)),
        ),
        const SizedBox(height: Esp.s),
        Expanded(
          child: ListView(padding: EdgeInsets.zero, children: [
            for (final s in secciones) _botonMenu(s, cerrarAlElegir),
          ]),
        ),
        const SizedBox(height: Esp.m),
        Container(
          padding: const EdgeInsets.all(Esp.m),
          decoration: BoxDecoration(
            color: Forja.hierro2,
            borderRadius: BorderRadius.circular(Rad.m),
            border: Border.all(color: Forja.hierro3),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.dns_outlined, size: 18, color: Forja.paja),
            const SizedBox(width: Esp.s),
            Expanded(
              child: Text(
                'Conectado a ForjaApp Servidor\n${sesion.servidor}',
                style: const TextStyle(color: Forja.grisClaro, fontSize: 12.5, height: 1.4),
              ),
            ),
          ]),
        ),
        const SizedBox(height: Esp.m),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: Esp.s),
          child: Text('Proyecto de 2.º DAM · Álvaro Martínez', style: TextStyle(color: Forja.grisOscuro, fontSize: 12)),
        ),
      ]),
    );
  }

  Widget _botonMenu(_Seccion s, bool cerrarAlElegir) {
    final activo = s == seccion;
    return Padding(
      padding: const EdgeInsets.only(bottom: Esp.xs),
      child: Semantics(
        selected: activo,
        button: true,
        child: Material(
          color: activo ? Forja.hierro2 : Colors.transparent,
          borderRadius: BorderRadius.circular(Rad.m),
          child: InkWell(
            borderRadius: BorderRadius.circular(Rad.m),
            hoverColor: Forja.hierro2,
            focusColor: Forja.hierro3,
            onTap: () {
              _ir(s);
              if (cerrarAlElegir) Navigator.of(context).maybePop();
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Esp.xs, 10, Esp.m, 10),
              child: Row(children: [
                AnimatedContainer(
                  duration: Mov.medio,
                  width: 3,
                  height: 30,
                  decoration: BoxDecoration(
                    color: activo ? Forja.ascua : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: Esp.m),
                Icon(activo ? s.iconoActivo : s.icono, size: 22, color: activo ? Forja.ascua : Forja.grisClaro),
                const SizedBox(width: Esp.m),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s.tituloPara(u),
                        style: TextStyle(
                          color: activo ? Colors.white : Forja.grisClaro,
                          fontWeight: activo ? FontWeight.w600 : FontWeight.w500,
                          fontSize: 15,
                        )),
                    Text(s.descripcion, style: const TextStyle(color: Forja.grisOscuro, fontSize: 12)),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Usuario conectado con su menú: cambiar contraseña y cerrar sesión.
class _MenuCuenta extends StatelessWidget {
  const _MenuCuenta({required this.u, this.claro = false});
  final Usuario u;
  final bool claro;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Tu cuenta',
      position: PopupMenuPosition.under,
      onSelected: (v) async {
        if (v == 'contrasena') await _cambiarContrasena(context);
        if (v == 'salir') await sesion.salir();
      },
      itemBuilder: (_) => [
        PopupMenuItem(enabled: false, child: Text(u.email, style: Txt.secundario)),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'contrasena',
          child: ListTile(leading: Icon(Icons.key_rounded), title: Text('Cambiar contraseña')),
        ),
        const PopupMenuItem(
          value: 'salir',
          child: ListTile(leading: Icon(Icons.logout_rounded), title: Text('Cerrar sesión')),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Esp.s, vertical: Esp.xs),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Avatar(u.nombre, tam: 32, fondo: Forja.templeSuave, color: Forja.temple),
          if (!claro) ...[
            const SizedBox(width: Esp.s),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(u.nombre, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                Text(u.nombreRol, style: const TextStyle(fontSize: 12, color: Forja.gris)),
              ],
            ),
          ],
          Icon(Icons.expand_more_rounded, color: claro ? Colors.white : Forja.gris),
        ]),
      ),
    );
  }
}

Future<void> _cambiarContrasena(BuildContext context) {
  final actual = TextEditingController();
  final nueva = TextEditingController();
  final nueva2 = TextEditingController();
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Cambiar contraseña'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            CampoContrasena(controller: actual, etiqueta: 'Contraseña actual'),
            const SizedBox(height: Esp.m),
            CampoContrasena(
              controller: nueva,
              etiqueta: 'Contraseña nueva',
              ayuda: 'Mínimo 8 caracteres, con letras y números.',
            ),
            const SizedBox(height: Esp.m),
            CampoContrasena(controller: nueva2, etiqueta: 'Repite la contraseña nueva'),
            const SizedBox(height: Esp.m),
            const Nota('Se cerrará la sesión en tus otros dispositivos.'),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () async {
            final ok = await intentar(ctx, () => sesion.api.cambiarContrasena(actual.text, nueva.text, nueva2.text),
                exito: 'Contraseña cambiada.');
            if (ok && ctx.mounted) Navigator.pop(ctx);
          },
          child: const Text('Guardar'),
        ),
      ],
    ),
  ).whenComplete(() {
    actual.dispose();
    nueva.dispose();
    nueva2.dispose();
  });
}
