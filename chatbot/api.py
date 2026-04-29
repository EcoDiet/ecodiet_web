"""
ChefBot REST API — Flask wrapper for the chatbot engine.
Serves as the backend for the EcoDiet Flutter web app.

Run:
    pip install flask flask-cors
    python api.py
"""

import sys
import uuid
from pathlib import Path
from flask import Flask, request, jsonify
from flask_cors import CORS

# ── Import chatbot logic from the same directory ───────────────────────────────
sys.path.insert(0, str(Path(__file__).parent))
from chatbot import build_recipe_db, profile_filter, generate_response, Session

app = Flask(__name__)
CORS(app)  # Allow cross-origin requests from the Flutter web dev server

# ── Load recipe database once on startup ──────────────────────────────────────
print("Loading recipe database...", end=" ", flush=True)
RECIPE_DB, DIMENSIONS = build_recipe_db()
print(f"{len(RECIPE_DB)} recipes loaded.")

# ── In-memory sessions: { session_id: Session } ───────────────────────────────
SESSIONS: dict = {}

# ── Endpoints ─────────────────────────────────────────────────────────────────

@app.route("/api/health", methods=["GET"])
def health():
    """Health check — used by the Flutter app to confirm the server is up."""
    return jsonify({"status": "ok", "recipes": len(RECIPE_DB)})


@app.route("/api/session/init", methods=["POST"])
def init_session():
    """
    Initialize a new chat session with a user profile.

    Body:
        {
            "profile": {
                "name": "Marie",
                "regime": "vegetarian",   // vegan|vegetarian|pescetarian|carnivore|""
                "allergies": ["gluten"]   // list of allergen libelle strings
            }
        }

    Returns:
        { "session_id": "...", "recipe_count": N }
    """
    data = request.get_json(force=True) or {}
    profile = data.get("profile", {})

    # Ensure required fields with sensible defaults
    profile.setdefault("name", "Utilisateur")
    profile.setdefault("regime", "")
    profile.setdefault("allergies", [])

    pool = profile_filter(RECIPE_DB, profile)
    session_id = str(uuid.uuid4())
    SESSIONS[session_id] = Session(pool=pool, profile=profile)

    return jsonify({"session_id": session_id, "recipe_count": len(pool)})


@app.route("/api/chat", methods=["POST"])
def chat():
    """
    Send a message and receive a response.

    Body:
        { "session_id": "...", "message": "propose-moi un dessert" }

    Returns:
        { "response": "..." }
    """
    data = request.get_json(force=True) or {}
    session_id = data.get("session_id", "")
    message = (data.get("message") or "").strip()

    if not message:
        return jsonify({"error": "Empty message"}), 400

    session = SESSIONS.get(session_id)
    if session is None:
        return jsonify({"error": "Session not found. Please call /api/session/init first."}), 404

    response = generate_response(message, session)

    # Normalize quit response to a friendly farewell
    if response == "QUIT":
        response = "Bon appétit ! À bientôt !"

    return jsonify({"response": response})


@app.route("/api/session/<session_id>", methods=["DELETE"])
def delete_session(session_id: str):
    """Remove a session from memory (optional cleanup)."""
    SESSIONS.pop(session_id, None)
    return jsonify({"status": "deleted"})


# ── Entry point ───────────────────────────────────────────────────────────────

if __name__ == "__main__":
    print("ChefBot API running on http://localhost:5000")
    app.run(host="0.0.0.0", port=5000, debug=False)
