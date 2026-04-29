"""
ChefBot — Recipe recommendation chatbot (no API, pure Python algorithms)
Recommends recipes based on user dietary profile + natural keyword parsing.
"""

import csv
import json
import random
import re
import textwrap
from pathlib import Path

# ─── Paths ────────────────────────────────────────────────────────────────────
BASE_DIR   = Path(__file__).parent
DIM_DIR    = BASE_DIR / "DIM"
FACT_DIR   = BASE_DIR / "FACT"
PROFILES_F = BASE_DIR / "profiles.json"

# ─── Dietary hierarchy ────────────────────────────────────────────────────────
REGIME_COMPAT = {
    "vegan":       {"vegan"},
    "vegetarian":  {"vegan", "vegetarian"},
    "pescetarian": {"vegan", "vegetarian", "pescetarian"},
    "carnivore":   {"vegan", "vegetarian", "pescetarian", "carnivore"},
}

# ─── Keyword maps (FR + EN) ───────────────────────────────────────────────────
OCCASION_KEYWORDS = {
    "barbecue":  ["barbecue", "bbq", "grill", "grillé"],
    "ete":       ["été", "ete", "summer", "chaud", "frais", "estival"],
    "noel":      ["noël", "noel", "christmas", "fêtes", "fetes", "réveillon"],
    "festif":    ["festif", "fête", "fete", "party", "célébration", "anniversaire"],
    "quotidien": ["quotidien", "everyday", "tous les jours", "semaine", "daily"],
    "rapide":    ["rapide", "quick", "fast", "vite", "express", "pressé"],
    "familial":  ["familial", "famille", "family", "enfants", "kids"],
}

DISH_KEYWORDS = {
    "entree":         ["entrée", "entree", "starter", "amuse"],
    "plat_principal": ["plat", "principal", "main", "diner", "dîner", "déjeuner", "repas"],
    "dessert":        ["dessert", "sucré", "sucre", "gâteau", "gateau", "cake", "sweet"],
    "petit_dejeuner": ["petit-déjeuner", "petit dejeuner", "breakfast", "matin", "brunch"],
    "aperitif":       ["apéritif", "aperitif", "apéro", "apero", "cocktail", "drink"],
    "snack":          ["snack", "encas", "en-cas", "goûter", "gouter"],
}

DURATION_KEYWORDS = {
    "quick":  ["rapide", "quick", "vite", "express", "simple", "20 min", "30 min", "pressé"],
    "medium": ["moyen", "medium", "normal", "30", "45", "60"],
    "long":   ["long", "lent", "mijot", "slow", "confit", "mariné", "heure"],
}

ALLERGEN_KEYWORDS = {
    "gluten":        ["gluten", "blé", "ble", "farine", "pain", "wheat"],
    "lactose":       ["lactose", "lait", "crème", "creme", "beurre", "fromage", "dairy", "milk"],
    "arachide":      ["arachide", "cacahuète", "cacahuete", "peanut"],
    "fruits_a_coque":["noix", "noisette", "amande", "noix de cajou", "nut", "pecan"],
    "oeuf":          ["oeuf", "egg"],
    "poisson":       ["poisson", "fish", "saumon", "thon", "cabillaud"],
    "crustaces":     ["crustacé", "crustace", "crevette", "homard", "crabe", "lobster", "shrimp"],
    "mollusques":    ["mollusque", "moule", "coquille", "huître", "huitre", "escargot"],
    "soja":          ["soja", "soy", "tofu"],
    "sesame":        ["sésame", "sesame"],
    "moutarde":      ["moutarde", "mustard"],
    "celeri":        ["céleri", "celeri", "celery"],
    "sulfites":      ["sulfite", "vin", "wine"],
}

REGIME_KEYWORDS = {
    "vegan":       ["vegan", "végétalien", "vegetalien", "plant-based", "sans viande", "sans animal"],
    "vegetarian":  ["végétarien", "vegetarien", "vegetarian", "sans viande"],
    "pescetarian": ["pescétarien", "pescetarien", "pescetarian", "poisson"],
    "carnivore":   ["carnivore", "viande", "meat", "boeuf", "poulet", "porc"],
}

