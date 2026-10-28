import 'dart:convert';
import 'package:flutter/material.dart';

ImageProvider? photoImageProvider(String? path) {
  if (path == null || !path.startsWith('data:')) return null;
  final virgule = path.indexOf(',');
  if (virgule < 0) return null;
  try {
    return MemoryImage(base64Decode(path.substring(virgule + 1)));
  } catch (_) {
    return null;
  }
}
