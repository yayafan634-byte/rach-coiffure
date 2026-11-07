import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

class SonService {
  SonService._();

  static final SonService instance = SonService._();

  AudioPlayer? _player;

  Future<void> succes() async {
    HapticFeedback.mediumImpact();
    try {
      final player = _player ??= AudioPlayer();
      await player.stop();
      await player.play(AssetSource('sounds/succes.wav'));
    } catch (_) {}
  }
}
