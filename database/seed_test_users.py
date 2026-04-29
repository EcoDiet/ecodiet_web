"""
Seed script — creates 5 confirmed test users in Supabase with complete profiles.

Each user is created with:
  - Supabase Auth account (email_confirm=True → login works immediately)
  - user_metadata: gender, birth_date, height, weight, goal, diet_type
  - user_regime table entry
  - user_allergene table entries
  - utilisateurs table entry

Run once (after restoring the Supabase project):
    pip install requests
    python database/seed_test_users.py

Test credentials:
    marie@ecodiet.test   / EcoDiet2024!
    jean@ecodiet.test    / EcoDiet2024!
    sophie@ecodiet.test  / EcoDiet2024!
    lucas@ecodiet.test   / EcoDiet2024!
    clara@ecodiet.test   / EcoDiet2024!
"""

import requests
import sys

# ── Config ────────────────────────────────────────────────────────────────────

SUPABASE_URL = "https://vnrcvuyhfgvinzugxftl.supabase.co"
SERVICE_KEY  = (
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
    ".eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZucmN2dXloZmd2aW56dWd4ZnRsIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MzgyMzc5NiwiZXhwIjoyMDg5Mzk5Nzk2fQ"
    ".dzjKfCBWrlmM-tgDCgyA9BxcgRLHJp_GEzSyl4_fR3s"
)
PASSWORD = "EcoDiet2024!"

HEADERS = {
    "apikey":        SERVICE_KEY,
    "Authorization": f"Bearer {SERVICE_KEY}",
    "Content-Type":  "application/json",
}

# ── Regime IDs (dim_regime) ───────────────────────────────────────────────────
# 1=carnivore  2=pescetarian  3=vegan  4=vegetarian

# ── Allergen IDs (dim_allergene) ──────────────────────────────────────────────
# 1=arachide  2=celeri  3=crustaces  4=fruits_a_coque  5=gluten
# 6=lactose  7=mollusques  8=moutarde  9=oeuf  10=poisson
# 11=sesame  12=soja  13=sulfites

# ── Full test profiles ────────────────────────────────────────────────────────
# Each entry mirrors exactly what the create_account wizard collects:
#   prenom, nom, email          → auth + utilisateurs table
#   gender, birth_date          → user_metadata (step 2)
#   height_cm, weight_kg        → user_metadata (step 2)
#   target_weight_kg            → user_metadata (step 2)
#   goal                        → user_metadata (step 3)
#   diet_type                   → user_metadata (step 4)
#   regime_id                   → user_regime table (step 4)
#   allergies                   → user_allergene table (step 5)

TEST_USERS = [
    {
        "email":            "marie@ecodiet.test",
        "prenom":           "Marie",
        "nom":              "Dupont",
        "gender":           "female",
        "birth_date":       "1995-03-12",
        "height_cm":        "166",
        "weight_kg":        "58",
        "target_weight_kg": "55",
        "goal":             "eat_healthy",
        "diet_type":        "vegetarian",
        "regime_id":        4,
        "allergies":        [6, 5],      # lactose, gluten
        "note":             "Vegetarian — lactose + gluten intolerant",
    },
    {
        "email":            "jean@ecodiet.test",
        "prenom":           "Jean",
        "nom":              "Martin",
        "gender":           "male",
        "birth_date":       "1988-07-25",
        "height_cm":        "182",
        "weight_kg":        "85",
        "target_weight_kg": "80",
        "goal":             "gain_muscle",
        "diet_type":        "omnivore",
        "regime_id":        1,
        "allergies":        [3, 7],      # crustaces, mollusques
        "note":             "Carnivore — no seafood (crustaceans + molluscs)",
    },
    {
        "email":            "sophie@ecodiet.test",
        "prenom":           "Sophie",
        "nom":              "Bernard",
        "gender":           "female",
        "birth_date":       "2000-11-08",
        "height_cm":        "170",
        "weight_kg":        "62",
        "target_weight_kg": "60",
        "goal":             "reduce_carbon",
        "diet_type":        "vegan",
        "regime_id":        3,
        "allergies":        [12, 11],    # soja, sesame
        "note":             "Vegan — soy + sesame allergy",
    },
    {
        "email":            "lucas@ecodiet.test",
        "prenom":           "Lucas",
        "nom":              "Petit",
        "gender":           "male",
        "birth_date":       "1992-05-17",
        "height_cm":        "178",
        "weight_kg":        "75",
        "target_weight_kg": "75",
        "goal":             "maintain",
        "diet_type":        "pescatarian",
        "regime_id":        2,
        "allergies":        [],
        "note":             "Pescetarian — no allergies",
    },
    {
        "email":            "clara@ecodiet.test",
        "prenom":           "Clara",
        "nom":              "Leroy",
        "gender":           "female",
        "birth_date":       "1997-09-30",
        "height_cm":        "163",
        "weight_kg":        "55",
        "target_weight_kg": "52",
        "goal":             "lose_weight",
        "diet_type":        "omnivore",
        "regime_id":        1,
        "allergies":        [1, 4],      # arachide, fruits_a_coque
        "note":             "Carnivore — peanut + tree nut allergy",
    },
]

