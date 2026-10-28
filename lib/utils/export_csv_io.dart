import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'export_csv_common.dart';

/// Génère un fichier CSV, le sauvegarde dans le dossier Documents de l'app
/// et propose le partage. Retourne le chemin du fichier.
Future<String> exporterCsv({
  required String nomFichier,
  required List<String> entetes,
  required List<List<dynamic>> lignes,
}) async {
  final contenu = construireCsv(entetes: entetes, lignes: lignes);
  final dir = await getApplicationDocumentsDirectory();
  final nom = nomFichierCsv(nomFichier);
  final fichier = File('${dir.path}${Platform.pathSeparator}$nom');
  // BOM UTF-8 pour ouverture correcte dans Excel
  await fichier.writeAsString('\uFEFF$contenu', flush: true);

  await Share.shareXFiles([XFile(fichier.path)], subject: nomFichier);
  return fichier.path;
}
