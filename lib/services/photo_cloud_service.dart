import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as pth;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'cloud_sync.dart';

class PhotoCloudService {
  PhotoCloudService._();

  static const String _bucket = 'photos';
  static const String _marqueur = '/storage/v1/object/public/$_bucket/';

  static Future<String?> envoyer(XFile picked) async {
    await CloudSync.instance.init();
    final client = CloudSync.instance.client;
    if (client == null) return null;
    try {
      final dire = picked.name.isNotEmpty ? picked.name : picked.path;
      final extension = pth.extension(dire).isEmpty
          ? '.jpg'
          : pth.extension(dire).toLowerCase();
      final nom =
          'perruques/${DateTime.now().millisecondsSinceEpoch}$extension';
      final bytes = await picked.readAsBytes();
      await client.storage.from(_bucket).uploadBinary(
            nom,
            bytes,
            fileOptions: FileOptions(
              contentType: picked.mimeType ?? 'image/jpeg',
              upsert: true,
            ),
          );
      return client.storage.from(_bucket).getPublicUrl(nom);
    } catch (e) {
      debugPrint('PhotoCloudService envoyer: $e');
      return null;
    }
  }

  static bool estPhotoCloud(String? chemin) =>
      chemin != null && chemin.contains(_marqueur);

  static Future<void> supprimer(String? chemin) async {
    if (!estPhotoCloud(chemin)) return;
    final client = CloudSync.instance.client;
    if (client == null) return;
    try {
      final index = chemin!.indexOf(_marqueur);
      final nom = chemin.substring(index + _marqueur.length);
      if (nom.isEmpty) return;
      await client.storage.from(_bucket).remove([nom]);
    } catch (e) {
      debugPrint('PhotoCloudService supprimer: $e');
    }
  }
}