INTENT_KEYWORDS = {
    "recommend":  ["propose", "suggère", "suggere", "recommande", "donne", "cherche", "trouve",
                   "veux", "voudrais", "j'aimerais", "montre", "give me", "suggest", "find",
                   "quoi manger", "que manger", "quoi cuisiner", "idée", "idea"],
    "more":       ["autre", "encore", "more", "plus", "suivant", "next", "suite", "différent"],
    "detail":     ["détail", "detail", "ingrédient", "ingredient", "recette complète",
                   "plus d'info", "comment", "how", "préparation", "preparation"],
    "list_all":   ["liste", "list", "tout", "all", "combien", "how many"],
    "help":       ["aide", "help", "quoi dire", "commande", "comment utiliser"],
    "quit":       ["quitter", "quit", "exit", "bye", "au revoir", "sortir", "fin"],
}

GREETING_KEYWORDS = ["bonjour", "salut", "hello", "hi", "bonsoir", "coucou", "hey"]

SUBSTITUTE_KEYWORDS = ["remplacer", "substitut", "alternative", "sans viande", "version vegan",
                       "version végétarienne", "changer", "swap"]

# ─── CSV helpers ──────────────────────────────────────────────────────────────

def load_dim(filename: str, key_col: str) -> dict:
    path = DIM_DIR / filename
    with open(path, encoding="utf-8") as f:
        return {r[key_col]: r for r in csv.DictReader(f)}

def load_fact(filename: str) -> list:
    path = FACT_DIR / filename
    with open(path, encoding="utf-8") as f:
        return list(csv.DictReader(f))

# ─── Database builder ─────────────────────────────────────────────────────────

def build_recipe_db() -> tuple:
    allergens   = load_dim("DIM_ALLERGENE.csv",   "allergene_id")
    ingredients = load_dim("DIM_INGREDIENTS.csv", "ingredient_id")
    occasions   = load_dim("DIM_OCCASION.csv",    "occasion_id")
    regimes     = load_dim("DIM_REGIME.csv",      "regime_id")
    dish_types  = load_dim("DIM_TYPE_PLAT.csv",   "type_plat_id")
    equipment   = load_dim("DIM_EQUIPEMENT.csv",  "equipement_id")
    time_bins   = load_dim("DIM_TEMPS_BIN.csv",   "temps_bin_id")

    recipes_base = {r["recette_id"]: r for r in load_fact("FACT_RECETTE_BASE.csv")}
    fact_ing = load_fact("FACT_INGREDIENTS_RECETTE.csv")
    fact_alg = load_fact("FACT_RECETTE_ALLERGENE.csv")
    fact_occ = load_fact("FACT_RECETTE_OCCASION.csv")
    fact_reg = load_fact("FACT_RECETTE_REGIME.csv")
    fact_dt  = load_fact("FACT_RECETTE_TYPE_PLAT.csv")
    fact_eq  = load_fact("FACT_RECETTE_EQUIPEMENTS.csv")

    db = {}
    for rid, r in recipes_base.items():
        dur = r.get("duree_minute", "0") or "0"
        tbin = time_bins.get(r.get("temps_bin_id", ""), {}).get("libelle", "")
        db[rid] = {
            "id":          rid,
            "title":       r["titre"],
            "duration":    int(dur) if dur.isdigit() else 0,
            "time_bin":    tbin,
            "ingredients": [],
            "allergens":   [],
            "occasions":   [],
            "regimes":     [],
            "dish_types":  [],
            "equipment":   [],
        }

    def _add(bridge, id_col, dim, dim_key, field):
        for row in bridge:
            rid = row["recette_id"]
            if rid in db:
                val = dim.get(row[id_col], {}).get(dim_key, "")
                if val:
                    db[rid][field].append(val)

    _add(fact_ing, "ingredient_id", ingredients, "nom_ingredient", "ingredients")
    _add(fact_alg, "allergene_id",  allergens,   "libelle",        "allergens")
    _add(fact_occ, "occasion_id",   occasions,   "libelle",        "occasions")
    _add(fact_reg, "regime_id",     regimes,     "libelle",        "regimes")
    _add(fact_dt,  "type_plat_id",  dish_types,  "libelle",        "dish_types")
    _add(fact_eq,  "equipement_id", equipment,   "nom_equipement", "equipment")

    dimensions = {
        "allergens":  allergens,
        "regimes":    regimes,
        "occasions":  occasions,
        "dish_types": dish_types,
    }
    return db, dimensions

# ─── Profile filtering ────────────────────────────────────────────────────────

