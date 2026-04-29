from config import Config
from llm_client import OpenAILLMClient
from recipe_service import RecipeService

class CLIApp:
    """
    Interface en ligne de commande pour l'application Recettes.
    """

    def __init__(self):
        config = Config()
        llm_client = OpenAILLMClient(
            api_key=config.api_key,
            project_id=config.project_id,
        )
        self.recipe_service = RecipeService(llm_client)

    def run(self):
        print("=== Générateur de Recettes (LLM) ===")
        ingredients = input("Ingrédients disponibles : ")
        contraintes = input("Contraintes (optionnel) : ")

        print("\nGénération de la recette...\n")
        recette = self.recipe_service.generate_recipe(ingredients, contraintes)

        print("=== RECETTE PROPOSÉE ===\n")
        print(recette)
