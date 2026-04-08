import re

with open("lib/services/ecodiet_api.dart", "r", encoding="utf-8") as f:
    text = f.read()

# Fix the import
text = text.replace("import '../models/user.dart';", "import '../models/user.dart' as app_models;\nimport '../models/user.dart' hide User;")

# Fix ambiguous User references
text = text.replace("User? _currentUser", "app_models.User? _currentUser")
text = text.replace("User? get currentUser", "app_models.User? get currentUser")
text = text.replace("Future<ApiResult<User>>", "Future<ApiResult<app_models.User>>")
text = text.replace("final user = User(", "final user = app_models.User(")
text = text.replace("final user = User.fromMap(userData);", "final user = app_models.User.fromMap(userData);")

# Remove _hashPassword
# We will just strip out the _hashPassword method entirely using regex
import re
text = re.sub(r"/// Hache un mot de passe avec SHA256.*?\n\s+String _hashPassword\([^}]+\}\n\s+\}", "", text, flags=re.DOTALL)

# Fix count usage
count_find = "final countRes = await _supabase.from('folder_recette')\\n            .select('recette_id', const FetchOptions(count: CountOption.exact))\\n            .eq('folder_id', folder.folderId!);"
count_repl = "final countRes = await _supabase.from('folder_recette')\\n            .select('recette_id').eq('folder_id', folder.folderId!).count(CountOption.exact);"

# Even simpler, just replace the exact text
text = text.replace(
    ".select('*', const FetchOptions(count: CountOption.exact))", 
    ".select().count(CountOption.exact)"
)
text = text.replace(
    ".select('recette_id', const FetchOptions(count: CountOption.exact))", 
    ".select('recette_id').count(CountOption.exact)"
)
text = text.replace(
    "folder.recipeCount = countRes.count ?? 0;", 
    "folder.recipeCount = countRes;"
)
text = text.replace(
    "folder.recipeCount = countRes.length;", 
    "folder.recipeCount = countRes;"
)

with open("lib/services/ecodiet_api.dart", "w", encoding="utf-8") as f:
    f.write(text)

print("Fixes applied.")
