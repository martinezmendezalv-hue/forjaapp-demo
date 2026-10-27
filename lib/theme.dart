import 'package:flutter/material.dart';

/// Identidad de Forja: acero templado.
///
/// Al templar el acero, el metal pasa por colores según la temperatura:
/// azul cuando está frío, paja a media temperatura y ascua al rojo vivo.
/// Esos tres colores son también los estados de la app: una clase con
/// sitio está "fría" (azul) y una clase llena está "al rojo" (ascua).
class Forja {
  // Neutros
  static const hierro = Color(0xFF15181D); // menú lateral, marco del móvil
  static const hierro2 = Color(0xFF22262E);
  static const hierro3 = Color(0xFF2E333D);
  static const acero = Color(0xFFEEF1F4); // fondo de la app
  static const superficie = Color(0xFFFFFFFF);
  static const linea = Color(0xFFDDE2E8);
  static const tinta = Color(0xFF1B1F27); // texto principal
  static const gris = Color(0xFF5A6270); // texto secundario (6,1:1 sobre blanco)
  static const grisClaro = Color(0xFFC9CED6); // texto sobre hierro
  static const grisOscuro = Color(0xFF8B93A0); // texto secundario sobre hierro

  // Marca: ascua
  static const ascua = Color(0xFFE8611A); // rellenos y detalles, nunca texto pequeño
  static const ascuaTexto = Color(0xFFB8400D); // botones con texto blanco (5,5:1)
  static const ascuaSuave = Color(0xFFFDEBDF);

  // Colores de temple, usados como estados
  static const temple = Color(0xFF2C5E8F); // libre / información
  static const templeSuave = Color(0xFFE4EDF6);
  static const paja = Color(0xFFD99A1E); // casi llena / aviso
  static const pajaTexto = Color(0xFF8A5A00);
  static const pajaSuave = Color(0xFFFBF0D9);
  static const verde = Color(0xFF1F7A4D); // concedido / correcto
  static const verdeSuave = Color(0xFFE3F3EA);
  static const rojo = Color(0xFFB42318); // denegado / error
  static const rojoSuave = Color(0xFFFDE8E6);

  /// Degradado de temple para las barras de ocupación.
  static const gradienteTemple = [temple, paja, ascua];

  static const display = 'BarlowCondensed';
  static const texto = 'Barlow';

  static ThemeData tema() {
    final esquema = ColorScheme.fromSeed(
      seedColor: ascua,
      primary: ascuaTexto,
      onPrimary: Colors.white,
      secondary: temple,
      surface: superficie,
      onSurface: tinta,
      error: rojo,
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: esquema,
      scaffoldBackgroundColor: acero,
      fontFamily: texto,
      visualDensity: VisualDensity.standard,
    );
    final boton = RoundedRectangleBorder(borderRadius: BorderRadius.circular(Rad.m));
    return base.copyWith(
      textTheme: base.textTheme.apply(bodyColor: tinta, displayColor: tinta, fontFamily: texto),
      dividerTheme: const DividerThemeData(color: linea, thickness: 1, space: 1),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ascuaTexto,
          foregroundColor: Colors.white,
          disabledBackgroundColor: linea,
          disabledForegroundColor: gris,
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: Esp.l),
          shape: boton,
          textStyle: const TextStyle(fontFamily: texto, fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: tinta,
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: Esp.l),
          side: const BorderSide(color: linea, width: 1.5),
          shape: boton,
          textStyle: const TextStyle(fontFamily: texto, fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ascuaTexto,
          minimumSize: const Size(0, 40),
          shape: boton,
          textStyle: const TextStyle(fontFamily: texto, fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: acero,
        labelStyle: const TextStyle(color: gris),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(Rad.m), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Rad.m),
          borderSide: const BorderSide(color: linea),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Rad.m),
          borderSide: const BorderSide(color: ascuaTexto, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Rad.m),
          borderSide: const BorderSide(color: rojo, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Rad.m),
          borderSide: const BorderSide(color: rojo, width: 2),
        ),
      ),
      dialogTheme: DialogTheme(
        backgroundColor: superficie,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Rad.l)),
        titleTextStyle: const TextStyle(fontFamily: display, fontSize: 26, fontWeight: FontWeight.w700, color: tinta),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: hierro,
        contentTextStyle: const TextStyle(fontFamily: texto, color: Colors.white, fontSize: 14),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Rad.m)),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: hierro, borderRadius: BorderRadius.circular(Rad.s)),
        textStyle: const TextStyle(fontFamily: texto, color: Colors.white, fontSize: 13),
      ),
      sliderTheme: const SliderThemeData(activeTrackColor: ascuaTexto, thumbColor: ascuaTexto),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: ascuaSuave,
          selectedForegroundColor: ascuaTexto,
          side: const BorderSide(color: linea),
        ),
      ),
    );
  }
}

