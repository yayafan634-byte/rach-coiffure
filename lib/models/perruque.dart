class Perruque {
  final int? id;
  final String nom;
  final String type; // Brésilien, Mongole, etc.
  final String longueur;
  final String couleur;
  final String texture;
  final int quantite;
  final double prixAchat;
  final double prixVente;
  final String? photoPath;
  final int seuilAlerte;
  final String? fournisseur;

  Perruque({
    this.id,
    required this.nom,
    required this.type,
    required this.longueur,
    required this.couleur,
    required this.texture,
    required this.quantite,
    required this.prixAchat,
    required this.prixVente,
    this.photoPath,
    this.seuilAlerte = 3,
    this.fournisseur,
  });

  bool get stockBas => quantite <= seuilAlerte;

  double get margeUnitaire => prixVente - prixAchat;

  double get margePourcent =>
      prixAchat <= 0 ? 0 : (margeUnitaire / prixAchat) * 100;

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'nom': nom,
        'type': type,
        'longueur': longueur,
        'couleur': couleur,
        'texture': texture,
        'quantite': quantite,
        'prixAchat': prixAchat,
        'prixVente': prixVente,
        'photoPath': photoPath,
        'seuilAlerte': seuilAlerte,
        'fournisseur': fournisseur,
      };

  factory Perruque.fromMap(Map<String, dynamic> m) => Perruque(
        id: m['id'],
        nom: m['nom'],
        type: m['type'],
        longueur: m['longueur'],
        couleur: m['couleur'],
        texture: m['texture'],
        quantite: m['quantite'],
        prixAchat: (m['prixAchat'] as num).toDouble(),
        prixVente: (m['prixVente'] as num).toDouble(),
        photoPath: m['photoPath'],
        seuilAlerte: (m['seuilAlerte'] as num?)?.toInt() ?? 3,
        fournisseur: m['fournisseur'] as String?,
      );
}
