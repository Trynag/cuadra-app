/// Constantes públicas de configuración de Firebase compartidas con la versión Web (React + Vite).
///
/// Para habilitar la sincronización en la nube en Android:
/// 1. Ejecuta `dart pub global activate flutterfire_cli`
/// 2. Ejecuta `flutterfire configure --project=rapid-weaver-sk4jk`
/// 3. Sube tu huella SHA-1 de Android en Firebase Console para Google Sign-In.
class FirebaseConstants {
  FirebaseConstants._();

  static const String projectId = 'rapid-weaver-sk4jk';
  static const String firestoreDatabaseId =
      'ai-studio-c4ac59f9-68c5-491d-aed6-227c8d62a952';
}
