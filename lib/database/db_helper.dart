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
      version: 2,
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
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nom TEXT NOT NULL,
        telephone TEXT NOT NULL UNIQUE,
        motDePasseHash TEXT NOT NULL,
        role TEXT NOT NULL DEFAULT 'gestionnaire',
        actif INTEGER NOT NULL DEFAULT 1
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
        photoPath TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE clients(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nom TEXT NOT NULL,
        telephone TEXT NOT NULL,
        adresse TEXT,
        pointsFidelite INTEGER NOT NULL DEFAULT 0,
        dateCreation TEXT NOT NULL
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
  }
}
