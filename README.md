# ForjaApp · demo

Demo de **ForjaApp**, el proyecto de 2.º de DAM (IES Brianda de Mendoza) para **Forja Training Club**, un gimnasio independiente de Guadalajara (empresa ficticia).

La idea de negocio: sustituir el WhatsApp, el Excel, el PC de las tarjetas y la hoja de firmas por un sistema sencillo de **reservas de clases, control de accesos con QR y fichajes del personal**.

![App del socio](docs/capturas/socio.png)

## Pruébala

| | Enlace |
|---|---|
| **En el navegador** (sin instalar nada) | **https://martinezmendezalv-hue.github.io/forjaapp-demo/** |
| **Windows: instalador** | [ForjaApp-Demo-Setup.exe](https://github.com/martinezmendezalv-hue/forjaapp-demo/releases/download/demo/ForjaApp-Demo-Setup.exe) |
| **Windows: portable** (sin instalar) | [ForjaApp-Demo-portable.zip](https://github.com/martinezmendezalv-hue/forjaapp-demo/releases/download/demo/ForjaApp-Demo-portable.zip) |
| Todas las descargas | [Releases → demo](https://github.com/martinezmendezalv-hue/forjaapp-demo/releases/tag/demo) |

> [!WARNING]
> **Windows SmartScreen** avisará de que la aplicación es de un editor desconocido, porque el `.exe` no está firmado digitalmente (un certificado cuesta dinero y esto es un proyecto de clase).
> Pulsa **Más información → Ejecutar de todas formas**. El instalador no pide permisos de administrador.

Para la versión portable: descomprime el zip y abre `forja_app_demo.exe`.

Todo funciona sin Internet y con datos de ejemplo: no hay servidor ni datos reales. Las clases son las de **hoy**, así que lo que puedes reservar depende de la hora a la que abras la demo.

## Las cuatro pantallas

| | |
|---|---|
| ![Recepción](docs/capturas/recepcion.png) | ![Fichajes](docs/capturas/fichajes.png) |
| **Recepción**: ocupación de las clases, socios en riesgo de baja, últimas entradas y alta de socio. | **Fichajes**: entrada, pausa y salida del personal, correcciones que no borran el original y exportación CSV para la inspección. |
| ![Punto de acceso](docs/capturas/acceso.png) | ![Acceso concedido](docs/capturas/acceso-concedido.png) |
| **Punto de acceso**: la tablet del torno en reposo… | …y cuando el QR es válido. En rojo si la cuota está pendiente, en ámbar si el QR es una captura antigua. |

<p align="center"><img src="docs/capturas/qr.png" width="300" alt="Pase de entrada con QR y cuenta atrás"></p>

**App del socio** (dentro de un marco de móvil): clases de hoy con monitor, plazas y estado, reservas, lista de espera con ascenso automático, avisos y el **pase QR a pantalla completa que cambia cada 30 segundos**.

### Prueba recomendada

1. En *App del socio*, pulsa **Entrar como Marcos** y cancela su ciclo de las 19:00.
2. La plaza pasa sola a **Lucía Gómez**, la primera de la lista de espera.
3. Vuelve a Lucía y abre **Avisos**: tiene la plaza confirmada.

Otros casos: **Pablo Ruiz** no puede reservar (3 ausencias este mes), **Raúl Fernández** tiene el recibo devuelto y el torno no le abre, **Javier Moreno** tiene tarifa de sala sin clases dirigidas.

En la web se puede abrir cada sección directamente: [`?seccion=recepcion`](https://martinezmendezalv-hue.github.io/forjaapp-demo/?seccion=recepcion), [`?seccion=acceso`](https://martinezmendezalv-hue.github.io/forjaapp-demo/?seccion=acceso), [`?seccion=fichajes`](https://martinezmendezalv-hue.github.io/forjaapp-demo/?seccion=fichajes).

## Diseño

- **Identidad «acero templado»**: los colores del temple del acero (azul frío, paja y ascua) son también los estados de la app. La barra de ocupación de cada clase «se calienta» de azul a ascua según se llena.
- **Tipografía**: Barlow Condensed para titulares y cifras, Barlow para el texto. Van empaquetadas en `assets/fonts` (licencia SIL OFL).
- **Accesibilidad**: contraste AA en todo el texto, los estados siempre llevan icono además de color, objetivos táctiles de 44 px y etiquetas para lector de pantalla en tarjetas, QR e indicadores.
- Los tokens (colores, espaciado, radios, tipografía, animación) y los componentes compartidos están en `lib/theme.dart`.

## Cómo está hecha

- **Flutter 3.27** (Dart), el mismo framework que usaría la app real del socio en Android e iOS.
- El paquete `qr_flutter` dibuja el QR.
- **GitHub Actions** (`.github/workflows/windows.yml`) compila en cada cambio: la versión de Windows con su instalador de **Inno Setup**, que se publica en la release `demo`, y la versión web, que se publica en **GitHub Pages**.

En el proyecto real, los datos vendrían de una API REST en Java 21 + Spring Boot 3 con PostgreSQL; en la demo todo vive en memoria (`lib/data/store.dart`).

## Compilar en tu PC

Necesitas Flutter 3.27 y, para Windows, Visual Studio con «Desarrollo para el escritorio con C++».

```
flutter create --platforms=windows --org es.forja --project-name forja_app_demo .
flutter test
flutter run -d windows
```

Para la web: `flutter run -d chrome`.

---
Álvaro Martínez · Módulo de Proyecto · 2.º DAM · curso 2026/27
