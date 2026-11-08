import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

class SonService {
  SonService._();

  static final SonService instance = SonService._();

  static final _source = AssetSource('sounds/succes.wav');

  AudioPlayer? _player;
  bool _pret = false;

  Future<void> initialiser() async {
    try {
      final player = _player ??= AudioPlayer();
      await player.setReleaseMode(ReleaseMode.stop);
      await player.setSource(_source);
      _pret = true;
    } catch (_) {
      _pret = false;
    }
  }

  Future<void> succes() async {
    HapticFeedback.mediumImpact();
    final player = _player ??= AudioPlayer();
    try {
      if (!_pret) {
        await player.setReleaseMode(ReleaseMode.stop);
        await player.setSource(_source);
        _pret = true;
      } else {
        await player.seek(Duration.zero);
      }
      await player.resume();
    } catch (_) {
      _pret = false;
      try {
        await player.play(_source);
      } catch (_) {}
    }
  }
}
