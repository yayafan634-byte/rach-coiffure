import 'package:sqflite/sqflite.dart';
import '../database/db_helper.dart';

class Parametres {
  final String nomSalon;
  final String telephone;
  final String adresse;
  final String messageRecu;
  final double valeurPoint;

  const Parametres({
    this.nomSalon = 'Rach Coiffure',
    this.telephone = '',
    this.adresse = '',
    this.messageRecu = 'Merci de votre confiance !',
    this.valeurPoint = 100,
  });

  Parametres copyWith({
    String? nomSalon,
    String? telephone,
    String? adresse,
    String? messageRecu,
    double? valeurPoint,
  }) =>
      Parametres(
        nomSalon: nomSalon ?? this.nomSalon,
        telephone: telephone ?? this.telephone,
        adresse: adresse ?? this.adresse,
        messageRecu: messageRecu ?? this.messageRecu,
        valeurPoint: valeurPoint ?? this.valeurPoint,
      );
}

class ParametresService {
  static final ParametresService instance = ParametresService._();
  ParametresService._();

  static const _defauts = {
    'nomSalon': 'Rach Coiffure',
    'telephone': '',
    'adresse': '',
    'messageRecu': 'Merci de votre confiance !',
    'valeurPoint': '100',
  };

  Future<Parametres> charger() async {
    final db = await DbHelper.instance.db;
    final res = await db.query('parametres');
    final valeurs = <String, String>{..._defauts};
    for (final ligne in res) {
      valeurs[ligne['cle'] as String] = ligne['valeur'] as String;
    }
    return Parametres(
      nomSalon: valeurs['nomSalon']!,
      telephone: valeurs['telephone']!,
      adresse: valeurs['adresse']!,
      messageRecu: valeurs['messageRecu']!,
      valeurPoint: double.tryParse(valeurs['valeurPoint']!) ?? 100,
    );
  }

  Future<void> enregistrer(Parametres p) async {
    final db = await DbHelper.instance.db;
    final valeurs = {
      'nomSalon': p.nomSalon.trim(),
      'telephone': p.telephone.trim(),
      'adresse': p.adresse.trim(),
      'messageRecu': p.messageRecu.trim(),
      'valeurPoint': p.valeurPoint.toString(),
    };
    final batch = db.batch();
    for (final e in valeurs.entries) {
      batch.insert(
        'parametres',
        {'cle': e.key, 'valeur': e.value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }
}