def profile_filter(recipe_db: dict, profile: dict) -> list:
    """Hard filter: remove allergen conflicts and diet incompatibilities."""
    user_allergies = set(profile.get("allergies", []))
    user_regime    = profile.get("regime", "")
    compatible     = REGIME_COMPAT.get(user_regime, set())

    result = []
    for recipe in recipe_db.values():
        if user_allergies & set(recipe["allergens"]):
            continue
        if user_regime and compatible:
            if not (compatible & set(recipe["regimes"])):
                continue
        result.append(recipe)
    return result

# ─── NLP: keyword extraction ──────────────────────────────────────────────────

def normalize(text: str) -> str:
    text = text.lower()
    # Remove accents for easier matching
    replacements = {
        "é":"e","è":"e","ê":"e","ë":"e",
        "à":"a","â":"a","ä":"a",
        "î":"i","ï":"i",
        "ô":"o","ö":"o",
        "ù":"u","û":"u","ü":"u",
        "ç":"c","œ":"oe","æ":"ae",
    }
    for src, dst in replacements.items():
        text = text.replace(src, dst)
    return text

def detect_keywords(text: str, keyword_map: dict) -> list:
    """Return list of keys from keyword_map whose keywords appear in text."""
    norm = normalize(text)
    found = []
    for key, kws in keyword_map.items():
        if any(normalize(kw) in norm for kw in kws):
            found.append(key)
    return found

def detect_intents(text: str) -> list:
    return detect_keywords(text, INTENT_KEYWORDS)

FILLERS = {"de","du","la","le","les","des","un","une","au","aux","et","ou","l","d","mes","ton","ma"}

def detect_ingredient_search(text: str) -> str | None:
    """Detect 'avec [des/du/...] [ingredient]' or 'with [ingredient]' patterns."""
    norm = normalize(text)
    # Patterns that capture one or two words after an optional article
    patterns = [
        r"avec (?:du |de la |des |de l |l |)(\w+)",
        r"with (?:some |)(\w+)",
        r"contenant (?:du |de la |des |de l |)(\w+)",
        r"qui contient (?:du |de la |des |)(\w+)",
        r"a base de (\w+)",
        r"base de (\w+)",
        r"utilisant (\w+)",
    ]
    for pattern in patterns:
        m = re.search(pattern, norm)
        if m:
            word = m.group(1)
            if word not in FILLERS and len(word) > 2:
                return word
    return None

def detect_recipe_name(text: str, recipes: list) -> dict | None:
    """Try to find a recipe by name mention in the text."""
    norm = normalize(text)
    best_match = None
    best_score = 0
    for r in recipes:
        title_words = normalize(r["title"]).split()
        # Score = number of title words found in the message
        score = sum(1 for w in title_words if len(w) > 3 and w in norm)
        if score > best_score:
            best_score = score
            best_match = r
    return best_match if best_score >= 2 else None

# ─── Query engine ─────────────────────────────────────────────────────────────

def query_recipes(pool: list, text: str) -> list:
    """
    Score and filter `pool` based on keywords in `text`.
    Returns recipes sorted by relevance score (descending).
    """
    occasions_wanted  = set(detect_keywords(text, OCCASION_KEYWORDS))
    dishes_wanted     = set(detect_keywords(text, DISH_KEYWORDS))
    duration_wanted   = detect_keywords(text, DURATION_KEYWORDS)
    extra_excl_allerg = set(detect_keywords(text, ALLERGEN_KEYWORDS))
    regime_wanted     = set(detect_keywords(text, REGIME_KEYWORDS))
    ingredient_kw     = detect_ingredient_search(text)

    results = []
    for r in pool:
        # Hard exclude: additional allergen mentioned by user in message
        if extra_excl_allerg & set(r["allergens"]):
            continue

        score = 0

        # Occasion match
        if occasions_wanted:
            if occasions_wanted & set(r["occasions"]):
                score += 3
            else:
                score -= 1

        # Dish type match
        if dishes_wanted:
            if dishes_wanted & set(r["dish_types"]):
                score += 3
            else:
                score -= 1

        # Regime match (extra filter within allowed pool)
        if regime_wanted:
            if regime_wanted & set(r["regimes"]):
                score += 2

        # Duration match
        dur = r["duration"]
        if "quick" in duration_wanted:
            if dur > 0 and dur <= 30:
                score += 2
            elif dur > 60:
                score -= 1
        if "long" in duration_wanted:
            if dur > 60:
                score += 2

        # Ingredient keyword match
        if ingredient_kw:
            ing_text = normalize(" ".join(r["ingredients"]))
            if ingredient_kw in ing_text:
                score += 4

        results.append((score, r))

    # Sort by score desc, then shuffle same-score ties for variety
    results.sort(key=lambda x: x[0], reverse=True)

    # Separate zero-score (no criteria) from positive matches
    if occasions_wanted or dishes_wanted or ingredient_kw or duration_wanted or regime_wanted:
        results = [(s, r) for s, r in results if s > 0]

    return [r for _, r in results]

