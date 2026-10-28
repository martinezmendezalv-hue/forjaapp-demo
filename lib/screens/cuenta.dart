import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../servicios/api.dart';
import '../servicios/sesion.dart';
import '../theme.dart';
import '../widgets/escaner.dart';

/// Pantalla de entrada: iniciar sesión o crear una cuenta nueva.
class PantallaCuenta extends StatefulWidget {
  const PantallaCuenta({super.key});

  @override
  State<PantallaCuenta> createState() => _PantallaCuentaState();
}

class _PantallaCuentaState extends State<PantallaCuenta> {
  bool registro = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Forja.hierro,
      body: LayoutBuilder(builder: (context, c) {
        final ancho = c.maxWidth >= 900;
        final formulario = Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: ancho ? Esp.xxl : Esp.l, vertical: Esp.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (!ancho) ...[const _Marca(compacta: true), const SizedBox(height: Esp.xl)],
                AnimatedSwitcher(
                  duration: Mov.medio,
                  child: registro
                      ? _FormRegistro(
                          key: const ValueKey('registro'), alCambiar: () => setState(() => registro = false))
                      : _FormLogin(key: const ValueKey('login'), alCambiar: () => setState(() => registro = true)),
                ),
                const SizedBox(height: Esp.l),
                _Servidor(oscuro: !ancho),
              ]),
            ),
          ),
        );
        if (!ancho) return SafeArea(child: formulario);
        return Row(children: [
          const Expanded(child: _Portada()),
          Expanded(child: ColoredBox(color: Forja.acero, child: formulario)),
        ]);
      }),
    );
  }
}

class _Marca extends StatelessWidget {
  const _Marca({this.compacta = false});
  final bool compacta;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Logo(tam: compacta ? 44 : 56),
      const SizedBox(width: Esp.m),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('FORJA',
            style: TextStyle(
                fontFamily: Forja.display,
                color: Colors.white,
                fontSize: compacta ? 28 : 36,
                fontWeight: FontWeight.w800,
                letterSpacing: 3,
                height: 1)),
        const Text('TRAINING CLUB',
            style: TextStyle(
                fontFamily: Forja.display,
                color: Forja.grisOscuro,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 2.4)),
      ]),
    ]);
  }
}

class _Portada extends StatelessWidget {
  const _Portada();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(56),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _Marca(),
        Spacer(),
        Text('Reserva, entra y\nentrena a tu ritmo.',
            style: TextStyle(
                fontFamily: Forja.display,
                fontSize: 54,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.02)),
        SizedBox(height: Esp.l),
        Text('Tus clases, tu pase de entrada y tu cuota, en una sola app.',
            style: TextStyle(color: Forja.grisClaro, fontSize: 18, height: 1.4)),
        SizedBox(height: Esp.xl),
        SizedBox(width: 280, child: BarraTemple(0.92, alto: 6, fondo: Forja.hierro3)),
        Spacer(),
        Text('Forja Training Club · Guadalajara', style: TextStyle(color: Forja.grisOscuro, fontSize: 13)),
      ]),
    );
  }
}

// ------------------------------------------------------------ componentes

/// Campo de contraseña con el botón del ojo para verla u ocultarla.
class CampoContrasena extends StatefulWidget {
  const CampoContrasena({
    super.key,
    required this.controller,
    required this.etiqueta,
    this.ayuda,
    this.alEnviar,
    this.autofill,
  });
  final TextEditingController controller;
  final String etiqueta;
  final String? ayuda;
  final VoidCallback? alEnviar;
  final Iterable<String>? autofill;

  @override
  State<CampoContrasena> createState() => _CampoContrasenaState();
}

