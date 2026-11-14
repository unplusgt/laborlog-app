import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/attendance_screen.dart';
import 'screens/history_screen.dart';
import 'screens/planillas_screen.dart';
import 'screens/trabajadores_screen.dart';
import 'screens/obras_screen.dart';
import 'screens/dispositivos_screen.dart';
import 'screens/kiosco_screen.dart';
import 'screens/kiosco_activar_screen.dart';
import 'services/sync_service.dart';
import 'utils/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.cargar();
  var esKiosco = false;
  try {
    esKiosco = await KioscoService.instancia.estaActivado();
  } catch (_) {
    // Sin almacenamiento seguro disponible: se arranca en el login normal
  }
  runApp(LaborLogApp(rutaInicial: esKiosco ? '/kiosco' : '/login'));
}

class LaborLogApp extends StatelessWidget {
  /// '/kiosco' si este teléfono está activado como kiosco de obra.
  final String rutaInicial;

  const LaborLogApp({super.key, this.rutaInicial = '/login'});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Labor Log',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      initialRoute: rutaInicial,
      routes: {
        '/login': (context) => LoginScreen(),
        '/home': (context) => HomeScreen(),
        '/attendance': (context) => AttendanceScreen(),
        '/history': (context) => HistoryScreen(),
        '/planillas': (context) => PlanillasScreen(),
        '/trabajadores': (context) => TrabajadoresScreen(),
        '/obras': (context) => ObrasScreen(),
        '/dispositivos': (context) => const DispositivosScreen(),
        '/kiosco': (context) => const KioscoScreen(),
        '/kiosco/activar': (context) => const KioscoActivarScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
