import 'dart:convert';
import 'package:image_picker/image_picker.dart';

Future<String> savePickedPhoto(XFile picked) async {
  final bytes = await picked.readAsBytes();
  final mime = picked.mimeType ?? 'image/jpeg';
  return 'data:$mime;base64,${base64Encode(bytes)}';
}

Future<void> deletePhoto(String? chemin) async {
  // Les photos web sont encodées en base64 dans la base : rien à supprimer
  // sur le disque, il suffit de retirer la référence.
}
