import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
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

/// Fotos de los marcajes pendientes (no caben bien en shared_preferences).
abstract class AlmacenFotos {
  /// Guarda la foto y devuelve una referencia para guardarla en la cola.
  Future<String> guardar(String id, Uint8List jpeg);
  Future<Uint8List?> leer(String ref);
  Future<void> borrar(String ref);
  Future<void> borrarTodas();
}

/// Archivos en la carpeta privada de la app.
class AlmacenFotosArchivos implements AlmacenFotos {
  Future<Directory> _dir() async {
    final base = await getApplicationSupportDirectory();
    final d = Directory('${base.path}/fotos_marcajes');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  @override
  Future<String> guardar(String id, Uint8List jpeg) async {
    final f = File('${(await _dir()).path}/$id.jpg');
    await f.writeAsBytes(jpeg, flush: true);
    return '$id.jpg';
  }

  @override
  Future<Uint8List?> leer(String ref) async {
    final f = File('${(await _dir()).path}/${ref.split('/').last}');
    return await f.exists() ? f.readAsBytes() : null;
  }

  @override
  Future<void> borrar(String ref) async {
    final f = File('${(await _dir()).path}/${ref.split('/').last}');
    if (await f.exists()) await f.delete();
  }

  @override
  Future<void> borrarTodas() async {
    final d = await _dir();
    if (await d.exists()) await d.delete(recursive: true);
  }
}

/// Para pruebas.
class AlmacenFotosMemoria implements AlmacenFotos {
  final Map<String, Uint8List> fotos = {};

  @override
  Future<String> guardar(String id, Uint8List jpeg) async {
    fotos[id] = jpeg;
    return id;
  }

  @override
  Future<Uint8List?> leer(String ref) async => fotos[ref];

  @override
  Future<void> borrar(String ref) async => fotos.remove(ref);

  @override
  Future<void> borrarTodas() async => fotos.clear();
}
