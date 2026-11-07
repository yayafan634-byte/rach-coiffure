import 'package:flutter_test/flutter_test.dart';
import 'package:perruques_salon/auth/auth_provider.dart';
import 'package:perruques_salon/models/client.dart';
import 'package:perruques_salon/models/perruque.dart';
import 'package:perruques_salon/models/user.dart';

void main() {
  group('validerMotDePasse', () {
    test('refuse un mot de passe trop court', () {
      expect(validerMotDePasse('abc1'), 'Minimum 8 caractères');
    });

    test('exige une lettre et un chiffre', () {
      expect(validerMotDePasse('abcdefgh'), isNotNull);
      expect(validerMotDePasse('12345678'), isNotNull);
    });

    test('accepte un mot de passe conforme', () {
      expect(validerMotDePasse('salon2026'), isNull);
    });
  });

  test('Perruque conserve le seuil et le fournisseur', () {
    final p = Perruque(
      id: 1,
      nom: 'Body wave',
      type: 'Brésilien',
      longueur: '22"',
      couleur: 'Noir',
      texture: 'Ondulée',
      quantite: 2,
      prixAchat: 10000,
      prixVente: 20000,
      seuilAlerte: 5,
      fournisseur: 'Boutique A',
    );

    final copie = Perruque.fromMap(p.toMap());

    expect(copie.seuilAlerte, 5);
    expect(copie.fournisseur, 'Boutique A');
  });

  test('Client conserve la date de naissance lors de la modification', () {
    final c = Client(
      id: 1,
      nom: 'Awa',
      telephone: '70000000',
      dateNaissance: DateTime(1995, 4, 12),
    );

    final copie = Client.fromMap(c.toMap());

    expect(copie.dateNaissance, DateTime(1995, 4, 12));
  });

  test('AppUser conserve la demande de changement de mot de passe', () {
    final u = AppUser(
      id: 1,
      nom: 'Issiaka',
      telephone: '0000',
      motDePasseHash: 'hash',
      role: 'admin',
      doitChangerMotDePasse: true,
    );

    final copie = AppUser.fromMap(u.toMap());

    expect(copie.doitChangerMotDePasse, isTrue);
    expect(copie.copyWith(doitChangerMotDePasse: false).doitChangerMotDePasse,
        isFalse);
  });
}
