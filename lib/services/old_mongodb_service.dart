import 'package:mongo_dart/mongo_dart.dart';
import 'package:logger/logger.dart';

final logger = Logger(level: Level.debug, printer: PrettyPrinter());

class MongoDBService {
  static late Db _db;
  static const String _collectionName = 'user_profile';

  static Future<void> connect() async {
    const String connectionString =
        'mongodb+srv://mumuprimev33_db_user:aipVGrLSVq2kqGmm@cluster0.b7ayomx.mongodb.net/EcoDiet?retryWrites=true&w=majority';
    _db = Db(connectionString);
    await _db.open();
    logger.i('Connexion réussie : ${_db.isConnected}');
  }

  static Future<void> insertUser(Map<String, dynamic> userData) async {
    try {
      logger.d('Insertion des données : $userData');
      final result = await _db.collection(_collectionName).insertOne(userData);
      if (!result.isSuccess) {
        logger.e('Échec de l\'insertion : ${result.writeError?.errmsg}');
        throw Exception('Échec de l\'insertion');
      }
      logger.i('Insertion réussie, ID : ${result.id}');
    } catch (e) {
      logger.e('Erreur : $e');
      rethrow;
    }
  }

  static Future<void> close() async {
    await _db.close();
    logger.i('Connexion fermée');
  }
}
