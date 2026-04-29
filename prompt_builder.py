class RecipePromptBuilder:
    """
    Construit un prompt propre selon les ingrédients et les contraintes.
    """

    @staticmethod
    def build_prompt(ingredients: str, contraintes: str | None = None) -> str:
        prompt = f"""
L'utilisateur possède les ingrédients suivants : {ingredients}.

Ta mission : proposer UNE seule recette faisable en cuisine maison.
Utilise autant que possible ces ingrédients.
Tu peux ajouter sel, poivre, huile, eau, herbes simples si indispensable.

Respecte strictement ce format :

NOM DE LA RECETTE :
...

INGRÉDIENTS (pour X personnes) :
- ...

ÉTAPES :
1. ...
2. ...
3. ...

TEMPS APPROXIMATIF :
... minutes

DIFFICULTÉ :
facile / moyen / difficile

ASTUCE DU CHEF :
Une astuce ou variante utile.
"""

        if contraintes:
            prompt += f"\nContraintes à respecter : {contraintes}"

        return prompt