class _CampoContrasenaState extends State<CampoContrasena> {
  bool visible = false;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: !visible,
      enableSuggestions: false,
      autocorrect: false,
      maxLength: 128,
      autofillHints: widget.autofill,
      textInputAction: widget.alEnviar == null ? TextInputAction.next : TextInputAction.done,
      onSubmitted: (_) => widget.alEnviar?.call(),
      decoration: InputDecoration(
        labelText: widget.etiqueta,
        helperText: widget.ayuda,
        helperMaxLines: 2,
        counterText: '',
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          tooltip: visible ? 'Ocultar contraseña' : 'Mostrar contraseña',
          onPressed: () => setState(() => visible = !visible),
          icon: Icon(visible ? Icons.visibility_off_outlined : Icons.visibility_outlined),
        ),
      ),
    );
  }
}

/// Estado del captcha: el id del reto, la imagen y lo que escribe el usuario.
class ControladorCaptcha extends ChangeNotifier {
  String? id;
  Uint8List? imagen;
  String? error;
  bool cargando = false;

  /// El servidor de la nube está despertando (la petición tarda).
  bool lento = false;
  final texto = TextEditingController();
  int _peticion = 0;
  bool _cerrado = false;

  Future<void> nuevo() async {
    final mia = ++_peticion;
    cargando = true;
    lento = false;
    error = null;
    texto.clear();
    notifyListeners();
    final aviso = Timer(const Duration(seconds: 4), () {
      if (mia == _peticion && cargando && !_cerrado) {
        lento = true;
        notifyListeners();
      }
    });
    String? fallo;
    ({String id, Uint8List imagen})? c;
    try {
      c = await sesion.api.captcha();
    } on ErrorServidor catch (e) {
      fallo = e.mensaje;
    } catch (_) {
      fallo = 'No se ha podido cargar la imagen de verificación. Pulsa el botón de recargar.';
    }
    aviso.cancel();
    // Si mientras tanto se pidió otra (o se cambió de servidor), esta ya no vale.
    if (mia != _peticion || _cerrado) return;
    id = c?.id;
    imagen = c?.imagen;
    error = fallo;
    cargando = false;
    lento = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _cerrado = true;
    texto.dispose();
    super.dispose();
  }
}

/// Captcha del servidor: imagen con letras y números deformados.
class Captcha extends StatefulWidget {
  const Captcha({super.key, required this.controller});
  final ControladorCaptcha controller;

  @override
  State<Captcha> createState() => _CaptchaState();
}

class _CaptchaState extends State<Captcha> {
  late String _servidor = sesion.servidor;

  @override
  void initState() {
    super.initState();
    sesion.addListener(_alCambiarSesion);
    widget.controller.nuevo();
  }

  @override
  void dispose() {
    sesion.removeListener(_alCambiarSesion);
    super.dispose();
  }

  /// Al elegir otro servidor, el código anterior ya no sirve: se pide otro.
  void _alCambiarSesion() {
    if (sesion.servidor == _servidor) return;
    _servidor = sesion.servidor;
    widget.controller.nuevo();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final c = widget.controller;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('VERIFICACIÓN', style: Txt.etiqueta),
          const SizedBox(height: Esp.s),
          Row(children: [
            Container(
              width: 180,
              height: 60,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Forja.acero,
                borderRadius: BorderRadius.circular(Rad.m),
                border: Border.all(color: Forja.linea),
              ),
              child: c.cargando
                  ? const Center(
                      child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)))
                  : c.imagen != null
                      ? Semantics(
                          label: 'Imagen de verificación con letras y números',
                          image: true,
                          child: Image.memory(
                            c.imagen!,
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                            errorBuilder: (_, __, ___) =>
                                const Center(child: Icon(Icons.broken_image_outlined, color: Forja.gris)),
                          ),
                        )
                      : const Center(child: Icon(Icons.cloud_off_rounded, color: Forja.gris)),
            ),
            const SizedBox(width: Esp.s),
            IconButton.outlined(
              tooltip: 'Otra imagen',
              onPressed: c.cargando ? null : c.nuevo,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ]),
          const SizedBox(height: Esp.s),
          TextField(
            controller: c.texto,
            maxLength: 6,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Los 6 caracteres de la imagen',
              counterText: '',
              prefixIcon: Icon(Icons.shield_outlined),
            ),
          ),
          if (c.lento) ...[
            const SizedBox(height: Esp.xs),
            const Text('Despertando el servidor… la primera vez puede tardar hasta un minuto.', style: Txt.secundario),
          ],
          if (c.error != null) ...[
            const SizedBox(height: Esp.xs),
            Text(c.error!, style: const TextStyle(color: Forja.rojo, fontSize: 13)),
          ],
        ]);
      },
    );
  }
}

