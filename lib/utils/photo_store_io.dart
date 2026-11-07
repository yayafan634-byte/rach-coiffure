import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as pth;
import 'package:path_provider/path_provider.dart';

Future<String> savePickedPhoto(XFile picked) async {
  final dir = await getApplicationDocumentsDirectory();
  final dossier = Directory('${dir.path}${Platform.pathSeparator}photos');
  if (!await dossier.exists()) {
    await dossier.create(recursive: true);
  }
  final nomFichier =
      '${DateTime.now().millisecondsSinceEpoch}${pth.extension(picked.path)}';
  final cible = File('${dossier.path}${Platform.pathSeparator}$nomFichier');
  await File(picked.path).copy(cible.path);
  return cible.path;
}

Future<void> deletePhoto(String? chemin) async {
  if (chemin == null || chemin.isEmpty || chemin.startsWith('data:')) return;
  try {
    final fichier = File(chemin);
    if (await fichier.exists()) await fichier.delete();
  } catch (_) {}
}
