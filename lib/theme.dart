import 'package:flutter/material.dart';

/// Colores de la marca ForjaApp (los mismos que la presentación).
class Forja {
  static const crema = Color(0xFFFFF7EC);
  static const tarjeta = Color(0xFFFFFDF9);
  static const marino = Color(0xFF1F2A44);
  static const gris = Color(0xFF5B6278);
  static const linea = Color(0xFFEDE3D6);

  static const coral = Color(0xFFFF6B57);
  static const coralSuave = Color(0xFFFFE1D9);
  static const rojo = Color(0xFFC93A26);

  static const turquesa = Color(0xFF20A39E);
  static const turquesaSuave = Color(0xFFD3F1EC);
  static const verde = Color(0xFF13827E);

  static const amarillo = Color(0xFFFFC845);
  static const amarilloSuave = Color(0xFFFFEFC2);
  static const ocre = Color(0xFF8A5A00);

  static const morado = Color(0xFF5A4FE0);
  static const moradoSuave = Color(0xFFE3E0FF);

  static ThemeData tema() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: morado,
        surface: crema,
      ),
      scaffoldBackgroundColor: crema,
      fontFamily: 'Segoe UI',
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(bodyColor: marino, displayColor: marino),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: marino,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// Tarjeta blanca con sombra suave, como en la presentación.
class Tarjeta extends StatelessWidget {
  const Tarjeta({super.key, required this.child, this.padding = const EdgeInsets.all(20), this.color = Forja.tarjeta});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Color(0x141F2A44), blurRadius: 24, offset: Offset(0, 8)),
        ],
      ),
      child: child,
    );
  }
}

/// Etiqueta en forma de píldora (p. ej. "RECEPCIÓN · HOY").
class Pildora extends StatelessWidget {
  const Pildora(this.texto, {super.key, this.fondo = Forja.coral, this.color = Forja.marino});

  final String texto;
  final Color fondo;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(20)),
      child: Text(
        texto,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: color),
      ),
    );
  }
}

/// Cabecera de pantalla: píldora, título y subtítulo en color.
class Cabecera extends StatelessWidget {
  const Cabecera({
    super.key,
    required this.etiqueta,
    required this.titulo,
    required this.subtitulo,
    this.colorEtiqueta = Forja.coral,
    this.colorTextoEtiqueta = Forja.marino,
    this.colorSubtitulo = Forja.rojo,
    this.accion,
  });

  final String etiqueta;
  final String titulo;
  final String subtitulo;
  final Color colorEtiqueta;
  final Color colorTextoEtiqueta;
  final Color colorSubtitulo;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Pildora(etiqueta, fondo: colorEtiqueta, color: colorTextoEtiqueta),
              const SizedBox(height: 10),
              Text(titulo, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: Forja.marino)),
              const SizedBox(height: 4),
              Text(subtitulo, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: colorSubtitulo)),
            ],
          ),
        ),
        if (accion != null) accion!,
      ],
    );
  }
}

/// Recuadro amarillo de nota, como los "Ejemplo:" de la presentación.
class Nota extends StatelessWidget {
  const Nota(this.negrita, this.texto, {super.key, this.fondo = Forja.amarilloSuave});

  final String negrita;
  final String texto;
  final Color fondo;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(12)),
      child: Text.rich(
        TextSpan(children: [
          TextSpan(text: '$negrita ', style: const TextStyle(fontWeight: FontWeight.w700)),
          TextSpan(text: texto),
        ]),
        style: const TextStyle(fontSize: 13, color: Forja.marino, height: 1.35),
      ),
    );
  }
}

/// Icono dentro de un círculo de color suave.
class IconoCirculo extends StatelessWidget {
  const IconoCirculo(this.icono, {super.key, this.fondo = Forja.coralSuave, this.color = Forja.rojo, this.tam = 40});

  final IconData icono;
  final Color fondo;
  final Color color;
  final double tam;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tam,
      height: tam,
      decoration: BoxDecoration(color: fondo, shape: BoxShape.circle),
      child: Icon(icono, color: color, size: tam * 0.5),
    );
  }
}

String dosCifras(int n) => n.toString().padLeft(2, '0');

String hora(DateTime t) => '${dosCifras(t.hour)}:${dosCifras(t.minute)}';

String horaSeg(DateTime t) => '${hora(t)}:${dosCifras(t.second)}';