class _Error extends StatelessWidget {
  const _Error(this.texto);
  final String? texto;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: Mov.corto,
      child: texto == null
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(bottom: Esp.m),
              child: Semantics(
                liveRegion: true,
                child: Nota(texto!, icono: Icons.error_outline_rounded, color: Forja.rojo, fondo: Forja.rojoSuave),
              ),
            ),
    );
  }
}

class _Tarjeta extends StatelessWidget {
  const _Tarjeta({required this.titulo, required this.subtitulo, required this.children});
  final String titulo;
  final String subtitulo;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Tarjeta(
      padding: const EdgeInsets.all(Esp.xl),
      child: AutofillGroup(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Semantics(header: true, child: Text(titulo, style: Txt.titular.copyWith(fontSize: 32))),
          const SizedBox(height: Esp.xs),
          Text(subtitulo, style: Txt.secundario.copyWith(fontSize: 14)),
          const SizedBox(height: Esp.xl),
          ...children,
        ]),
      ),
    );
  }
}

Widget _botonEnviar({required String texto, required bool enviando, required VoidCallback alPulsar}) {
  return FilledButton(
    onPressed: enviando ? null : alPulsar,
    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
    child: enviando
        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
        : Text(texto),
  );
}

// ------------------------------------------------------------ iniciar sesión

class _FormLogin extends StatefulWidget {
  const _FormLogin({super.key, required this.alCambiar});
  final VoidCallback alCambiar;

  @override
  State<_FormLogin> createState() => _FormLoginState();
}

class _FormLoginState extends State<_FormLogin> {
  late final correo = TextEditingController(text: sesion.ultimoCorreo);
  final clave = TextEditingController();
  final captcha = ControladorCaptcha();
  bool enviando = false;
  String? error;

  @override
  void dispose() {
    correo.dispose();
    clave.dispose();
    captcha.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (correo.text.trim().isEmpty || clave.text.isEmpty) {
      setState(() => error = 'Escribe tu correo y tu contraseña.');
      return;
    }
    if (captcha.id == null || captcha.texto.text.trim().length != 6) {
      setState(() => error = 'Escribe los 6 caracteres de la imagen de verificación.');
      return;
    }
    setState(() {
      enviando = true;
      error = null;
    });
    try {
      final r = await sesion.api.login(
        email: correo.text.trim(),
        password: clave.text,
        captchaId: captcha.id!,
        captcha: captcha.texto.text.trim(),
      );
      clave.clear();
      await sesion.entrar(r.token, r.usuario);
    } on ErrorServidor catch (e) {
      if (!mounted) return;
      setState(() => error = e.mensaje);
      captcha.nuevo(); // cada código sirve una sola vez
    } finally {
      if (mounted) setState(() => enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _Tarjeta(
      titulo: 'Iniciar sesión',
      subtitulo: 'Entra con la cuenta que creaste al registrarte.',
      children: [
        _Error(error),
        TextField(
          controller: correo,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          maxLength: 254,
          autofillHints: const [AutofillHints.email, AutofillHints.username],
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
              labelText: 'Correo electrónico', counterText: '', prefixIcon: Icon(Icons.alternate_email_rounded)),
        ),
        const SizedBox(height: Esp.m),
        CampoContrasena(controller: clave, etiqueta: 'Contraseña', autofill: const [AutofillHints.password]),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => restablecerContrasena(context, correo.text.trim()),
            child: const Text('¿Has olvidado tu contraseña?'),
          ),
        ),
        Captcha(controller: captcha),
        const SizedBox(height: Esp.xl),
        _botonEnviar(texto: 'Iniciar sesión', enviando: enviando, alPulsar: _entrar),
        const SizedBox(height: Esp.m),
        Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, children: [
          const Text('¿Aún no tienes cuenta?', style: Txt.secundario),
          TextButton(onPressed: widget.alCambiar, child: const Text('Regístrate')),
        ]),
      ],
    );
  }
}

