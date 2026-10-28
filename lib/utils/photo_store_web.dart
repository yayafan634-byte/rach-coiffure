import 'dart:convert';
import 'package:image_picker/image_picker.dart';

Future<String> savePickedPhoto(XFile picked) async {
  final bytes = await picked.readAsBytes();
  final mime = picked.mimeType ?? 'image/jpeg';
  return 'data:$mime;base64,${base64Encode(bytes)}';
}
