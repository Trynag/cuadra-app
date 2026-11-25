import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'screens/home_shell.dart';
import 'state/finance_controller.dart';
import 'theme/cuadra_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_CO', null);

  bool firebaseReady = false;
  try {
    // Una vez ejecutes `flutterfire configure --project=rapid-weaver-sk4jk`,
    // puedes importar `firebase_options.dart` y pasar:
    // `options: DefaultFirebaseOptions.currentPlatform`
    await Firebase.initializeApp();
    firebaseReady = true;
  } catch (_) {
    // Permite ejecutar la app inmediatamente en modo local antes de configurar Firebase en Android.
    firebaseReady = false;
  }

  runApp(CuadraApp(firebaseAvailable: firebaseReady));
}

class CuadraApp extends StatelessWidget {
  const CuadraApp({super.key, required this.firebaseAvailable});

  final bool firebaseAvailable;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => FinanceController(firebaseAvailable: firebaseAvailable),
      child: MaterialApp(
        title: 'Cuadra — Finanzas Personales',
        debugShowCheckedModeBanner: false,
        theme: CuadraTheme.build(),
        home: const HomeShell(),
      ),
    );
  }
}
