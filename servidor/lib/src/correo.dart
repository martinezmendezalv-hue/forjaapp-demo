import 'dart:convert';
import 'dart:io';

/// Envío de correos (por ahora, solo el código para restablecer la contraseña).
abstract class EnvioCorreo {
  Future<void> enviar({required String para, required String asunto, required String texto, required String html});
}

/// Brevo (antes Sendinblue), plan gratuito de 300 correos al día. Va por
/// HTTPS porque el plan gratuito de Render bloquea los puertos de SMTP.
class CorreoBrevo implements EnvioCorreo {
  CorreoBrevo({required this.clave, required this.remitente, this.nombre = 'Forja Training Club'});

  final String clave;
  final String remitente;
  final String nombre;

  @override
  Future<void> enviar({required String para, required String asunto, required String texto, required String html}) async {
    final cliente = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final req = await cliente.postUrl(Uri.parse('https://api.brevo.com/v3/smtp/email'));
      req.headers
        ..set('api-key', clave)
        ..contentType = ContentType.json
        ..set('accept', 'application/json');
      req.add(utf8.encode(jsonEncode({
        'sender': {'name': nombre, 'email': remitente},
        'to': [
          {'email': para}
        ],
        'subject': asunto,
        'textContent': texto,
        'htmlContent': html,
      })));
      final r = await req.close().timeout(const Duration(seconds: 20));
      final cuerpo = await utf8.decodeStream(r);
      if (r.statusCode >= 300) throw HttpException('Brevo respondió ${r.statusCode}: $cuerpo');
    } finally {
      cliente.close();
    }
  }
}

/// Texto del correo con el código de restablecimiento.
({String asunto, String texto, String html}) correoCodigo(String nombre, String codigo, int minutos) {
  final escapado = const HtmlEscape().convert(nombre);
  return (
    asunto: 'Tu código para restablecer la contraseña de ForjaApp: $codigo',
    texto: 'Hola, $nombre:\n\n'
        'Tu código para crear una contraseña nueva en ForjaApp es: $codigo\n\n'
        'Caduca en $minutos minutos y solo sirve una vez. Si no lo has pedido tú, '
        'ignora este correo: tu contraseña no ha cambiado.\n\nForja Training Club',
    html: '<div style="font-family:Arial,sans-serif;max-width:480px;margin:auto;color:#222">'
        '<h2 style="color:#C2410C">Forja Training Club</h2>'
        '<p>Hola, $escapado:</p>'
        '<p>Tu código para crear una contraseña nueva en ForjaApp es:</p>'
        '<p style="font-size:32px;font-weight:bold;letter-spacing:6px;background:#F4F4F5;'
        'padding:12px 16px;text-align:center;border-radius:8px">$codigo</p>'
        '<p>Caduca en $minutos minutos y solo sirve una vez.</p>'
        '<p style="color:#666;font-size:13px">Si no lo has pedido tú, ignora este correo: '
        'tu contraseña no ha cambiado.</p></div>',
  );
}