/// Escala de espaciado (múltiplos de 4).
class Esp {
  static const xs = 4.0;
  static const s = 8.0;
  static const m = 12.0;
  static const l = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

/// Radios de esquina.
class Rad {
  static const s = 6.0;
  static const m = 10.0;
  static const l = 16.0;
  static const xl = 24.0;
}

/// Duraciones de animación.
class Mov {
  static const corto = Duration(milliseconds: 180);
  static const medio = Duration(milliseconds: 280);
  static const largo = Duration(milliseconds: 450);
  static const curva = Curves.easeOutCubic;
}

/// Escala tipográfica.
class Txt {
  static const titular =
      TextStyle(fontFamily: Forja.display, fontSize: 34, fontWeight: FontWeight.w700, height: 1.05, color: Forja.tinta);
  static const tituloSeccion =
      TextStyle(fontFamily: Forja.display, fontSize: 22, fontWeight: FontWeight.w700, height: 1.1, color: Forja.tinta);
  static const cifra = TextStyle(
    fontFamily: Forja.display,
    fontSize: 36,
    fontWeight: FontWeight.w700,
    height: 1,
    color: Forja.tinta,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const etiqueta = TextStyle(
      fontFamily: Forja.texto, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1.1, color: Forja.gris);
  static const cuerpo = TextStyle(fontFamily: Forja.texto, fontSize: 15, height: 1.4, color: Forja.tinta);
  static const cuerpoFuerte =
      TextStyle(fontFamily: Forja.texto, fontSize: 15, fontWeight: FontWeight.w600, color: Forja.tinta);
  static const secundario = TextStyle(fontFamily: Forja.texto, fontSize: 13, height: 1.35, color: Forja.gris);
  static const hora = TextStyle(
    fontFamily: Forja.display,
    fontSize: 17,
    fontWeight: FontWeight.w700,
    color: Forja.tinta,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}

// ------------------------------------------------------------------ estados

/// Un estado con color e icono, para que nunca dependa solo del color.
class Estado {
  const Estado(this.texto, this.icono, this.color, this.fondo);
  final String texto;
  final IconData icono;
  final Color color;
  final Color fondo;

  static const libre = Estado('Plazas libres', Icons.check_circle_outline_rounded, Forja.temple, Forja.templeSuave);
  static const ultimas =
      Estado('Últimas plazas', Icons.local_fire_department_outlined, Forja.pajaTexto, Forja.pajaSuave);
  static const llena = Estado('Completa', Icons.block_rounded, Forja.rojo, Forja.rojoSuave);
  static const terminada = Estado('Terminada', Icons.history_rounded, Forja.gris, Forja.acero);
  static const reservada = Estado('Reservada', Icons.event_available_rounded, Forja.verde, Forja.verdeSuave);
  static const espera = Estado('En espera', Icons.hourglass_top_rounded, Forja.pajaTexto, Forja.pajaSuave);
}

/// Insignia de estado: icono + texto sobre fondo suave.
class Insignia extends StatelessWidget {
  const Insignia(this.estado, {super.key, this.texto});

  final Estado estado;
  final String? texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: estado.fondo, borderRadius: BorderRadius.circular(Rad.s)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(estado.icono, size: 14, color: estado.color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(texto ?? estado.texto,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: estado.color, height: 1.2)),
        ),
      ]),
    );
  }
}

// --------------------------------------------------------------- componentes

/// Tarjeta blanca con borde fino. Sin sombras: la jerarquía la marcan
/// el borde y el fondo acero.
class Tarjeta extends StatelessWidget {
  const Tarjeta({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Esp.xl),
    this.color = Forja.superficie,
    this.borde = Forja.linea,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color borde;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: Mov.medio,
      curve: Mov.curva,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(Rad.l),
        border: Border.all(color: borde, width: borde == Forja.linea ? 1 : 1.5),
      ),
      child: child,
    );
  }
}

/// Título de un bloque, con texto de apoyo y acción opcional a la derecha.
class TituloBloque extends StatelessWidget {
  const TituloBloque(this.titulo, {super.key, this.apoyo, this.accion});
  final String titulo;
  final String? apoyo;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Semantics(header: true, child: Text(titulo, style: Txt.tituloSeccion)),
          if (apoyo != null) ...[
            const SizedBox(height: 2),
            Text(apoyo!, style: Txt.secundario),
          ],
        ]),
      ),
      if (accion != null) ...[const SizedBox(width: Esp.m), accion!],
    ]);
  }
}

