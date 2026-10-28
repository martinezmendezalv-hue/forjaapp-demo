import 'package:flutter/material.dart';

import '../servicios/sesion.dart';
import '../theme.dart';
import '../widgets/carga.dart';

/// Sección «Contacto»: el mensaje llega a la bandeja de gerencia.
class PantallaContacto extends StatefulWidget {
  const PantallaContacto({super.key});

  @override
  State<PantallaContacto> createState() => _PantallaContactoState();
}

class _PantallaContactoState extends State<PantallaContacto> {
  final asunto = TextEditingController();
  final texto = TextEditingController();
  bool enviando = false;
  bool enviado = false;

  @override
  void dispose() {
    asunto.dispose();
    texto.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (enviando) return;
    setState(() => enviando = true);
    final ok = await intentar(context, () => sesion.api.contacto(asunto.text.trim(), texto.text.trim()));
    if (!mounted) return;
    setState(() {
      enviando = false;
      if (ok) {
        enviado = true;
        asunto.clear();
        texto.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      return SingleChildScrollView(
        padding: margenSeccion(c.maxWidth),
        child: Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (c.maxWidth >= 760) ...[
                const CabeceraPanel(antetitulo: 'Atención al socio', titulo: 'Contáctanos'),
                const SizedBox(height: Esp.xl),
              ],
              Tarjeta(child: enviado ? _gracias() : _formulario()),
              const SizedBox(height: Esp.l),
              const Nota('Te responderemos al correo de tu cuenta. Para urgencias, pásate por recepción.'),
            ]),
          ),
        ),
      );
    });
  }

  Widget _gracias() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: Esp.l),
        const Icon(Icons.mark_email_read_outlined, size: 48, color: Forja.verde),
        const SizedBox(height: Esp.m),
        const Text('Mensaje enviado', textAlign: TextAlign.center, style: Txt.tituloSeccion),
        const SizedBox(height: Esp.xs),
        const Text('Gerencia ya lo tiene en su bandeja.', textAlign: TextAlign.center, style: Txt.secundario),
        const SizedBox(height: Esp.l),
        Center(
          child: OutlinedButton(onPressed: () => setState(() => enviado = false), child: const Text('Escribir otro')),
        ),
      ]);

  Widget _formulario() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const TituloBloque('Escribe a gerencia', apoyo: 'Dudas, sugerencias, bajas o incidencias.'),
        const SizedBox(height: Esp.l),
        TextField(
          controller: asunto,
          maxLength: 80,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(labelText: 'Asunto', prefixIcon: Icon(Icons.subject_rounded)),
        ),
        const SizedBox(height: Esp.s),
        TextField(
          controller: texto,
          maxLength: 2000,
          minLines: 5,
          maxLines: 10,
          keyboardType: TextInputType.multiline,
          decoration: const InputDecoration(labelText: 'Mensaje', alignLabelWithHint: true),
        ),
        const SizedBox(height: Esp.m),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: enviando ? null : _enviar,
            icon: enviando
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.send_rounded, size: 18),
            label: const Text('Enviar'),
          ),
        ),
      ]);
}
