// Fechas en español como en los bocetos: "5 oct · 10:15", "jueves 8 de octubre".
const _mesesCortos = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
const _meses = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];
const _dias = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];

String fechaCorta(DateTime f) => '${f.day} ${_mesesCortos[f.month - 1]}';

String fechaHora(DateTime f) => '${fechaCorta(f)} · ${f.hour.toString().padLeft(2, '0')}:${f.minute.toString().padLeft(2, '0')}';

String diaSemana(DateTime f) => _dias[f.weekday - 1];

// "jueves 8 de octubre"; con [corta], "jueves 8".
String fechaLarga(DateTime f, {bool corta = false}) => corta ? '${diaSemana(f)} ${f.day}' : '${diaSemana(f)} ${f.day} de ${_meses[f.month - 1]}';

// Días completos que faltan para [f] (0 si ya es hoy o ya pasó).
int diasHasta(DateTime f, {DateTime? hoy}) {
  final ahora = hoy ?? DateTime.now();
  final a = DateTime(ahora.year, ahora.month, ahora.day);
  final b = DateTime(f.year, f.month, f.day);
  final d = b.difference(a).inDays;
  return d < 0 ? 0 : d;
}