# ─── Response formatting ──────────────────────────────────────────────────────

def fmt_duration(recipe: dict) -> str:
    if recipe["duration"] > 0:
        return f"{recipe['duration']} min"
    return recipe.get("time_bin") or "durée inconnue"

def fmt_recipe_card(recipe: dict, idx: int = None) -> str:
    prefix = f"{idx}. " if idx else ""
    dur    = fmt_duration(recipe)
    types  = ", ".join(recipe["dish_types"]) or "—"
    occ    = ", ".join(recipe["occasions"])  or "—"
    alg    = ", ".join(recipe["allergens"])  or "aucun"
    reg    = ", ".join(recipe["regimes"])    or "—"
    return (
        f"{prefix}**{recipe['title']}**\n"
        f"   Durée : {dur}  |  Type : {types}  |  Occasion : {occ}\n"
        f"   Régime : {reg}  |  Allergènes : {alg}"
    )

def fmt_recipe_detail(recipe: dict) -> str:
    dur   = fmt_duration(recipe)
    types = ", ".join(recipe["dish_types"]) or "—"
    occ   = ", ".join(recipe["occasions"])  or "—"
    alg   = ", ".join(recipe["allergens"])  or "aucun"
    reg   = ", ".join(recipe["regimes"])    or "—"
    equip = ", ".join(recipe["equipment"])  or "—"
    ings  = "\n   • ".join(recipe["ingredients"]) or "—"

    return (
        f"=== {recipe['title']} ===\n"
        f"Durée       : {dur}\n"
        f"Type        : {types}\n"
        f"Occasion    : {occ}\n"
        f"Régime      : {reg}\n"
        f"Allergènes  : {alg}\n"
        f"Équipement  : {equip}\n"
        f"\nIngrédients :\n   • {ings}"
    )

def suggest_substitutions(recipe: dict, profile: dict) -> str:
    """Generate substitution tips for vegetarians/vegans looking at a meat dish."""
    regime = profile.get("regime", "")
    tips = []

    if regime in ("vegetarian", "vegan"):
        meat_kws = ["poulet", "boeuf", "porc", "agneau", "canard", "veau",
                    "lardons", "jambon", "saucisse", "dinde", "lapin"]
        ings = [i.lower() for i in recipe["ingredients"]]
        found_meat = [kw for kw in meat_kws if any(kw in i for i in ings)]

        subs = {
            "poulet":    "tofu ferme ou seitan",
            "boeuf":     "protéines de soja texturées (PST) ou champignons portobello",
            "porc":      "tofu fumé ou tempeh",
            "agneau":    "lentilles ou pois chiches",
            "canard":    "jackfruit effiloché",
            "veau":      "seitan",
            "lardons":   "lardons de tofu fumé ou dés de tempeh",
            "jambon":    "tofu fumé tranché",
            "saucisse":  "saucisse végétale",
            "dinde":     "seitan ou tofu",
            "lapin":     "champignons ou pois chiches",
        }

        for meat in found_meat:
            sub = subs.get(meat, "une alternative végétale")
            tips.append(f"• Remplacez '{meat}' par {sub}")

        if regime == "vegan":
            dairy_kws = ["beurre", "crème", "lait", "fromage", "yaourt"]
            found_dairy = [kw for kw in dairy_kws if any(kw in i for i in ings)]
            dairy_subs = {
                "beurre":  "margarine végétale ou huile de coco",
                "crème":   "crème de coco ou crème de soja",
                "lait":    "lait de soja, d'avoine ou d'amande",
                "fromage": "fromage végétal ou levure maltée",
                "yaourt":  "yaourt de soja ou de coco",
            }
            for dairy in found_dairy:
                sub = dairy_subs.get(dairy, "une alternative végétale")
                tips.append(f"• Remplacez '{dairy}' par {sub}")

    if not tips:
        return ""
    return "\nSuggestions d'adaptation :\n" + "\n".join(tips)

# ─── Session state ────────────────────────────────────────────────────────────

