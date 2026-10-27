import 'package:flutter_test/flutter_test.dart';
import 'package:forja_app_demo/data/store.dart';

void main() {
  test('la plaza liberada pasa al primero de la lista de espera', () {
    final store = ForjaStore();
    final ciclo = store.sesion(4);
    expect(ciclo.llena, isTrue);
    expect(ciclo.espera.first, 1);

    store.cancelar(2, 4); // Marcos cancela

    expect(ciclo.reservas.contains(1), isTrue); // Lucía entra
    expect(store.avisos.first.socioId, 1);
    store.dispose();
  });

  test('un QR de la ventana anterior está caducado', () {
    final store = ForjaStore();
    final viejo = store.tokenQr(1, store.ventanaActual() - 1);
    expect(store.validarQr(viejo).resultado, ResultadoAcceso.qrCaducado);
    store.dispose();
  });
}
