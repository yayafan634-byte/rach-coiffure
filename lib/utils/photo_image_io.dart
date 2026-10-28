import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';

ImageProvider? photoImageProvider(String? path) {
  if (path == null || path.isEmpty) return null;
  if (path.startsWith('data:')) {
    final virgule = path.indexOf(',');
    if (virgule < 0) return null;
    try {
      return MemoryImage(base64Decode(path.substring(virgule + 1)));
    } catch (_) {
      return null;
    }
  }
  if (!File(path).existsSync()) return null;
  return FileImage(File(path));
}
