import 'package:sqflite/sqflite.dart';
import 'db_platform.dart';

class DbHelper {
  static final DbHelper instance = DbHelper._();
  static Database? _db;

  DbHelper._();

  Future<Database> get db async {
    _db ??= await _init();
    return _db!;
  }

  Future<Database> _init() async {
    await initDbPlatform();
    final path = await databaseFilePath();
    return openDatabase(
      path,
      version: 7,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS mouvements_stock(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          perruqueId INTEGER NOT NULL,
          delta INTEGER NOT NULL,
          type TEXT NOT NULL,
          motif TEXT,
          date TEXT NOT NULL,
          FOREIGN KEY(perruqueId) REFERENCES perruques(id)
        )
      ''');
      await db.execute(
          'ALTER TABLE ventes ADD COLUMN quantite INTEGER NOT NULL DEFAULT 1');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE ventes ADD COLUMN libelle TEXT');
    }
    if (oldVersion < 4) {
      await db.execute(
          'ALTER TABLE perruques ADD COLUMN seuilAlerte INTEGER NOT NULL DEFAULT 3');
      await db.execute('ALTER TABLE perruques ADD COLUMN fournisseur TEXT');
      await db.execute('ALTER TABLE clients ADD COLUMN dateNaissance TEXT');
      await db.execute(
          'ALTER TABLE ventes ADD COLUMN remise REAL NOT NULL DEFAULT 0');
      await db.execute(
          'ALTER TABLE ventes ADD COLUMN pointsUtilises INTEGER NOT NULL DEFAULT 0');

      await _creerTablesV4(db);

      await db.execute('''
        INSERT INTO venteItems
          (venteId, perruqueId, libelle, prixUnitaire, quantite, montant)
        SELECT id, perruqueId, libelle,
               CASE WHEN quantite > 0 THEN montant / quantite ELSE montant END,
               quantite, montant
        FROM ventes
        WHERE perruqueId IS NOT NULL OR (libelle IS NOT NULL AND libelle <> '')
      ''');
    }
    if (oldVersion < 5) {
      await db.execute('ALTER TABLE users ADD COLUMN permissions TEXT');
    }
    if (oldVersion < 6) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS sync_meta(
          cle TEXT PRIMARY KEY,
          valeur TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 7) {
      await db.execute(
          'ALTER TABLE users ADD COLUMN doitChangerMotDePasse INTEGER NOT NULL DEFAULT 0');
    }
  }

  Future<void> _creerTablesV4(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS venteItems(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        venteId INTEGER NOT NULL,
        perruqueId INTEGER,
        libelle TEXT,
        prixUnitaire REAL NOT NULL,
        quantite INTEGER NOT NULL DEFAULT 1,
        montant REAL NOT NULL,
        FOREIGN KEY(venteId) REFERENCES ventes(id) ON DELETE CASCADE,
        FOREIGN KEY(perruqueId) REFERENCES perruques(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS parametres(
        cle TEXT PRIMARY KEY,
        valeur TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS activites(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId INTEGER,
        utilisateur TEXT,
        action TEXT NOT NULL,
        details TEXT,
        date TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS depenses(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        libelle TEXT NOT NULL,
        categorie TEXT,
        montant REAL NOT NULL,
        date TEXT NOT NULL
      )
    ''');

    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_venteItems_vente ON venteItems(venteId)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_ventes_date ON ventes(dateVente)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_rdv_date ON rendezVous(dateHeure)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_activites_date ON activites(date)');
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nom TEXT NOT NULL,
        telephone TEXT NOT NULL UNIQUE,
        motDePasseHash TEXT NOT NULL,
        role TEXT NOT NULL DEFAULT 'gestionnaire',
        actif INTEGER NOT NULL DEFAULT 1,
        permissions TEXT,
        doitChangerMotDePasse INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE perruques(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nom TEXT NOT NULL,
        type TEXT NOT NULL,
        longueur TEXT NOT NULL,
        couleur TEXT NOT NULL,
        texture TEXT NOT NULL,
        quantite INTEGER NOT NULL DEFAULT 0,
        prixAchat REAL NOT NULL,
        prixVente REAL NOT NULL,
        photoPath TEXT,
        seuilAlerte INTEGER NOT NULL DEFAULT 3,
        fournisseur TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE clients(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nom TEXT NOT NULL,
        telephone TEXT NOT NULL,
        adresse TEXT,
        pointsFidelite INTEGER NOT NULL DEFAULT 0,
        dateCreation TEXT NOT NULL,
        dateNaissance TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE prestations(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nom TEXT NOT NULL,
        prix REAL NOT NULL,
        dureeMinutes INTEGER NOT NULL DEFAULT 60
      )
    ''');

    await db.execute('''
      CREATE TABLE rendezVous(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        clientId INTEGER NOT NULL,
        prestationId INTEGER,
        dateHeure TEXT NOT NULL,
        statut TEXT NOT NULL DEFAULT 'prévu',
        note TEXT,
        FOREIGN KEY(clientId) REFERENCES clients(id),
        FOREIGN KEY(prestationId) REFERENCES prestations(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE ventes(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        clientId INTEGER,
        perruqueId INTEGER,
        prestationId INTEGER,
        montant REAL NOT NULL,
        quantite INTEGER NOT NULL DEFAULT 1,
        modePaiement TEXT NOT NULL,
        libelle TEXT,
        remise REAL NOT NULL DEFAULT 0,
        pointsUtilises INTEGER NOT NULL DEFAULT 0,
        dateVente TEXT NOT NULL,
        FOREIGN KEY(clientId) REFERENCES clients(id),
        FOREIGN KEY(perruqueId) REFERENCES perruques(id),
        FOREIGN KEY(prestationId) REFERENCES prestations(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE mouvements_stock(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        perruqueId INTEGER NOT NULL,
        delta INTEGER NOT NULL,
        type TEXT NOT NULL,
        motif TEXT,
        date TEXT NOT NULL,
        FOREIGN KEY(perruqueId) REFERENCES perruques(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE sync_meta(
        cle TEXT PRIMARY KEY,
        valeur TEXT NOT NULL
      )
    ''');

    await _creerTablesV4(db);
  }
}