# ── Helpers ───────────────────────────────────────────────────────────────────

def rest(method, path, **kwargs):
    url = f"{SUPABASE_URL}{path}"
    res = getattr(requests, method)(url, headers=HEADERS, **kwargs)
    return res


def create_or_get_user(u):
    """
    Create a confirmed Supabase Auth user with full metadata.
    If the email already exists, return the existing user's ID.
    Returns the UUID string or None on failure.
    """
    metadata = {
        "prenom":           u["prenom"],
        "nom":              u["nom"],
        "gender":           u["gender"],
        "birth_date":       u["birth_date"],
        "height_cm":        u["height_cm"],
        "weight_kg":        u["weight_kg"],
        "target_weight_kg": u["target_weight_kg"],
        "goal":             u["goal"],
        "diet_type":        u["diet_type"],
    }

    res = rest("post", "/auth/v1/admin/users", json={
        "email":         u["email"],
        "password":      PASSWORD,
        "email_confirm": True,          # confirmed immediately — no email needed
        "user_metadata": metadata,
    })

    if res.status_code in (200, 201):
        return res.json()["id"]

    # User already exists — find and update them
    if res.status_code == 422 or "already" in res.text.lower():
        list_res = rest("get", "/auth/v1/admin/users", params={"per_page": 200})
        if list_res.ok:
            for existing in list_res.json().get("users", []):
                if existing.get("email") == u["email"]:
                    uid = existing["id"]
                    # Update metadata + re-confirm
                    rest("put", f"/auth/v1/admin/users/{uid}", json={
                        "email_confirm": True,
                        "user_metadata": metadata,
                    })
                    return uid

    print(f"  ERROR creating auth user: {res.status_code} {res.text[:200]}")
    return None


def upsert_utilisateurs(user_id, email, nom, prenom):
    res = rest("post", "/rest/v1/utilisateurs",
               json={"user_id": user_id, "email": email, "nom": nom, "prenom": prenom},
               params={"on_conflict": "email"})
    if res.status_code not in (200, 201, 409):
        print(f"  WARN utilisateurs: {res.status_code} {res.text[:120]}")


def set_regime(user_id, regime_id):
    rest("delete", "/rest/v1/user_regime", params={"user_id": f"eq.{user_id}"})
    res = rest("post", "/rest/v1/user_regime",
               json={"user_id": user_id, "regime_id": regime_id})
    if res.status_code not in (200, 201):
        print(f"  WARN regime: {res.status_code} {res.text[:120]}")


def set_allergies(user_id, allergen_ids):
    rest("delete", "/rest/v1/user_allergene", params={"user_id": f"eq.{user_id}"})
    for aid in allergen_ids:
        res = rest("post", "/rest/v1/user_allergene",
                   json={"user_id": user_id, "allergene_id": aid})
        if res.status_code not in (200, 201):
            print(f"  WARN allergene {aid}: {res.status_code} {res.text[:120]}")


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    # Quick connectivity check
    try:
        check = requests.get(f"{SUPABASE_URL}/rest/v1/", headers=HEADERS, timeout=6)
    except Exception as e:
        print("\nERROR: Cannot reach Supabase.")
        print("  The project may be paused. Go to:")
        print(f"  https://supabase.com/dashboard/project/vnrcvuyhfgvinzugxftl")
        print("  and click 'Restore project', then re-run this script.\n")
        sys.exit(1)

    print("=" * 60)
    print("  EcoDiet — Seeding test users")
    print("=" * 60)

    for u in TEST_USERS:
        print(f"\n> {u['prenom']} {u['nom']} <{u['email']}>")
        print(f"  {u['note']}")

        user_id = create_or_get_user(u)
        if not user_id:
            print("  SKIP")
            continue

        print(f"  OK  auth id   : {user_id}")
        upsert_utilisateurs(user_id, u["email"], u["nom"], u["prenom"])
        set_regime(user_id, u["regime_id"])
        set_allergies(user_id, u["allergies"])
        print(f"  OK  regime    : {u['diet_type']} (id={u['regime_id']})")
        print(f"  OK  allergies : {u['allergies']}")
        print(f"  OK  metadata  : goal={u['goal']}, gender={u['gender']}, "
              f"height={u['height_cm']}cm, weight={u['weight_kg']}kg")

    print("\n" + "=" * 60)
    print("  All done. Login with:")
    print("=" * 60)
    for u in TEST_USERS:
        print(f"  {u['email']:<30}  {PASSWORD}")
    print()


if __name__ == "__main__":
    main()
