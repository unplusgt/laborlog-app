import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/kiosco.dart';
import '../rostro/comparacion.dart';
import '../rostro/escaner_rostro.dart';
import '../rostro/servicio_rostro.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import '../services/sync_service.dart';
import '../utils/geo.dart';
import '../utils/reglas_marcaje.dart';
import 'registro_rostro_screen.dart';

/// Pantalla del teléfono instalado en la obra. Los trabajadores buscan su nombre y
/// marcan; el marcaje se guarda en el teléfono y se envía cuando hay conexión.
class KioscoScreen extends StatefulWidget {
  const KioscoScreen({super.key});

  @override
  State<KioscoScreen> createState() => _KioscoScreenState();
}

class _KioscoScreenState extends State<KioscoScreen> with WidgetsBindingObserver {
  static const _intervaloSync = Duration(minutes: 2);

  final KioscoService _svc = KioscoService.instancia;
  final _busqueda = TextEditingController();

  KioscoConfig? _config;
  Map<String, ({String tipo, DateTime en})> _ultimos = {};
  int _pendientes = 0;
  int _rechazados = 0;
  bool _sincronizando = false;
  bool? _enLinea;
  DateTime? _ultimaSync;
  DateTime _ahora = DateTime.now();
  bool _marcando = false;
  Timer? _timerSync;

