import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'export_csv_common.dart';

/// Génère le CSV et déclenche son téléchargement dans le navigateur.
Future<String> exporterCsv({
  required String nomFichier,
  required List<String> entetes,
  required List<List<dynamic>> lignes,
}) async {
  final contenu = construireCsv(entetes: entetes, lignes: lignes);
  final nom = nomFichierCsv(nomFichier);
  final parties = <JSAny>['\uFEFF$contenu'.toJS].toJS;
  final blob = web.Blob(
    parties,
    web.BlobPropertyBag(type: 'text/csv;charset=utf-8'),
  );
  final url = web.URL.createObjectURL(blob);
  final ancre = web.HTMLAnchorElement()
    ..href = url
    ..download = nom;
  web.document.body?.append(ancre);
  ancre.click();
  ancre.remove();
  web.URL.revokeObjectURL(url);
  return nom;
}
