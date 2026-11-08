import 'dart:convert';
import 'package:image_picker/image_picker.dart';

import '../services/photo_cloud_service.dart';

Future<String> savePickedPhoto(XFile picked) async {
  final cloud = await PhotoCloudService.envoyer(picked);
  if (cloud != null) return cloud;
  final bytes = await picked.readAsBytes();
  final mime = picked.mimeType ?? 'image/jpeg';
  return 'data:$mime;base64,${base64Encode(bytes)}';
}

Future<void> deletePhoto(String? chemin) async {
  // Les photos locales web sont encodées en base64 : rien à supprimer sur le
  // disque. Les photos cloud sont retirées du bucket Supabase.
  await PhotoCloudService.supprimer(chemin);
}
