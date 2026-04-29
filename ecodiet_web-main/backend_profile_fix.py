import os

filepath = '../ecodiet_backend/bin/server.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

profile_route = '''
  // ========== USER PROFILE ==========
  app.put('/api/profile', (Request request) async {
    final authHeader = request.headers['authorization'];
    if (authHeader == null || !authHeader.startsWith('Bearer ')) {
      return Response.forbidden(jsonEncode({'error': 'Non autoris�'}));
    }
    
    final token = authHeader.substring(7);
    int userId;
    try {
      final jwt = JWT.verify(token, SecretKey(jwtSecret));
      userId = jwt.payload['id'] as int;
    } catch (e) {
      return Response.forbidden(jsonEncode({'error': 'Token invalide'}));
    }

    final payload = await request.readAsString();
    final data = jsonDecode(payload);
    
    try {
      // Construction dynamique de la requ�te update
      List<String> setClauses = [];
      Map<String, dynamic> params = {'id': userId};
      
      if (data.containsKey('nom')) {
        setClauses.add('nom = @nom');
        params['nom'] = data['nom'];
      }
      if (data.containsKey('prenom')) {
        setClauses.add('prenom = @prenom');
        params['prenom'] = data['prenom'];
      }
      if (data.containsKey('photo_url')) {
        setClauses.add('photo_url = @photo_url');
        params['photo_url'] = data['photo_url'];
      }

      if (setClauses.isEmpty) {
        return Response.ok(jsonEncode({'message': 'Aucune modification'}));
      }

      final query = 'UPDATE "user" SET \ WHERE id_user = @id RETURNING *';
      final result = await connection.execute(Sql.named(query), parameters: params);
      
      if (result.isEmpty) return Response.notFound(jsonEncode({'error': 'Utilisateur introuvable'}));
      
      return Response.ok(jsonEncode({
        'message': 'Profil mis � jour',
        'user': {
          'id_user': result[0][0],
          'email': result[0][1],
          'nom': result[0][3],
          'prenom': result[0][4]
        }
      }), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': 'Erreur serveur: \'}));
    }
  });
'''

if 'app.put(\'/api/profile\'' not in content:
    content = content.replace('  // Appliquer le middleware CORS', profile_route + '\n  // Appliquer le middleware CORS')
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    print("Added profile route mapping successfully.")
else:
    print("Route already exists.")