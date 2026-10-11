import os
import google.generativeai as genai
from dotenv import load_dotenv

# Forzar la carga del .env en la carpeta actual
load_dotenv(dotenv_path=os.path.join(os.path.dirname(__file__), ".env"))

api_key = os.getenv("GEMINI_API_KEY")
print(f"API Key leída: {'SÍ (Empieza por ' + api_key[:5] + '...)' if api_key else 'NO'}")

if api_key:
    genai.configure(api_key=api_key)
    try:
        print("\nModelos disponibles para tu API Key:")
        for m in genai.list_models():
            if 'generateContent' in m.supported_generation_methods:
                print(f" - {m.name}")
    except Exception as e:
        print(f"\nError de conexión: {e}")