class Session:
    def __init__(self, pool: list, profile: dict):
        self.pool            = pool        # all profile-safe recipes
        self.profile         = profile
        self.last_results    = []          # last search results
        self.display_offset  = 0           # for "show more"
        self.page_size       = 4

    def show_next_page(self) -> str:
        end = self.display_offset + self.page_size
        page = self.last_results[self.display_offset:end]
        self.display_offset = end

        if not page:
            return "Il n'y a plus d'autres recettes pour cette recherche."

        lines = ["Voici d'autres recettes :\n"]
        for i, r in enumerate(page, self.display_offset - len(page) + 1):
            lines.append(fmt_recipe_card(r, i))

        remaining = len(self.last_results) - self.display_offset
        if remaining > 0:
            lines.append(f"\n({remaining} recettes de plus — tapez 'encore' pour voir la suite)")
        return "\n".join(lines)

    def new_search(self, results: list) -> str:
        self.last_results   = results
        self.display_offset = 0
        return self.show_next_page()

# ─── Response generator ───────────────────────────────────────────────────────

def generate_response(text: str, session: Session) -> str:
    intents = detect_intents(text)
    norm    = normalize(text)

    # ── Quit ──────────────────────────────────────────────────────────────────
    if "quit" in intents:
        return "QUIT"

    # ── Greeting ──────────────────────────────────────────────────────────────
    if any(normalize(g) in norm for g in GREETING_KEYWORDS):
        name = session.profile["name"]
        regime = session.profile.get("regime") or "sans régime particulier"
        allergies = session.profile.get("allergies", [])
        alg_str = ", ".join(allergies) if allergies else "aucune"
        return (
            f"Bonjour {name} ! Je suis ChefBot, votre assistant culinaire.\n"
            f"Votre profil : régime {regime} | allergies : {alg_str}\n"
            f"J'ai {len(session.pool)} recettes adaptées pour vous.\n\n"
            f"Essayez : 'propose-moi un plat principal', 'quelque chose de rapide',\n"
            f"'recette avec des champignons', 'idée pour un barbecue'..."
        )

    # ── Help ──────────────────────────────────────────────────────────────────
    if "help" in intents:
        return (
            "Voici ce que vous pouvez me demander :\n\n"
            "  • 'propose-moi un dessert'\n"
            "  • 'une recette rapide pour ce soir'\n"
            "  • 'idée pour un barbecue'\n"
            "  • 'recette avec des champignons'\n"
            "  • 'encore' / 'autres recettes'\n"
            "  • 'détails sur [nom de recette]'\n"
            "  • 'liste toutes les recettes'\n"
            "  • 'quitter' pour sortir"
        )

    # ── List all ──────────────────────────────────────────────────────────────
    if "list_all" in intents and any(w in norm for w in ["tout", "all", "liste", "combien"]):
        results = session.pool[:]
        random.shuffle(results)
        reply = session.new_search(results)
        return f"J'ai {len(session.pool)} recettes pour votre profil.\n\n" + reply

    # ── Show more ─────────────────────────────────────────────────────────────
    if "more" in intents and not "recommend" in intents:
        if session.last_results:
            return session.show_next_page()
        else:
            return "Faites d'abord une recherche, puis tapez 'encore' pour voir plus."

    # ── Detail request ────────────────────────────────────────────────────────
    if "detail" in intents or "ingrédient" in norm or "ingredient" in norm:
        recipe = detect_recipe_name(text, session.last_results or session.pool)
        if recipe:
            detail = fmt_recipe_detail(recipe)
            subs   = suggest_substitutions(recipe, session.profile)
            return detail + subs
        elif session.last_results:
            # Show details of first result if no name found
            recipe = session.last_results[0]
            detail = fmt_recipe_detail(recipe)
            subs   = suggest_substitutions(recipe, session.profile)
            return detail + subs
        else:
            return "Précisez le nom de la recette dont vous voulez les détails."

    # ── Substitution request ──────────────────────────────────────────────────
    if any(normalize(kw) in norm for kw in SUBSTITUTE_KEYWORDS):
        recipe = detect_recipe_name(text, session.last_results or session.pool)
        if recipe:
            subs = suggest_substitutions(recipe, session.profile)
            if subs:
                return f"Pour adapter '{recipe['title']}' :\n{subs}"
            else:
                return f"'{recipe['title']}' est déjà compatible avec votre profil !"
        else:
            return "De quelle recette voulez-vous adapter les ingrédients ?"

    # ── Recipe recommendation (default intent) ────────────────────────────────
    results = query_recipes(session.pool, text)

    if not results:
        # Widen search — just pick random from pool
        results = session.pool[:]
        random.shuffle(results)
        prefix = (
            "Je n'ai pas trouvé de recettes exactement correspondantes "
            "à votre demande dans votre profil, mais voici quelques suggestions :\n\n"
        )
    else:
        prefix = f"Voici {min(len(results), session.page_size)} recette(s) pour vous :\n\n"

    reply = session.new_search(results)
    return prefix + reply

