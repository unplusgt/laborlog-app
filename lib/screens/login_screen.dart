import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_textfield.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;

  void _login() async {
    print('🚀 _login() called');
    print('📧 Email from controller: "${_emailController.text.trim()}"');
    print('🔒 Password length: ${_passwordController.text.trim().length}');
    
    setState(() {
      _loading = true;
      _error = null;
    });
    final success = await AuthService().login(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );
    print('📊 Login result: $success');
    
    setState(() {
      _loading = false;
    });
    if (success) {
      print('✅ Navigating to home...');
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      print('❌ Login failed, showing error');
      setState(() {
        _error = 'Credenciales incorrectas o error de conexión';
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
          ],
        ),
      ),
    );
  }
}
