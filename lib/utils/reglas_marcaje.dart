/// Reglas de marcaje compartidas con el servidor (laborlog_backend/marcajes.py).
///
/// Un turno (incluido nocturno) dura como máximo 20 h: si la última marca es una
/// ENTRADA de hace menos de 20 h, lo siguiente es SALIDA; si no, ENTRADA.
const Duration ventanaTurno = Duration(hours: 20);

String tipoSiguiente({
  String? ultimoTipo,
  DateTime? ultimoEn,
  required DateTime ahora,
}) {
  if (ultimoTipo == 'entrada' &&
      ultimoEn != null &&
      ahora.difference(ultimoEn) < ventanaTurno) {
    return 'salida';
  }
  return 'entrada';
}