  /// Última captura que no se reconoció: si la persona luego busca su nombre, la foto
  /// va como evidencia (el servidor lo deja en conflicto para revisión).
  CapturaRostro? _capturaSinReconocer;
  Timer? _timerReloj;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _busqueda.addListener(() => setState(() {}));
    _cargar();
    _timerSync = Timer.periodic(_intervaloSync, (_) => _sincronizar());
    _timerReloj = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(() => _ahora = DateTime.now());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timerSync?.cancel();
    _timerReloj?.cancel();
    _busqueda.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _sincronizar();
  }

  Future<void> _cargar() async {
    final config = await _svc.configGuardada();
    if (!mounted) return;
    if (config == null) {
      Navigator.pushNamedAndRemoveUntil(context, '/kiosco/activar', (_) => false);
      return;
    }
    setState(() => _config = config);
    await _refrescarEstado();
    await _sincronizar();
  }

  Future<void> _refrescarEstado() async {
    final config = await _svc.configGuardada() ?? _config;
    if (config == null) return;
    final ultimos = await _svc.ultimosMarcajes(config);
    final pendientes = await _svc.cantidadPendientes();
    final rechazados = (await _svc.rechazados()).length;
    if (!mounted) return;
    setState(() {
      _config = config;
      _ultimos = ultimos;
      _pendientes = pendientes;
      _rechazados = rechazados;
    });
  }

  Future<void> _sincronizar({bool manual = false}) async {
    if (_sincronizando || _config == null) return;
    setState(() => _sincronizando = true);
    try {
      final r = await _svc.sincronizar();
      if (!mounted) return;
      setState(() {
        _enLinea = !r.sinConexion;
        if (!r.sinConexion) _ultimaSync = DateTime.now();
      });
      if (r.rechazados.isNotEmpty) {
        _aviso('${r.rechazados.length} marcaje(s) rechazados por el servidor. Revisa "Rechazados".',
            color: Colors.orange.shade800);
      } else if (manual) {
        _aviso(r.sinConexion
            ? 'Sin conexión. Los marcajes quedan guardados en el teléfono.'
            : 'Sincronizado. Pendientes: ${r.pendientes}');
      }
    } on DispositivoNoAutorizado catch (e) {
      if (mounted) _dispositivoNoAutorizado(e.message);
    } catch (e) {
      if (mounted && manual) _aviso('Error al sincronizar: $e', color: Colors.red);
    } finally {
      if (mounted) setState(() => _sincronizando = false);
      await _refrescarEstado();
    }
  }

  void _dispositivoNoAutorizado(String mensaje) {
    _timerSync?.cancel();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Dispositivo no autorizado'),
        content: Text(
          '$mensaje.\n\nEl token de este teléfono fue cambiado o el dispositivo fue desactivado. '
          'Pide al administrador un token nuevo. Los marcajes pendientes ($_pendientes) se conservan.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pushNamedAndRemoveUntil(ctx, '/kiosco/activar', (_) => false),
            child: const Text('Ingresar token nuevo'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- marcar
  String _tipoPara(KioscoTrabajador t) {
    final u = _ultimos[t.id];
    return tipoSiguiente(ultimoTipo: u?.tipo, ultimoEn: u?.en, ahora: DateTime.now().toUtc());
  }

  Future<void> _abrirTrabajador(KioscoTrabajador t, {CapturaRostro? captura, double? similitud}) async {
    final tipo = _tipoPara(t);
    final reconocido = captura != null && similitud != null;
    final otro = tipo == 'entrada' ? 'salida' : 'entrada';
    final ultimo = _ultimos[t.id];
    final elegido = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (reconocido)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(radius: 36, backgroundImage: MemoryImage(captura.jpeg)),
                      const SizedBox(width: 12),
                      const Icon(Icons.verified, color: Colors.green),
                      const Text(' Reconocido', style: TextStyle(color: Colors.green)),
                    ],
                  ),
                ),
              Text(t.nombre, style: Theme.of(ctx).textTheme.headlineSmall, textAlign: TextAlign.center),
              if (ultimo != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Último: ${ultimo.tipo.toUpperCase()} ${_hora(ultimo.en)}',
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 20),
              SizedBox(
                height: 64,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: _color(tipo)),
                  onPressed: () => Navigator.pop(ctx, tipo),
                  icon: Icon(tipo == 'entrada' ? Icons.login : Icons.logout, size: 28),
                  label: Text('Marcar ${tipo.toUpperCase()}', style: const TextStyle(fontSize: 22)),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(ctx, otro),
                child: Text('No es correcto: marcar ${otro.toUpperCase()}'),
              ),
              if (reconocido)
                TextButton(
                  onPressed: () => Navigator.pop(ctx, 'no_soy'),
                  child: const Text('No soy yo', style: TextStyle(color: Colors.red)),
                ),
            ],
          ),
        ),
      ),
    );
    if (elegido == 'no_soy') {
      _capturaSinReconocer = captura;
      _aviso('Busca tu nombre en la lista para marcar.');
      return;
    }
    if (elegido == null) return;
    if (reconocido) {
      await _marcar(t, elegido, captura: captura, similitud: similitud);
    } else {
      // Marcaje manual: si hace poco la cámara no lo reconoció, se adjunta esa foto
      final reciente = _capturaSinReconocer != null &&
          DateTime.now().difference(_capturaSinReconocer!.en) < const Duration(minutes: 2);
      await _marcar(t, elegido, captura: reciente ? _capturaSinReconocer : null);
      _capturaSinReconocer = null;
    }
  }

  /// La persona mira la cámara; la app la identifica sin conexión entre los
  /// trabajadores con rostro registrado.
  Future<void> _marcarConRostro() async {
    final config = _config;
    if (config == null) return;
    final candidatos = <Candidato>[];
    for (final t in config.trabajadores) {
      if (t.huellaB64 == null) continue;
      try {
        candidatos.add(Candidato(t.id, t.nombre, huellaDeBase64(t.huellaB64!)));
      } catch (_) {}
    }
    if (candidatos.isEmpty) {
      _error('Aún no hay rostros registrados. Un supervisor puede registrarlos en el menú ⋮ > Registrar rostros.');
      return;
    }
    final capturas = await EscanerRostroScreen.abrir(context, titulo: 'Marcar con mi rostro');
    if (capturas == null || capturas.isEmpty || !mounted) return;
    final captura = capturas.first;
    final r = identificar(captura.huella, candidatos);
    if (r.reconocido) {
      final t = config.trabajadores.firstWhere((x) => x.id == r.candidato!.id);
      await _abrirTrabajador(t, captura: captura, similitud: r.mejor);
      return;
    }
    _capturaSinReconocer = captura;
    if (!mounted) return;
    final accion = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.help_outline, size: 48),
        title: const Text('No te reconocí'),
        content: const Text('Intenta de nuevo con buena luz y la cara completa en el óvalo, '
            'o busca tu nombre en la lista.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, 'nombre'), child: const Text('Buscar mi nombre')),
          FilledButton(onPressed: () => Navigator.pop(ctx, 'otra'), child: const Text('Intentar de nuevo')),
        ],
      ),
    );
    if (accion == 'otra') await _marcarConRostro();
  }

  Future<void> _marcar(KioscoTrabajador t, String tipo, {CapturaRostro? captura, double? similitud}) async {
    final obra = _config?.obra;
    if (obra == null) {
      _error('Este teléfono no tiene obra asignada. Pide al administrador que la asigne.');
      return;
    }
    if (!obra.tieneGeocerca) {
      _error('La obra "${obra.nombre}" no tiene ubicación y radio configurados.');
      return;
    }
    setState(() => _marcando = true);
    try {
      final u = await LocationService.obtenerUbicacion();
      if (u.simulada) {
        _error('Se detectó una ubicación falsa (GPS simulado). Desactiva la app de ubicación falsa.');
        return;
      }
      final distancia = distanciaMetros(u.lat, u.lng, obra.lat!, obra.lng!);
      if (distancia > obra.radioMetros!) {
        _error('Estás a ${distancia.toStringAsFixed(0)} m de la obra (máximo ${obra.radioMetros} m). '
            'Acércate a la obra e intenta de nuevo.'
            '${u.precisionMetros > 30 ? '\n\nLa señal GPS es débil (±${u.precisionMetros.toStringAsFixed(0)} m); sal a cielo abierto.' : ''}');
        return;
      }
      final id = const Uuid().v4();
      final fotoRef = captura != null ? await _svc.guardarFoto(id, captura.jpeg) : null;
      final porRostro = captura != null && similitud != null;
      final marcaje = MarcajePendiente(
        id: id,
        trabajadorId: t.id,
        trabajadorNombre: t.nombre,
        obraId: obra.id,
        tipo: tipo,
        capturadoEn: DateTime.now().toUtc(),
        lat: u.lat,
        lng: u.lng,
        precisionMetros: u.precisionMetros,
        ubicacionSimulada: u.simulada,
        metodo: porRostro ? 'rostro' : 'manual',
        similitud: porRostro ? similitud : null,
        pruebaVida: captura?.pruebaVida,
        fotoRef: fotoRef,
      );
      await _svc.encolar(marcaje);
      await _refrescarEstado();
      _busqueda.clear();
      if (mounted) await _confirmacion(t, tipo, marcaje.capturadoEn);
      unawaited(_sincronizar());
    } on LocationException catch (e) {
      _error(e.message);
    } catch (e) {
      _error('No se pudo registrar: $e');
    } finally {
      if (mounted) setState(() => _marcando = false);
    }
  }

  Future<void> _confirmacion(KioscoTrabajador t, String tipo, DateTime en) async {
    final nav = Navigator.of(context);
    var abierto = true;
    Timer(const Duration(seconds: 3), () {
      if (abierto && nav.canPop()) nav.pop();
    });
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.check_circle, color: _color(tipo), size: 72),
        title: Text('${tipo.toUpperCase()} registrada'),
        content: Text('${t.nombre}\n${_hora(en)}',
            textAlign: TextAlign.center, style: const TextStyle(fontSize: 20)),
      ),
    );
    abierto = false;
  }

  void _error(String mensaje) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.error_outline, color: Colors.red, size: 48),
        title: const Text('No se registró el marcaje'),
        content: Text(mensaje),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Entendido'))],
      ),
    );
  }

  void _aviso(String mensaje, {Color? color}) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensaje), backgroundColor: color));
  }

  // ---------------------------------------------------------------- menú
  Future<void> _verRechazados() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const _RechazadosScreen()));
    await _refrescarEstado();
  }

  /// Pide usuario y contraseña de un supervisor/administrador. Deja la sesión abierta
  /// (quien llama debe cerrarla) y devuelve true si se pudo entrar con ese rol.
  Future<bool> _loginSupervisor(String titulo, {bool soloAdmin = false}) async {
    final email = TextEditingController();
    final password = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titulo),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(soloAdmin ? 'Requiere un jefe o super admin de ${_config?.empresaNombre ?? 'la empresa'}.' : 'Requiere un supervisor, jefe o super admin.'),
            TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Usuario o correo')),
            TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Contraseña')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Entrar')),
        ],
      ),
    );
    if (ok != true) return false;
    final auth = AuthService();
    final entro = await auth.login(_config?.empresaCodigo ?? '', email.text.trim(), password.text);
    final rol = AuthService.currentUser?.rol;
    final permitido = soloAdmin ? AuthService.puedeGestionar : const ['supervisor', 'jefe', 'superadmin'].contains(rol);
    if (!entro || !permitido) {
      await auth.logout();
      _error(entro ? 'Tu usuario no tiene permiso para esto.' : 'Credenciales incorrectas o sin conexión.');
      return false;
    }
    return true;
  }

  Future<void> _registrarRostros() async {
    if (kIsWeb) {
      _error('El registro de rostros se hace desde la app del celular.');
      return;
    }
    if (!await _loginSupervisor('Registrar rostros')) return;
    if (!mounted) return;
    try {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const _RegistroRostrosKiosco()));
    } finally {
      await AuthService().logout();
      await _refrescarEstado();
    }
  }

  Future<void> _salirDelKiosco() async {
    final email = TextEditingController();
    final password = TextEditingController();
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Salir del modo kiosco'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Requiere un jefe o super admin de la empresa.'),
            if (_pendientes > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Atención: hay $_pendientes marcajes sin enviar y se perderán.',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Usuario o correo')),
            TextField(
              controller: password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Contraseña'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Salir')),
        ],
      ),
    );
    if (confirmado != true) return;
    final auth = AuthService();
    final ok = await auth.login(_config?.empresaCodigo ?? '', email.text.trim(), password.text);
    if (!ok || !AuthService.puedeGestionar) {
      await auth.logout();
      _error(ok ? 'Solo un jefe o super admin puede salir del modo kiosco.' : 'Credenciales incorrectas o sin conexión.');
      return;
    }
    await auth.logout();
    await _svc.desactivar();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  // ---------------------------------------------------------------- UI
  static Color _color(String tipo) => tipo == 'entrada' ? Colors.green.shade700 : Colors.orange.shade800;

  static String _hora(DateTime t) {
    final l = t.toLocal();
    final hoy = DateTime.now();
    final hh = '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
    if (l.year == hoy.year && l.month == hoy.month && l.day == hoy.day) return hh;
    return '${l.day.toString().padLeft(2, '0')}/${l.month.toString().padLeft(2, '0')} $hh';
  }

  Widget _estadoSync() {
    final IconData icono;
    final Color color;
    if (_sincronizando) {
      icono = Icons.sync;
      color = Colors.white;
    } else if (_enLinea == false) {
      icono = Icons.cloud_off;
      color = Colors.amberAccent;
    } else if (_pendientes > 0) {
      icono = Icons.cloud_upload;
      color = Colors.white;
    } else {
      icono = Icons.cloud_done;
      color = Colors.lightGreenAccent;
    }
    return TextButton.icon(
      onPressed: _sincronizando ? null : () => _sincronizar(manual: true),
      icon: Icon(icono, color: color),
      label: Text(_pendientes > 0 ? '$_pendientes' : '', style: TextStyle(color: color)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = _config;
    if (config == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final filtro = _busqueda.text.trim().toLowerCase();
    final trabajadores = config.trabajadores
        .where((t) =>
            filtro.isEmpty ||
            t.nombre.toLowerCase().contains(filtro) ||
            (t.codigoEmpresa ?? '').toLowerCase().contains(filtro))
        .toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(config.obra?.nombre ?? 'Sin obra asignada'),
            Text(
              '${_hora(_ahora)} · ${config.empresaNombre}',
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          _estadoSync(),
          PopupMenuButton<String>(
            onSelected: (v) {
              switch (v) {
                case 'sync':
                  _sincronizar(manual: true);
                case 'rechazados':
                  _verRechazados();
                case 'rostros':
                  _registrarRostros();
                case 'salir':
                  _salirDelKiosco();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'sync', child: Text('Sincronizar ahora')),
              PopupMenuItem(value: 'rechazados', child: Text('Rechazados ($_rechazados)')),
              const PopupMenuItem(value: 'rostros', child: Text('Registrar rostros')),
              const PopupMenuItem(value: 'salir', child: Text('Salir del modo kiosco')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (_rechazados > 0)
            MaterialBanner(
              backgroundColor: Colors.orange.shade50,
              content: Text('$_rechazados marcaje(s) rechazados por el servidor'),
              actions: [TextButton(onPressed: _verRechazados, child: const Text('Revisar'))],
            ),
          if (config.obra == null)
            MaterialBanner(
              content: const Text('Este teléfono no tiene obra asignada. El administrador debe asignarla '
                  'en Dispositivos; luego toca Sincronizar.'),
              actions: [TextButton(onPressed: () => _sincronizar(manual: true), child: const Text('Sincronizar'))],
            ),
          if (_enLinea == false)
            Container(
              width: double.infinity,
              color: Colors.amber.shade100,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Text(
                'Sin conexión: los marcajes se guardan en el teléfono'
                '${_ultimaSync != null ? ' · última sincronización ${_hora(_ultimaSync!)}' : ''}',
              ),
            ),
          if (!kIsWeb && config.trabajadores.any((t) => t.tieneRostro))
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: SizedBox(
                width: double.infinity,
                height: 72,
                child: FilledButton.icon(
                  onPressed: _marcando ? null : _marcarConRostro,
                  icon: const Icon(Icons.face_retouching_natural, size: 32),
                  label: const Text('Marcar con mi rostro', style: TextStyle(fontSize: 22)),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _busqueda,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Busca tu nombre o código',
                border: const OutlineInputBorder(),
                suffixIcon: filtro.isEmpty
                    ? null
                    : IconButton(icon: const Icon(Icons.clear), onPressed: _busqueda.clear),
              ),
            ),
          ),
          if (_marcando) const LinearProgressIndicator(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _sincronizar(manual: true),
              child: trabajadores.isEmpty
                  ? ListView(children: const [
                      Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('No hay trabajadores que coincidan', textAlign: TextAlign.center),
                      ),
                    ])
                  : ListView.separated(
                      itemCount: trabajadores.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final t = trabajadores[i];
                        final tipo = _tipoPara(t);
                        final ultimo = _ultimos[t.id];
                        final dentro = tipo == 'salida';
                        return ListTile(
                          enabled: !_marcando,
                          leading: CircleAvatar(
                            backgroundColor: dentro ? Colors.green.shade100 : Colors.grey.shade200,
                            child: Text(t.nombre.isNotEmpty ? t.nombre[0].toUpperCase() : '?'),
                          ),
                          title: Text(t.nombre, style: const TextStyle(fontSize: 18)),
                          subtitle: Text([
                            if (dentro && ultimo != null) 'En obra desde ${_hora(ultimo.en)}' else if (t.codigoEmpresa != null) t.codigoEmpresa!,
                            if (!t.tieneRostro) 'sin rostro',
                          ].join(' · ')),
                          trailing: Chip(
                            label: Text(tipo.toUpperCase(),
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            backgroundColor: _color(tipo),
                          ),
                          onTap: () => _abrirTrabajador(t),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RechazadosScreen extends StatefulWidget {
  const _RechazadosScreen();

  @override
  State<_RechazadosScreen> createState() => _RechazadosScreenState();
}

class _RechazadosScreenState extends State<_RechazadosScreen> {
  List<MarcajePendiente> _items = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final items = await KioscoService.instancia.rechazados();
    if (mounted) setState(() => _items = items);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Marcajes rechazados')),
      body: _items.isEmpty
          ? const Center(child: Text('No hay marcajes rechazados'))
          : ListView.separated(
              itemCount: _items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final m = _items[i];
                return ListTile(
                  title: Text('${m.trabajadorNombre} · ${m.tipo.toUpperCase()} '
                      '${_KioscoScreenState._hora(m.capturadoEn)}'),
                  subtitle: Text(m.error ?? ''),
                  isThreeLine: true,
                  trailing: TextButton(
                    onPressed: () async {
                      await KioscoService.instancia.descartar(m.id);
                      await _cargar();
                    },
                    child: const Text('Descartar'),
                  ),
                );
              },
            ),
    );
  }
}


/// Lista de trabajadores para registrar su rostro desde el kiosco (con sesión de supervisor).
class _RegistroRostrosKiosco extends StatefulWidget {
  const _RegistroRostrosKiosco();

  @override
  State<_RegistroRostrosKiosco> createState() => _RegistroRostrosKioscoState();
}

class _RegistroRostrosKioscoState extends State<_RegistroRostrosKiosco> {
  KioscoConfig? _config;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar({bool descargar = false}) async {
    try {
      final config = descargar
          ? await KioscoService.instancia.actualizarConfig()
          : await KioscoService.instancia.configGuardada();
      if (mounted) setState(() => _config = config);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final trabajadores = _config?.trabajadores ?? [];
    final registrados = trabajadores.where((t) => t.tieneRostro).length;
    return Scaffold(
      appBar: AppBar(title: Text('Registrar rostros ($registrados/${trabajadores.length})')),
      body: _error != null
          ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
          : ListView.separated(
              itemCount: trabajadores.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final t = trabajadores[i];
                return ListTile(
                  leading: Icon(t.tieneRostro ? Icons.verified_user : Icons.face_outlined,
                      color: t.tieneRostro ? Colors.green : Colors.grey),
                  title: Text(t.nombre),
                  subtitle: Text(t.tieneRostro ? 'Rostro registrado' : 'Sin rostro'),
                  trailing: Text(t.tieneRostro ? 'Reemplazar' : 'Registrar'),
                  onTap: () async {
                    final ok = await RegistroRostroScreen.abrir(
                      context,
                      trabajadorId: t.id,
                      nombre: t.nombre,
                      yaRegistrado: t.tieneRostro,
                    );
                    if (ok) await _cargar(descargar: true);
                  },
                );
              },
            ),
    );
  }
}
