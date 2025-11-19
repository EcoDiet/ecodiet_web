from prompt_builder import RecipePromptBuilder
from llm_client import BaseLLMClient

class RecipeService:
    """
    Service métier pour générer des recettes.
    """

    def __init__(self, llm_client: BaseLLMClient):
        self.llm = llm_client

    def generate_recipe(self, ingredients: str, contraintes: str | None = None) -> str:
        prompt = RecipePromptBuilder.build_prompt(ingredients, contraintes)
        return self.llm.generate(prompt)
