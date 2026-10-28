/// Planes de cuota, con lo que incluye cada uno (mismo esquema que las
/// cuotas Comfort, Premium y Ultimate de Basic-Fit en España).
class Plan {
  const Plan(this.id, this.nombre, this.precio, this.incluye, {this.destacado = false});
  final String id;
  final String nombre;
  final double precio;
  final List<String> incluye;
  final bool destacado;

  Map<String, Object> toJson() => {
        'id': id,
        'nombre': nombre,
        'precio': precio,
        'periodo': 'cada 4 semanas',
        'incluye': incluye,
        'destacado': destacado,
      };
}

const planes = [
  Plan('comfort', 'Comfort', 24.99, [
    'Acceso ilimitado al club, todos los días',
    'Clases colectivas en el club',
    'App con más de 1.000 entrenamientos y clases en casa',
  ]),
  Plan(
    'premium',
    'Premium',
    29.99,
    [
      'Todo lo de Comfort',
      'Acceso a todos los clubes de la red',
      'Trae a un amigo una vez a la semana',
      'Sillones de masaje sin límite',
    ],
    destacado: true,
  ),
  Plan('ultimate', 'Ultimate', 34.99, [
    'Todo lo de Premium',
    'Trae a un amigo siempre que quieras',
    'Congela tu cuota sin coste',
    'Agua isotónica sin límite',
  ]),
];

Plan? planPorId(String? id) {
  for (final p in planes) {
    if (p.id == id) return p;
  }
  return null;
}