// ----------------------------------------------- he olvidado mi contraseña

/// Dos pasos: se pide un código al correo de la cuenta y, con ese código,
/// se pone una contraseña nueva (la antigua no se puede enviar: el servidor
/// solo guarda su huella, no la contraseña).
Future<void> restablecerContrasena(BuildContext context, String correoInicial) async {
  final cambiada = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _DialogoRestablecer(correoInicial: correoInicial),
  );
  if (cambiada != null && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Contraseña cambiada. Ya puedes iniciar sesión con la nueva.')),
    );
  }
}

class _DialogoRestablecer extends StatefulWidget {
  const _DialogoRestablecer({required this.correoInicial});
  final String correoInicial;

  @override
  State<_DialogoRestablecer> createState() => _DialogoRestablecerState();
}

class _DialogoRestablecerState extends State<_DialogoRestablecer> {
  late final correo = TextEditingController(text: widget.correoInicial);
  final codigo = TextEditingController();
  final nueva = TextEditingController();
  final nueva2 = TextEditingController();
  final captcha = ControladorCaptcha();
  bool codigoEnviado = false;
  bool enviando = false;
  String? error;
  String? aviso;

  @override
  void dispose() {
    for (final c in [correo, codigo, nueva, nueva2]) {
      c.dispose();
    }
    captcha.dispose();
    super.dispose();
  }

  Future<void> _pedirCodigo() async {
    final email = correo.text.trim();
    if (!email.contains('@')) {
      setState(() => error = 'Escribe el correo de tu cuenta.');
      return;
    }
    if (captcha.id == null || captcha.texto.text.trim().length != 6) {
      setState(() => error = 'Escribe los 6 caracteres de la imagen de verificación.');
      return;
    }
    setState(() {
      enviando = true;
      error = null;
    });
    try {
      final m = await sesion.api.olvido(email: email, captchaId: captcha.id!, captcha: captcha.texto.text.trim());
      if (!mounted) return;
      setState(() {
        codigoEnviado = true;
        aviso = m;
      });
    } on ErrorServidor catch (e) {
      if (!mounted) return;
      setState(() => error = e.mensaje);
      captcha.nuevo();
    } finally {
      if (mounted) setState(() => enviando = false);
    }
  }

