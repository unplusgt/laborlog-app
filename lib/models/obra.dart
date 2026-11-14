class Obra {
  final int id;
  final String nombre;
  final String? lat;
  final String? lng;
  final int? radioMetros;

  Obra({
    required this.id,
    required this.nombre,
    this.lat,
    this.lng,
    this.radioMetros,
  });

  factory Obra.fromJson(Map<String, dynamic> json) {
    return Obra(
      id: json['id'],
      nombre: json['nombre'],
      lat: json['lat'],
      lng: json['lng'],
      radioMetros: json['radio_metros'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'lat': lat,
      'lng': lng,
      'radio_metros': radioMetros,
    };
  }

  // Helper para obtener coordenadas como double
  double? get latitude => lat != null ? double.tryParse(lat!) : null;
  double? get longitude => lng != null ? double.tryParse(lng!) : null;
}