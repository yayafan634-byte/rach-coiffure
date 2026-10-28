import 'package:intl/intl.dart';

final NumberFormat _fcfa = NumberFormat('#,##0', 'fr_FR');
final DateFormat _heure = DateFormat('HH:mm');
final DateFormat _dateCourte = DateFormat('dd/MM/yyyy');
final DateFormat _dateHeure = DateFormat('dd/MM/yyyy à HH:mm');

const _jours = [
  'lundi',
  'mardi',
  'mercredi',
  'jeudi',
  'vendredi',
  'samedi',
  'dimanche',
];

const _mois = [
  'janvier',
  'février',
  'mars',
  'avril',
  'mai',
  'juin',
  'juillet',
  'août',
  'septembre',
  'octobre',
  'novembre',
  'décembre',
];

String formatFcfa(num montant) => '${_fcfa.format(montant)} FCFA';

String formatHeure(DateTime date) => _heure.format(date);

String formatDate(DateTime date) => _dateCourte.format(date);

String formatDateHeure(DateTime date) => _dateHeure.format(date);

String dateLongueFr(DateTime date) =>
    '${_jours[date.weekday - 1]} ${date.day} ${_mois[date.month - 1]} ${date.year}';

String initiales(String nom) {
  final mots = nom
      .trim()
      .split(RegExp(r'\s+'))
      .where((m) => m.isNotEmpty)
      .toList();
  if (mots.isEmpty) return '?';
  if (mots.length == 1) return mots.first.substring(0, 1).toUpperCase();
  return '${mots.first.substring(0, 1)}${mots.last.substring(0, 1)}'
      .toUpperCase();
}