/// Cabecera de cada panel: antetítulo, titular y acciones.
class CabeceraPanel extends StatelessWidget {
  const CabeceraPanel({super.key, required this.antetitulo, required this.titulo, this.acciones = const []});
  final String antetitulo;
  final String titulo;
  final List<Widget> acciones;

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(antetitulo.toUpperCase(), style: Txt.etiqueta),
          const SizedBox(height: Esp.xs),
          Semantics(header: true, child: Text(titulo, style: Txt.titular)),
        ]),
      ),
      for (final a in acciones) ...[const SizedBox(width: Esp.m), a],
    ]);
  }
}

/// Indicador numérico de la fila superior de los paneles.
class Indicador extends StatelessWidget {
  const Indicador({
    super.key,
    required this.valor,
    required this.texto,
    required this.icono,
    this.color = Forja.tinta,
    this.detalle,
  });

  final String valor;
  final String texto;
  final IconData icono;
  final Color color;
  final String? detalle;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$texto: $valor${detalle != null ? '. $detalle' : ''}',
      excludeSemantics: true,
      child: Tarjeta(
        padding: const EdgeInsets.fromLTRB(20, Esp.l, 20, Esp.l),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icono, size: 18, color: color),
            const SizedBox(width: Esp.s),
            Expanded(
              child: Text(texto,
                  style: Txt.secundario.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
          ]),
          const SizedBox(height: Esp.s),
          AnimatedSwitcher(
            duration: Mov.medio,
            transitionBuilder: (child, a) => FadeTransition(
              opacity: a,
              child: SlideTransition(
                position: Tween(begin: const Offset(0, 0.3), end: Offset.zero).animate(a),
                child: child,
              ),
            ),
            child: Text(valor, key: ValueKey(valor), style: Txt.cifra.copyWith(color: color)),
          ),
          if (detalle != null) ...[
            const SizedBox(height: Esp.xs),
            Text(detalle!, style: Txt.secundario, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ]),
      ),
    );
  }
}

/// Barra de ocupación "al temple": el relleno se calienta de azul a ascua
/// según se llena la clase. Es el elemento visual propio de Forja.
class BarraTemple extends StatelessWidget {
  const BarraTemple(this.valor, {super.key, this.alto = 8, this.fondo = Forja.acero});
  final double valor;
  final double alto;
  final Color fondo;

  @override
  Widget build(BuildContext context) {
    final v = valor.clamp(0.0, 1.0);
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(alto),
        child: SizedBox(
          height: alto,
          child: LayoutBuilder(builder: (context, c) {
            return Stack(children: [
              Positioned.fill(child: ColoredBox(color: fondo)),
              TweenAnimationBuilder<double>(
                tween: Tween(end: v),
                duration: Mov.largo,
                curve: Mov.curva,
                builder: (_, x, __) => SizedBox(
                  width: c.maxWidth * x,
                  height: alto,
                  child: ClipRect(
                    child: OverflowBox(
                      alignment: Alignment.centerLeft,
                      minWidth: c.maxWidth,
                      maxWidth: c.maxWidth,
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: Forja.gradienteTemple, stops: [0.35, 0.7, 0.95]),
                        ),
                        child: SizedBox.expand(),
                      ),
                    ),
                  ),
                ),
              ),
            ]);
          }),
        ),
      ),
    );
  }
}

/// Avatar con iniciales.
class Avatar extends StatelessWidget {
  const Avatar(this.nombre, {super.key, this.tam = 36, this.fondo = Forja.ascuaSuave, this.color = Forja.ascuaTexto});
  final String nombre;
  final double tam;
  final Color fondo;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ini = nombre.split(' ').where((p) => p.isNotEmpty).take(2).map((p) => p[0]).join().toUpperCase();
    return ExcludeSemantics(
      child: Container(
        width: tam,
        height: tam,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: fondo, shape: BoxShape.circle),
        child: Text(ini,
            style: TextStyle(
                fontFamily: Forja.display, fontWeight: FontWeight.w700, fontSize: tam * 0.42, color: color, height: 1)),
      ),
    );
  }
}

/// Estado vacío: icono, frase y, si tiene sentido, una acción.
class EstadoVacio extends StatelessWidget {
  const EstadoVacio({super.key, required this.icono, required this.titulo, required this.texto, this.accion});
  final IconData icono;
  final String titulo;
  final String texto;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Esp.xl, vertical: Esp.xxl),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(color: Forja.acero, shape: BoxShape.circle),
          child: Icon(icono, size: 30, color: Forja.gris),
        ),
        const SizedBox(height: Esp.l),
        Text(titulo, textAlign: TextAlign.center, style: Txt.tituloSeccion.copyWith(fontSize: 20)),
        const SizedBox(height: Esp.xs),
        Text(texto, textAlign: TextAlign.center, style: Txt.secundario),
        if (accion != null) ...[const SizedBox(height: Esp.l), accion!],
      ]),
    );
  }
}

