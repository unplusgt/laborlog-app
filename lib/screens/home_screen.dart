import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../models/user.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  UsuarioAdmin? _currentUser;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() async {
    setState(() {
      _currentUser = AuthService.currentUser;
      _loading = false;
    });
  }

  void _logout() async {
    await AuthService().logout();
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text('Labor Log')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Labor Log'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Información del usuario
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bienvenido',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    SizedBox(height: 8),
                    if (_currentUser != null) ...[
                      Text('Usuario: ${_currentUser!.email}'),
                      if (_currentUser!.rol != null)
                        Text('Rol: ${_currentUser!.rol}'),
                    ],
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 24),
            
            // Opciones principales
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _buildMenuCard(
                    'Registrar\nAsistencia',
                    Icons.access_time,
                    Colors.green,
                    () async {
                      Navigator.pushNamed(context, '/attendance');
                    },
                  ),
                  _buildMenuCard(
                    'Ver\nHistorial',
                    Icons.history,
                    Colors.blue,
                    () => Navigator.pushNamed(context, '/history'),
                  ),
                  _buildMenuCard(
                    'Trabajadores',
                    Icons.people,
                    Colors.orange,
                    () => Navigator.pushNamed(context, '/trabajadores'),
                  ),
                  _buildMenuCard(
                    'Obras',
                    Icons.business,
                    Colors.purple,
                    () => Navigator.pushNamed(context, '/obras'),
                  ),
                  if (AuthService.isAdmin)
                    _buildMenuCard(
                      'Dispositivos\n(kiosco)',
                      Icons.phone_android,
                      Colors.teal,
                      () => Navigator.pushNamed(context, '/dispositivos'),
                    ),
                ],
              ),
            ),
            
            SizedBox(height: 16),
            
            // Widget de Generar Planilla (solo administradores; el backend también lo exige)
            if (AuthService.isAdmin) _buildPlanillaWidgetCompleto(),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: color),
              SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlanillaWidgetCompleto() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.deepPurple,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withOpacity(0.3),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icono
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.receipt_long,
              size: 32,
              color: Colors.white,
            ),
          ),
          
          SizedBox(width: 16),
          
          // Contenido
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Generar Planilla',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Calcula horas trabajadas y genera reportes PDF/Excel',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          
          SizedBox(width: 16),
          
          // Botón
          ElevatedButton(
            onPressed: () => Navigator.pushNamed(context, '/planillas'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.deepPurple,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Abrir',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