  Future<void> _cambiar() async {
    if (!RegExp(r'^\d{6}$').hasMatch(codigo.text.trim())) {
      setState(() => error = 'Escribe el código de 6 cifras que te ha llegado al correo.');
      return;
    }
    if (nueva.text != nueva2.text) {
      setState(() => error = 'Las contraseñas nuevas no coinciden.');
      return;
    }
    setState(() {
      enviando = true;
      error = null;
    });
    try {
      await sesion.api.restablecer(
        email: correo.text.trim(),
        codigo: codigo.text.trim(),
        nueva: nueva.text,
        nueva2: nueva2.text,
      );
      if (mounted) Navigator.pop(context, correo.text.trim());
    } on ErrorServidor catch (e) {
      if (mounted) setState(() => error = e.mensaje);
    } finally {
      if (mounted) setState(() => enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Restablecer la contraseña'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _Error(error),
            if (!codigoEnviado) ...[
              const Text(
                'Escribe el correo de tu cuenta y te enviaremos un código de 6 cifras para crear una contraseña nueva.',
                style: Txt.secundario,
              ),
              const SizedBox(height: Esp.l),
              TextField(
                controller: correo,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                maxLength: 254,
                decoration: const InputDecoration(
                    labelText: 'Correo electrónico', counterText: '', prefixIcon: Icon(Icons.alternate_email_rounded)),
              ),
              const SizedBox(height: Esp.l),
              Captcha(controller: captcha),
            ] else ...[
              if (aviso != null)
                Nota(aviso!, icono: Icons.mark_email_read_outlined, color: Forja.verde, fondo: Forja.verdeSuave),
              const SizedBox(height: Esp.l),
              TextField(
                controller: codigo,
                keyboardType: TextInputType.number,
                maxLength: 6,
                autofillHints: const [AutofillHints.oneTimeCode],
                decoration: const InputDecoration(
                    labelText: 'Código del correo', counterText: '', prefixIcon: Icon(Icons.pin_outlined)),
              ),
              const SizedBox(height: Esp.m),
              CampoContrasena(
                controller: nueva,
                etiqueta: 'Contraseña nueva',
                ayuda: 'Al menos 8 caracteres, con letras y números.',
                autofill: const [AutofillHints.newPassword],
              ),
              const SizedBox(height: Esp.m),
              CampoContrasena(
                controller: nueva2,
                etiqueta: 'Repite la contraseña nueva',
                autofill: const [AutofillHints.newPassword],
                alEnviar: _cambiar,
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: enviando
                      ? null
                      : () => setState(() {
                            codigoEnviado = false;
                            error = null;
                            captcha.nuevo();
                          }),
                  child: const Text('No me ha llegado: pedir otro código'),
                ),
              ),
            ],
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: enviando ? null : () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: enviando ? null : (codigoEnviado ? _cambiar : _pedirCodigo),
          child: enviando
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
              : Text(codigoEnviado ? 'Cambiar contraseña' : 'Enviar código'),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------- registrarse

class _FormRegistro extends StatefulWidget {
  const _FormRegistro({super.key, required this.alCambiar});
  final VoidCallback alCambiar;

  @override
  State<_FormRegistro> createState() => _FormRegistroState();
}

class _FormRegistroState extends State<_FormRegistro> {
  final nombre = TextEditingController();
  final correo = TextEditingController();
  final clave = TextEditingController();
  final clave2 = TextEditingController();
  final captcha = ControladorCaptcha();
  bool acepta = false;
  bool enviando = false;
  String? error;

  @override
  void dispose() {
    for (final c in [nombre, correo, clave, clave2]) {
      c.dispose();
    }
    captcha.dispose();
    super.dispose();
  }

  String? _comprobar() {
    if (nombre.text.trim().length < 2) return 'Escribe tu nombre y apellidos.';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(correo.text.trim())) return 'Escribe un correo válido.';
    final c = clave.text;
    if (c.length < 8 || !RegExp(r'\d').hasMatch(c) || !RegExp(r'[A-Za-zÁÉÍÓÚÜÑáéíóúüñ]').hasMatch(c)) {
      return 'La contraseña debe tener al menos 8 caracteres y combinar letras y números.';
    }
    if (c != clave2.text) return 'Las contraseñas no coinciden.';
    if (!acepta) return 'Tienes que aceptar las condiciones para crear la cuenta.';
    if (captcha.id == null || captcha.texto.text.trim().length != 6) {
      return 'Escribe los 6 caracteres de la imagen de verificación.';
    }
    return null;
  }

  Future<void> _crear() async {
    final problema = _comprobar();
    if (problema != null) {
      setState(() => error = problema);
      return;
    }
    setState(() {
      enviando = true;
      error = null;
    });
    try {
      final r = await sesion.api.registro(
        nombre: nombre.text.trim(),
        email: correo.text.trim(),
        password: clave.text,
        password2: clave2.text,
        acepta: acepta,
        captchaId: captcha.id!,
        captcha: captcha.texto.text.trim(),
      );
      sesion.mostrarPlanes = true;
      await sesion.entrar(r.token, r.usuario);
    } on ErrorServidor catch (e) {
      if (!mounted) return;
      setState(() => error = e.mensaje);
      captcha.nuevo();
    } finally {
      if (mounted) setState(() => enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _Tarjeta(
      titulo: 'Crear cuenta',
      subtitulo: 'Hazte socio en un minuto. Después eliges tu plan.',
      children: [
        _Error(error),
        TextField(
          controller: nombre,
          maxLength: 60,
          textCapitalization: TextCapitalization.words,
          autofillHints: const [AutofillHints.name],
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
              labelText: 'Nombre y apellidos', counterText: '', prefixIcon: Icon(Icons.person_outline_rounded)),
        ),
        const SizedBox(height: Esp.m),
        TextField(
          controller: correo,
          maxLength: 254,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          autofillHints: const [AutofillHints.email],
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
              labelText: 'Correo electrónico (será tu usuario)',
              counterText: '',
              prefixIcon: Icon(Icons.alternate_email_rounded)),
        ),
        const SizedBox(height: Esp.m),
        CampoContrasena(
          controller: clave,
          etiqueta: 'Contraseña',
          ayuda: 'Mínimo 8 caracteres, con letras y números.',
          autofill: const [AutofillHints.newPassword],
        ),
        const SizedBox(height: Esp.m),
        CampoContrasena(
            controller: clave2, etiqueta: 'Repite la contraseña', autofill: const [AutofillHints.newPassword]),
        const SizedBox(height: Esp.l),
        Captcha(controller: captcha),
        const SizedBox(height: Esp.m),
        CheckboxListTile(
          value: acepta,
          onChanged: (v) => setState(() => acepta = v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          title:
              const Text('Acepto las condiciones de uso y la política de privacidad', style: TextStyle(fontSize: 14)),
          subtitle: Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32)),
              onPressed: () => mostrarCondiciones(context),
              child: const Text('Leer las condiciones'),
            ),
          ),
        ),
        const SizedBox(height: Esp.l),
        _botonEnviar(texto: 'Crear cuenta', enviando: enviando, alPulsar: _crear),
        const SizedBox(height: Esp.m),
        Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, children: [
          const Text('¿Ya tienes cuenta?', style: Txt.secundario),
          TextButton(onPressed: widget.alCambiar, child: const Text('Inicia sesión')),
        ]),
      ],
    );
  }
}

