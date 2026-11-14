import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../utils/app_config.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_textfield.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _servidorController = TextEditingController(text: AppConfig.apiUrl);
  bool _loading = false;
  String? _error;

  void _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    await AppConfig.guardarApiUrl(_servidorController.text);
    final success = await AuthService().login(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );
    setState(() {
      _loading = false;
    });
    if (success) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      setState(() {
        _error = 'Credenciales incorrectas o no hay conexión con ${AppConfig.apiUrl}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _servidorController,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: 'Servidor',
                hintText: 'http://192.168.0.12:8000',
              ),
            ),
            SizedBox(height: 16),
            CustomTextField(label: 'Email', controller: _emailController),
            SizedBox(height: 16),
            CustomTextField(label: 'Contraseña', controller: _passwordController, obscureText: true),
            SizedBox(height: 24),
            if (_loading) CircularProgressIndicator(),
            if (_error != null) ...[
              Text(_error!, style: TextStyle(color: Colors.red)),
              SizedBox(height: 8),
            ],
            CustomButton(text: 'Iniciar sesión', onPressed: _loading ? null : () => _login()),
            SizedBox(height: 24),
            TextButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/kiosco/activar'),
              icon: Icon(Icons.phonelink_lock),
              label: Text('Usar este teléfono como kiosco de obra'),
            ),
          ],
        ),
      ),
    );
  }
}
