import os
from dotenv import load_dotenv

class Config:
    """
    Responsabilité unique : charger la configuration (.env)
    et exposer les variables OPENAI.
    """

    def __init__(self):
        base_dir = os.path.dirname(__file__)
        env_path = os.path.join(base_dir, ".env")
        load_dotenv(env_path)

        self.api_key = os.getenv("OPENAI_API_KEY")
        self.project_id = os.getenv("OPENAI_PROJECT_ID")

        if not self.api_key:
            raise ValueError("OPENAI_API_KEY manquant dans le fichier .env")
        if not self.project_id:
            raise ValueError("OPENAI_PROJECT_ID manquant dans le fichier .env")
