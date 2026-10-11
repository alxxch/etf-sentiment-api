# 📊 Smart ETF Sentiment & Market Dashboard
### *Full-Stack Multimodal Financial Intelligence Platform*

[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev/)
[![FastAPI](https://img.shields.io/badge/FastAPI-009688?style=for-the-badge&logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com/)
[![Python 3.14](https://img.shields.io/badge/Python-3.14-3776AB?style=for-the-badge&logo=python&logoColor=white)](https://python.org)
[![Google Gemini](https://img.shields.io/badge/Google%20Gemini-8E75B2?style=for-the-badge&logo=google&logoColor=white)](https://ai.google.dev/)
[![ElevenLabs](https://img.shields.io/badge/ElevenLabs-TTS-black?style=for-the-badge)](https://elevenlabs.io/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)

---

## 🌟 Demo Preview

<!-- DEMO GIF/VIDEO PLACEHOLDER -->
<p align="center">
  <img src="https://via.placeholder.com/1000x560/000000/30D158?text=INSERT+YOUR+DEMO+GIF+OR+VIDEO+HERE+(Flutter+Dark+UI+%2B+Audio+Briefing)" alt="App Demo Preview" width="100%" />
</p>
<!-- Reemplaza la imagen superior con tu GIF grabado (ej. demo.gif o video preview) -->

---

## 🎯 Resumen Ejecutivo

**Smart ETF Sentiment & Market Dashboard** es una solución financiera integral que transforma datos brutos de mercado y titulares en tiempo real en inteligencia accionable y experiencias multimodales inmersivas.

Combinando la agilidad de **FastAPI** en el backend y la elegancia minimalista de **Flutter** inspirada en el sistema de diseño **Apple Finance**, la plataforma extrae cotizaciones de los principales ETFs mundiales (`VWCE.DE`, `EUNL.DE`, `8PSG.DE`), analiza el sentimiento mediático con **Google Gemini**, y genera un **Flash Briefing** de voz sintética ultrarrealista mediante **ElevenLabs**.

---

## 🏗️ Arquitectura de la Solución

```
 ┌─────────────────────────────────────────────────────────────┐
 │                Flutter Client (iOS / Web / Desktop)         │
 │  • Apple Finance Dark Palette (#000000, #1C1C1E, #30D158)   │
 │  • Custom Radial Gauge con TweenAnimationBuilder            │
 │  • Sound Wave Visualizer & Reproductor In-Memory            │
 └──────────────────────────────┬──────────────────────────────┘
                                │ HTTP / REST (Async JSON)
                                ▼
 ┌─────────────────────────────────────────────────────────────┐
 │                   FastAPI Gateway (Uvicorn)                 │
 │  • Endpoint: GET /api/v1/sentiment/{ticker}                 │
 │  • In-Memory TTL Cache (5 min) contra Rate-Limits / 429     │
 └──────────────┬───────────────┬────────────────┬─────────────┘
                │               │                │
                ▼               ▼                ▼
     ┌────────────────┐  ┌─────────────┐  ┌──────────────┐
     │  Yahoo Finance │  │Google Gemini│  │  ElevenLabs  │
     │    Scraper     │  │  LLM Flash  │  │   TTS v2     │
     │  (yfinance)    │  │ Structured  │  │(Base64 Audio)│
     └────────────────┘  └─────────────┘  └──────────────┘
```

---

## 🚀 Características Principales (Key Engineering Highlights)

1. **Arquitectura Tolerante a Fallos & Circuit Breakers:**
   - **Caché en Memoria con TTL de 5 minutos:** Previene el agotamiento de cuotas y bloqueos por `ResourceExhausted` (HTTP 429) tanto en Gemini como en ElevenLabs.
   - **Fallback Heurístico de Noticias:** Si un ETF carece de titulares directos en Yahoo Finance, el scraper resuelve los índices subyacentes (*MSCI World, FTSE All-World, Gold*) y normaliza la respuesta sin fallos 500.

2. **Sanitación Estricta de Contratos JSON:**
   - El modelo de IA está configurado con `response_mime_type: application/json` y validado mediante expresiones regulares y esquemas Pydantic, garantizando un score entre `0` y `100` y resúmenes concisos.

3. **Experiencia Multimodal ("Flash Briefing"):**
   - Transmisión de voz generativa en Base64 sin almacenamiento intermedio en disco. Decodificación instantánea en memoria en Flutter con `BytesSource` y visualizador de ondas animado en tiempo real.

4. **Diseño Apple Finance & Animaciones Implícitas:**
   - Paleta de alto contraste: Fondo negro absoluto (`#000000`), tarjetas oscuras (`#1C1C1E`), acentos verde alcista (`#30D158`) y rojo bajista (`#FF453A`).
   - Medidor radial interactivo pintado con `CustomPainter` y animado suavemente mediante `TweenAnimationBuilder` con curvas cúbicas.

---

## 🛠️ Stack Tecnológico

| Capa | Tecnologías |
| :--- | :--- |
| **Frontend** | Flutter 3.x, Dart 3.x, Provider (State Management), AudioPlayers, CustomPainter |
| **Backend** | Python 3.14, FastAPI, Uvicorn, Pydantic v2, Python-dotenv |
| **Fintech Data** | yfinance (Yahoo Finance Market Data API) |
| **IA & LLMs** | Google Gemini (Gemini 2.5 Flash / Flash Latest) |
| **Síntesis de Voz**| ElevenLabs API (Multilingual Neural TTS - Base64 Streaming) |

---

## ⚙️ Guía de Puesta en Marcha (Local Setup)

### 1. Clonar el repositorio
```bash
git clone https://github.com/tu-usuario/etf-sentiment-api.git
cd etf-sentiment-api
```

### 2. Configurar el Backend (FastAPI)

1. Ve a la carpeta `backend/` y crea tu entorno virtual:
   ```bash
   cd backend
   python -m venv venv
   # En Windows:
   .\venv\Scripts\activate
   # En Linux/macOS:
   source venv/bin/activate
   ```

2. Instala las dependencias:
   ```bash
   pip install -r requirements.txt
   ```

3. Crea un archivo `.env` en `backend/.env` con tus claves de API:
   ```env
   GEMINI_API_KEY=tu_gemini_api_key_aqui
   ELEVENLABS_API_KEY=tu_elevenlabs_api_key_aqui
   ```
   *(Nota: Si no se configuran las claves, el sistema cuenta con fallbacks elegantes para continuar funcionando en modo degradado).*

4. Inicia el servidor de desarrollo Uvicorn:
   ```bash
   uvicorn main:app --reload --port 8000
   ```
   > El servidor estará activo en `http://localhost:8000` y la documentación interactiva Swagger en `http://localhost:8000/docs`.

---

### 3. Configurar el Frontend (Flutter)

1. Abre una nueva terminal y navega a `frontend/`:
   ```bash
   cd frontend
   ```

2. Descarga los paquetes:
   ```bash
   flutter pub get
   ```

3. Ejecuta la aplicación en tu navegador o emulador:
   ```bash
   # Para probar en navegador Chrome:
   flutter run -d chrome

   # O para emulador Android / Windows Desktop:
   flutter run
   ```

---

## 📡 Especificación de la API REST

### `GET /api/v1/sentiment/{ticker}`
Obtiene la cotización en tiempo real, variación diaria, titulares analizados, puntuación de sentimiento (0-100), resumen de IA y audio en Base64.

#### Ejemplo de Respuesta:
```json
{
  "ticker": "VWCE.DE",
  "current_price": 134.50,
  "change_percent": 0.42,
  "currency": "EUR",
  "sentiment_score": 75,
  "ai_summary": "Sentimiento optimista respaldado por resultados sólidos en el sector tecnológico global.",
  "news": [
    "Global markets rally amid tech sector earnings strength",
    "European ETFs absorb record inflows in Q1"
  ],
  "audio_base64": "UklGRi4AAABXQVZFZm10IBAAAAABAAEA...",
  "cached": false
}
```

### `DELETE /api/v1/cache`
Limpia la memoria caché en caso de requerir invalidación manual inmediata.

---

## 🧪 Verificación y Tests

Para ejecutar la suite de pruebas del frontend:
```bash
cd frontend
flutter analyze
flutter test
```

---

## 👨‍💻 Autor

Desarrollado como proyecto de alta fidelidad para portfolio de ingeniería de software e inteligencia artificial multimodal.

- **LinkedIn:** [Tu Perfil](https://www.linkedin.com)
- **GitHub:** [Tu GitHub](https://github.com)
