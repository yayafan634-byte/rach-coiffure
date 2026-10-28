import 'package:intl/intl.dart';

String construireCsv({
  required List<String> entetes,
  required List<List<dynamic>> lignes,
}) {
  const sep = ';';
  final buffer = StringBuffer();
  buffer.writeln(entetes.join(sep));
  for (final l in lignes) {
    buffer.writeln(l
        .map((e) => e == null ? '' : '"${e.toString().replaceAll('"', '""')}"')
        .join(sep));
  }
  return buffer.toString();
}

String nomFichierCsv(String nomFichier) =>
    '${nomFichier}_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv';