Future<void> mostrarCondiciones(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Condiciones de uso'),
      content: const SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Text(
            'ForjaApp es una demo de un proyecto de 2.º de DAM para un gimnasio ficticio.\n\n'
            '1. Tus datos (nombre, correo y contraseña cifrada) se guardan solo en el servidor del gimnasio, '
            'en su propio ordenador. No se envían a terceros ni se usan para publicidad.\n\n'
            '2. Tu pase QR es personal: cambia cada 5 segundos y no sirve una captura de pantalla.\n\n'
            '3. Las cuotas se muestran a título informativo: en esta demo no se cobra nada.\n\n'
            '4. Puedes pedir que se borre tu cuenta escribiendo a la gerencia desde Contacto.\n\n'
            '5. No pedimos datos de salud ni huella dactilar.',
            style: TextStyle(height: 1.5),
          ),
        ),
      ),
      actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Entendido'))],
    ),
  );
}

// --------------------------------------------------------------- servidor

class _Servidor extends StatelessWidget {
  const _Servidor({required this.oscuro});
  final bool oscuro;

  @override
  Widget build(BuildContext context) {
    final color = oscuro ? Forja.grisClaro : Forja.gris;
    return ListenableBuilder(
      listenable: sesion,
      builder: (context, _) => Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Icon(Icons.dns_outlined, size: 16, color: color),
          const SizedBox(width: 6),
          Text(sesion.servidor.isEmpty ? 'Sin servidor configurado' : 'Servidor: ${sesion.servidor}',
              style: TextStyle(color: color, fontSize: 13)),
          TextButton(
            onPressed: () => configurarServidor(context),
            style: TextButton.styleFrom(foregroundColor: oscuro ? Forja.ascua : Forja.ascuaTexto),
            child: const Text('Cambiar'),
          ),
        ],
      ),
    );
  }
}

