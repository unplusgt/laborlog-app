import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Almacenamiento clave-valor del teléfono. Se abstrae para poder probar la
/// cola offline sin plugins nativos.
abstract class AlmacenClaveValor {
  Future<String?> leer(String clave);
  Future<void> escribir(String clave, String valor);
  Future<void> borrar(String clave);
}

/// Datos no secretos (cola de marcajes, catálogo del kiosco).
class AlmacenPreferencias implements AlmacenClaveValor {
  @override
  Future<String?> leer(String clave) async =>
      (await SharedPreferences.getInstance()).getString(clave);

  @override
  Future<void> escribir(String clave, String valor) async {
    await (await SharedPreferences.getInstance()).setString(clave, valor);
  }

  @override
  Future<void> borrar(String clave) async {
    await (await SharedPreferences.getInstance()).remove(clave);
  }
}

/// Secretos (token del dispositivo): Android Keystore / iOS Keychain.
class AlmacenSeguro implements AlmacenClaveValor {
  static const _storage = FlutterSecureStorage();

  @override
  Future<String?> leer(String clave) => _storage.read(key: clave);

  @override
  Future<void> escribir(String clave, String valor) =>
      _storage.write(key: clave, value: valor);

  @override
  Future<void> borrar(String clave) => _storage.delete(key: clave);
}

/// Para pruebas.
class AlmacenMemoria implements AlmacenClaveValor {
  final Map<String, String> datos = {};

  @override
  Future<String?> leer(String clave) async => datos[clave];

  @override
  Future<void> escribir(String clave, String valor) async => datos[clave] = valor;

  @override
  Future<void> borrar(String clave) async => datos.remove(clave);
}
