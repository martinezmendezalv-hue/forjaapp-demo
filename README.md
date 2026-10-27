# ForjaApp · demo

Demo de escritorio de **ForjaApp**, el proyecto de 2.º de DAM (IES Brianda de Mendoza) para **Forja Training Club**, un gimnasio independiente de Guadalajara (empresa ficticia).

La idea de negocio: sustituir el WhatsApp, el Excel, el PC de las tarjetas y la hoja de firmas por un sistema sencillo de **reservas de clases, control de accesos con QR y fichajes del personal**.

## Descargar y probar

1. Ve a **Releases** → `demo`.
2. Descarga `ForjaApp-Demo-Setup.exe` e instálalo (no pide permisos de administrador).
   Si prefieres no instalar nada, descarga `ForjaApp-Demo-portable.zip`, descomprímelo y abre `forja_app_demo.exe`.
3. Windows puede avisar con SmartScreen porque el ejecutable no está firmado: *Más información → Ejecutar de todas formas*.

Todo funciona sin Internet y con datos de ejemplo: no hay servidor ni datos reales.

## Qué se puede probar

| Pantalla | Qué enseña |
|---|---|
| **App del socio** | Clases de hoy, reservar y cancelar, lista de espera con aviso automático, QR de entrada que cambia cada 30 s, socio bloqueado por ausencias |
| **Recepción** | Ocupación de las clases, socios que llevan 21 días sin venir, últimas entradas, alta de socio |
| **Punto de acceso** | La tablet de la entrada: QR válido, cuota pendiente, captura de pantalla caducada y entrada manual sin Internet |
| **Fichajes** | Entrada, pausa y salida del personal, correcciones que no borran el original y exportación CSV para la inspección |

Prueba recomendada: en *App del socio* entra como **Marcos Herrero**, cancela el ciclo de las 19:00 y vuelve a **Lucía Gómez**: la plaza ha pasado a ella y tiene un aviso.

## Cómo está hecha

- **Flutter 3.27** (Dart), el mismo framework que usaría la app real del socio en Android e iOS.
- El paquete `qr_flutter` dibuja el QR.
- **GitHub Actions** compila la versión de Windows y crea el instalador con **Inno Setup** en cada cambio (ver `.github/workflows/windows.yml`).

En el proyecto real, los datos vendrían de una API REST en Java 21 + Spring Boot 3 con PostgreSQL; en la demo todo vive en memoria (`lib/data/store.dart`).

## Compilar en tu PC

Necesitas Flutter y Visual Studio con «Desarrollo para el escritorio con C++».

```
flutter create --platforms=windows --project-name forja_app_demo .
flutter run -d windows
```

---
Álvaro Martínez · Módulo de Proyecto · 2.º DAM · curso 2026/27