/// Diálogo para indicar dónde está ForjaApp Servidor.
Future<void> configurarServidor(BuildContext context) async {
  final ctrl = TextEditingController(text: sesion.servidor);
  String? estado;
  bool ok = false;
  bool probando = false;
  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) {
      Future<void> probar() async {
        setSt(() {
          probando = true;
          estado = null;
        });
        final api = ForjaApi(Sesion.normalizar(ctrl.text));
        try {
          await api.comprobar();
          final local = Sesion.esDeConfianza(ctrl.text);
          setSt(() {
            ok = local;
            estado = local
                ? 'Conectado con ForjaApp Servidor.'
                : 'Responde, pero no es el servidor de ForjaApp ni uno de la red local del gimnasio. '
                    'Guárdala solo si sabes que es vuestro servidor: podría ser una trampa para robar contraseñas.';
          });
        } on ErrorServidor catch (e) {
          setSt(() {
            ok = false;
            estado = e.mensaje;
          });
        }
        setSt(() => probando = false);
      }

      final movil = !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);
      return AlertDialog(
        title: const Text('Servidor'),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text(
                'Lo normal es usar el servidor de ForjaApp en internet, que funciona desde cualquier red. '
                'Si el gimnasio usa ForjaApp Servidor en su PC, escribe la dirección que aparece en su '
                'ventana (por ejemplo http://192.168.1.40:8080) o escanea su QR; entonces hay que estar en esa wifi.',
                style: Txt.secundario,
              ),
              const SizedBox(height: Esp.s),
              TextButton.icon(
                onPressed: () {
                  ctrl.text = Sesion.servidorNube;
                  probar();
                },
                icon: const Icon(Icons.cloud_outlined),
                label: const Text('Usar el servidor de internet'),
              ),
              const SizedBox(height: Esp.s),
              TextField(
                controller: ctrl,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration:
                    const InputDecoration(labelText: 'Dirección del servidor', prefixIcon: Icon(Icons.dns_outlined)),
                onSubmitted: (_) => probar(),
              ),
              if (movil) ...[
                const SizedBox(height: Esp.s),
                TextButton.icon(
                  onPressed: () async {
                    final leido = await _escanearDireccion(ctx);
                    if (leido != null) {
                      ctrl.text = leido;
                      probar();
                    }
                  },
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: const Text('Escanear el QR del servidor'),
                ),
              ],
              if (estado != null) ...[
                const SizedBox(height: Esp.s),
                Nota(estado!,
                    icono: ok ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded,
                    color: ok ? Forja.verde : Forja.rojo,
                    fondo: ok ? Forja.verdeSuave : Forja.rojoSuave),
              ],
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: probando ? null : probar, child: const Text('Probar conexión')),
          FilledButton(
            onPressed: () {
              sesion.cambiarServidor(ctrl.text);
              Navigator.pop(ctx);
            },
            child: const Text('Guardar'),
          ),
        ],
      );
    }),
  );
  ctrl.dispose();
}

Future<String?> _escanearDireccion(BuildContext context) {
  var leido = false;
  return showDialog<String>(
    context: context,
    builder: (ctx) => Dialog(
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 340,
        height: 420,
        child: Stack(children: [
          EscanerQr(alLeer: (t) {
            final u = Uri.tryParse(t);
            if (!leido && u != null && u.scheme == 'http' && u.host.isNotEmpty) {
              leido = true;
              Navigator.pop(ctx, t);
            }
          }),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              color: const Color(0xCC15181D),
              padding: const EdgeInsets.all(Esp.m),
              child: const Text('Apunta al QR de la ventana de ForjaApp Servidor',
                  textAlign: TextAlign.center, style: TextStyle(color: Colors.white)),
            ),
          ),
        ]),
      ),
    ),
  );
}