# ─── Profile management ───────────────────────────────────────────────────────

def load_profiles() -> dict:
    if PROFILES_F.exists():
        with open(PROFILES_F, encoding="utf-8") as f:
            return json.load(f)
    return {"profiles": []}

def save_profiles(data: dict):
    with open(PROFILES_F, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

def select_or_create_profile(profiles_data: dict, dimensions: dict) -> dict:
    existing = profiles_data.get("profiles", [])

    print("\n" + "=" * 55)
    print("       ChefBot — Assistant Culinaire Personnalisé")
    print("=" * 55)

    if existing:
        print("\nProfils existants :")
        for i, p in enumerate(existing, 1):
            allergies = ", ".join(p.get("allergies", [])) or "aucune"
            print(f"  {i}. {p['name']:12s} | régime: {p.get('regime','—'):12s} | allergies: {allergies}")
        print(f"  {len(existing)+1}. Créer un nouveau profil")

        choice = input("\nChoisissez un profil (numéro) : ").strip()
        try:
            idx = int(choice) - 1
            if 0 <= idx < len(existing):
                return existing[idx]
        except ValueError:
            pass

    # ── Create new profile ──
    print("\n── Création d'un nouveau profil ──")
    name = input("Votre prénom : ").strip() or "Utilisateur"

    regime_list = list(REGIME_COMPAT.keys()) + ["(aucun)"]
    print("\nRégimes alimentaires :")
    for i, r in enumerate(regime_list, 1):
        print(f"  {i}. {r}")
    regime_choice = input("Votre régime (numéro) : ").strip()
    try:
        regime = regime_list[int(regime_choice) - 1]
        if regime == "(aucun)":
            regime = ""
    except (ValueError, IndexError):
        regime = ""

    allergen_names = sorted(a["libelle"] for a in dimensions["allergens"].values())
    print("\nAllergènes disponibles :")
    for i, a in enumerate(allergen_names, 1):
        print(f"  {i:2}. {a}")
    print("  Numéros séparés par des virgules (ou Entrée pour aucun)")
    allergy_input = input("Vos allergies : ").strip()

    allergies = []
    if allergy_input:
        try:
            indices  = [int(x.strip()) - 1 for x in allergy_input.split(",")]
            allergies = [allergen_names[i] for i in indices if 0 <= i < len(allergen_names)]
        except (ValueError, IndexError):
            pass

    profile = {
        "id":       f"profile_{name.lower().replace(' ', '_')}",
        "name":     name,
        "regime":   regime,
        "allergies": allergies,
    }
    existing.append(profile)
    profiles_data["profiles"] = existing
    save_profiles(profiles_data)
    print(f"\nProfil créé pour {name} !")
    return profile

# ─── Main ─────────────────────────────────────────────────────────────────────

def main():
    # Ensure UTF-8 output on Windows terminals
    import sys, io
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    if hasattr(sys.stdin, "reconfigure"):
        sys.stdin.reconfigure(encoding="utf-8")

    print("\nChargement de la base de recettes...", end=" ", flush=True)
    recipe_db, dimensions = build_recipe_db()
    print(f"{len(recipe_db)} recettes chargées.")

    profiles_data = load_profiles()
    profile       = select_or_create_profile(profiles_data, dimensions)
    pool          = profile_filter(recipe_db, profile)

    allergies_str = ", ".join(profile.get("allergies", [])) or "aucune"
    print(f"\n  Régime : {profile.get('regime') or '—'}  |  Allergies : {allergies_str}")
    print(f"  {len(pool)} recettes compatibles avec votre profil.")
    print("\nTapez 'aide' pour voir les commandes disponibles.")
    print("-" * 55)

    session = Session(pool, profile)

    while True:
        try:
            user_input = input("\nVous : ").strip()
        except (EOFError, KeyboardInterrupt):
            print("\nChefBot : Bon appétit ! À bientôt !")
            break

        if not user_input:
            continue

        response = generate_response(user_input, session)

        if response == "QUIT":
            print("ChefBot : Bon appétit ! À bientôt !")
            break

        print(f"\nChefBot :\n{response}")
        print("-" * 55)

if __name__ == "__main__":
    main()