/// Bloque de carga con un brillo que lo recorre.
class Esqueleto extends StatefulWidget {
  const Esqueleto({super.key, this.alto = 16, this.ancho, this.radio = Rad.s});
  final double alto;
  final double? ancho;
  final double radio;

  @override
  State<Esqueleto> createState() => _EsqueletoState();
}

class _EsqueletoState extends State<Esqueleto> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Container(
        height: widget.alto,
        width: widget.ancho,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radio),
          gradient: LinearGradient(
            begin: Alignment(-3 + _c.value * 4, 0),
            end: Alignment(-1 + _c.value * 4, 0),
            colors: const [Color(0xFFE6EAEE), Color(0xFFF6F8FA), Color(0xFFE6EAEE)],
          ),
        ),
      ),
    );
  }
}

/// Recuadro informativo discreto.
class Nota extends StatelessWidget {
  const Nota(
    this.texto, {
    super.key,
    this.titulo,
    this.icono = Icons.info_outline_rounded,
    this.color = Forja.temple,
    this.fondo = Forja.templeSuave,
  });
  final String? titulo;
  final String texto;
  final IconData icono;
  final Color color;
  final Color fondo;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Esp.m),
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(Rad.m)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icono, size: 18, color: color),
        const SizedBox(width: Esp.s),
        Expanded(
          child: Text.rich(
            TextSpan(children: [
              if (titulo != null) TextSpan(text: '$titulo ', style: const TextStyle(fontWeight: FontWeight.w700)),
              TextSpan(text: texto),
            ]),
            style: const TextStyle(fontSize: 13.5, color: Forja.tinta, height: 1.4),
          ),
        ),
      ]),
    );
  }
}

/// Logotipo de Forja: la F en ascua sobre hierro con la franja de temple.
class Logo extends StatelessWidget {
  const Logo({super.key, this.tam = 40});
  final double tam;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: tam,
        height: tam,
        decoration: BoxDecoration(
          color: Forja.hierro,
          borderRadius: BorderRadius.circular(tam * 0.24),
          border: Border.all(color: Forja.hierro3),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('F',
              style: TextStyle(
                  fontFamily: Forja.display,
                  fontWeight: FontWeight.w800,
                  fontSize: tam * 0.6,
                  height: 1,
                  color: Forja.ascua)),
          SizedBox(height: tam * 0.04),
          Container(
            width: tam * 0.6,
            height: tam * 0.06,
            decoration: const BoxDecoration(gradient: LinearGradient(colors: Forja.gradienteTemple)),
          ),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------- tablas

/// Cabecera de tabla con columnas de ancho fijo (o flexible si es null).
class CabeceraTabla extends StatelessWidget {
  const CabeceraTabla({super.key, required this.columnas});
  final List<(double?, String)> columnas;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Esp.s),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Forja.linea))),
      child: Row(children: [
        for (final (ancho, texto) in columnas)
          if (ancho == null)
            Expanded(child: Text(texto, style: Txt.etiqueta.copyWith(fontSize: 11.5)))
          else
            SizedBox(width: ancho, child: Text(texto, style: Txt.etiqueta.copyWith(fontSize: 11.5))),
      ]),
    );
  }
}

/// Fila de tabla que se resalta al pasar el ratón.
class FilaTabla extends StatefulWidget {
  const FilaTabla({super.key, required this.child});
  final Widget child;

  @override
  State<FilaTabla> createState() => _FilaTablaState();
}

class _FilaTablaState extends State<FilaTabla> {
  bool encima = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => encima = true),
      onExit: (_) => setState(() => encima = false),
      child: AnimatedContainer(
        duration: Mov.corto,
        padding: const EdgeInsets.symmetric(horizontal: Esp.s, vertical: Esp.m),
        decoration: BoxDecoration(
          color: encima ? Forja.acero : Colors.transparent,
          borderRadius: BorderRadius.circular(Rad.s),
        ),
        child: widget.child,
      ),
    );
  }
}

// ---------------------------------------------------------------------- texto

String dosCifras(int n) => n.toString().padLeft(2, '0');

String hora(DateTime t) => '${dosCifras(t.hour)}:${dosCifras(t.minute)}';

String horaSeg(DateTime t) => '${hora(t)}:${dosCifras(t.second)}';

const _dias = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];
const _meses = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', //
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
];

/// «martes, 27 de octubre»
String fechaLarga(DateTime t) => '${_dias[t.weekday - 1]}, ${t.day} de ${_meses[t.month - 1]}';

/// «hace 3 min», «hace 2 h» o la hora si es de hace más.
String haceCuanto(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inSeconds < 60) return 'ahora mismo';
  if (d.inMinutes < 60) return 'hace ${d.inMinutes} min';
  if (d.inHours < 12) return 'hace ${d.inHours} h';
  return hora(t);
}
