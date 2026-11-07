import 'dart:math';

final Random _aleatoire = Random();
int _compteur = _aleatoire.nextInt(1024);

int nouvelId() {
  final millis = DateTime.now().millisecondsSinceEpoch;
  _compteur = (_compteur + 1) & 0x3FF;
  return millis * 1024 + _compteur;
}
