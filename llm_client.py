from abc import ABC, abstractmethod
from openai import OpenAI


class BaseLLMClient(ABC):
    """
    Interface abstraite pour un client LLM.
    Principe SOLID : ISP + DIP
    """

    @abstractmethod
    def generate(self, prompt: str) -> str:
        pass


class OpenAILLMClient(BaseLLMClient):
    """
    Client OpenAI utilisant le système moderne de PROJECTS.
    Respecte l'interface BaseLLMClient.
    """

    def __init__(self, api_key: str, project_id: str, model: str = "gpt-4.1-mini"):
        self.client = OpenAI(api_key=api_key, project=project_id)
        self.model = model

    def generate(self, prompt: str) -> str:
        response = self.client.chat.completions.create(
            model=self.model,
            messages=[
                {
                    "role": "system",
                    "content": (
                        "Tu es un chef professionnel, créatif et pédagogue. "
                        "Tu proposes des recettes réalisables, claires et équilibrées."
                    ),
                },
                {"role": "user", "content": prompt},
            ],
            temperature=0.8,
            max_tokens=900,
        )
        return response.choices[0].message.content

