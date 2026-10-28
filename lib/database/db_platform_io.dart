import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

Future<void> initDbPlatform() async {}

Future<String> databaseFilePath() async =>
    join(await getDatabasesPath(), 'salon.db');
