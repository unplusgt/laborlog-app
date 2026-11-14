import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/attendance_screen.dart';
import 'screens/history_screen.dart';
import 'screens/planillas_screen.dart';
import 'screens/trabajadores_screen.dart';
import 'screens/obras_screen.dart';

void main() {
  runApp(LaborLogApp());
}

class LaborLogApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Labor Log',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => LoginScreen(),
        '/home': (context) => HomeScreen(),
        '/attendance': (context) => AttendanceScreen(),
        '/history': (context) => HistoryScreen(),
        '/planillas': (context) => PlanillasScreen(),
        '/trabajadores': (context) => TrabajadoresScreen(),
        '/obras': (context) => ObrasScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
