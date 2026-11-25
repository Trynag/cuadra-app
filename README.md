# Cuadra Mobile (Flutter — Android)

Aplicación móvil en **Flutter** de **Cuadra — Finanzas Personales Colombia**, diseñada para compartir el mismo backend de **Firebase Auth y Cloud Firestore** que la versión web (`React + Vite`).

## Características incluidas
- **Disponible real al instante:** Efectivo, Nequi, Davibank Ahorros y NuBank Ahorros con entradas (`+$`) y salidas (`-$`) del mes.
- **Ingresos y trabajos flexibles:** preconfigurado con **UNAD** (mensual) y **Trabajo diario**, con opción de agregar, pausar y reactivar trabajos sin perder el historial.
- **Registro rápido en 2 toques (`QuickEntrySheet`):** Gasto, Ingreso (con fecha y razón), Traslado (Davibank → Nequi sin duplicar) y Abono a deudas.
- **Conciliación automática de traslados Davibank ↔ Nequi** y **simulador de deudas** (Avalancha vs. Bola de nieve para Davibank TC, NuBank TC, Addi y Sistecrédito).
- **Esquema Firestore 100% compatible:** conectado a la base `ai-studio-c4ac59f9-68c5-491d-aed6-227c8d62a952` cumpliendo todas las reglas de `firestore.rules`.

## Cómo inicializar en tu computador (Android)

1. Genera las carpetas nativas de Android dentro de este repo:
   ```bash
   flutter create . --platforms=android --org com.cuadra.app
   flutter pub get
   ```
2. Conecta tu proyecto de Firebase compartido:
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure --project=rapid-weaver-sk4jk
   ```
   Luego importa `firebase_options.dart` en `lib/main.dart` y pasa `options: DefaultFirebaseOptions.currentPlatform` a `Firebase.initializeApp(...)`.
3. Ejecuta las pruebas y corre en tu Android:
   ```bash
   flutter test
   flutter run
   ```
