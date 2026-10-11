# 📊 Plan de Desarrollo: Smart Market Sentiment & ETF Dashboard

## 🎯 Visión General del Proyecto
Aplicación full-stack que combina extracción de datos financieros, análisis de sentimiento mediante IA (LLM), síntesis de voz hiperrealista y una interfaz móvil/web ultra-minimalista. Orientado a demostrar habilidades en integración de APIs, diseño UI/UX y arquitectura de software para el portfolio de LinkedIn.

## 🛠 Stack Tecnológico (v1.0 - v1.5)
*   **Backend:** Python 3.10+, FastAPI, `yfinance`, `google-generativeai`, `elevenlabs` (v1.5), Uvicorn.
*   **Frontend:** Flutter (Dart), Provider (Gestor de estado), `http` (Peticiones), `fl_chart` (Gráficos), `audioplayers` (v1.5).
*   **Diseño:** Minimalismo "Apple Finance" (Fondo `#000000`, Acentos `#30D158` / `#FF453A`).

---

## 🗺️ Mapa de Versiones (Roadmap)

### 📌 v1.0: "Weekend MVP" (Objetivo Actual)
*Arquitectura Stateless (Sin Base de Datos).*
- [ ] Backend FastAPI que consulta `yfinance` y Gemini en tiempo real.
- [ ] Frontend Flutter de una sola pantalla con 3 tickers fijos (`VWCE.DE`, `EUNL.DE`, `8PSG.DE`).
- [ ] UI con indicador radial de sentimiento y resumen de IA en texto.

### 📌 v1.5: "Flash Briefing" (Integración Multimodal)
*El "efecto Wow" para LinkedIn con Text-to-Speech.*
- [ ] Backend conectado a la API de ElevenLabs para narrar el resumen de Gemini.
- [ ] Frontend con reproductor de audio integrado y animaciones de reproducción.

### 📌 v2.0: "Data Persistence" (Próxima Iteración)
*Arquitectura Stateful.*
- [ ] Integración de base de datos PostgreSQL.
- [ ] Tarea programada (Cron/Celery) para ejecutar el análisis al cierre del mercado.
- [ ] Despliegue en contenedores Docker (Backend + DB).
- [ ] Gráficos históricos de sentimiento en Flutter.

### 📌 v3.0: "Custom Portfolio" (Escalabilidad)
- [ ] Sistema de usuarios (Autenticación).
- [ ] Búsqueda y adición de tickers personalizados.
- [ ] Web scraping avanzado de noticias (más allá de yfinance).

---

## 🚀 FASES DE DESARROLLO

### Fase 1: Configuración del Entorno y Estructura (Día 1)
**Objetivo:** Tener los cimientos del proyecto listos.

- [x] 1.1 Crear carpeta raíz del proyecto: `mkdir etf_sentiment_dashboard && cd etf_sentiment_dashboard`
- [x] 1.2 Inicializar el backend:
  - [x] `mkdir backend && cd backend`
  - [x] Crear entorno virtual: `python -m venv venv`
  - [x] Activar entorno y crear `requirements.txt` (`fastapi`, `uvicorn`, `yfinance`, `google-generativeai`, `elevenlabs`, `python-dotenv`).
  - [x] Instalar dependencias: `pip install -r requirements.txt`
  - [x] Crear archivo `.env` (Añadir `GEMINI_API_KEY` y dejar preparado `ELEVENLABS_API_KEY`).
- [x] 1.3 Inicializar el frontend:
  - [x] En la raíz del proyecto: `flutter create frontend`
  - [x] Limpiar el `main.dart` generado por defecto.
  - [x] Añadir dependencias en `pubspec.yaml`: `provider`, `http`, `audioplayers`.

### Fase 2: Backend Core - Python & FastAPI (Día 1-2)
**Objetivo:** Un endpoint funcional que devuelva el JSON estandarizado.

- [x] 2.1 Módulo de Extracción (`scraper.py`):
  - [x] Crear función `get_ticker_data(ticker_symbol)` usando `yfinance`.
  - [x] Extraer: Precio actual y Porcentaje de cambio diario.
  - [x] Extraer: Lista de las últimas 5 noticias/titulares del ticker.
- [x] 2.2 Módulo de Inteligencia Artificial (`ai_service.py`):
  - [x] Crear prompt estricto: *"Analiza estos titulares. Devuelve SOLO un JSON con formato `{"sentiment_score": Int (0-100), "ai_summary": "String corto"}`"*.
  - [x] Crear función `analyze_sentiment(news_list)` que llame a Gemini y parsee el JSON de respuesta.
- [x] 2.3 API REST (`main.py`):
  - [x] Inicializar app FastAPI.
  - [x] Crear endpoint GET `/api/v1/sentiment/{ticker}`.
  - [x] Orquestar la lógica en el endpoint: llamar a `scraper.py` -> pasar noticias a `ai_service.py` -> unificar datos.
  - [x] Retornar el esquema JSON acordado.
- [ ] 2.4 Pruebas del Backend.
  - [ ] Levantar servidor: `uvicorn main:app --reload`.
  - [ ] Probar en `http://localhost:8000/docs` con el ticker `VWCE.DE`.

### Fase 3: Frontend Core - Flutter UI (Día 3-4)
**Objetivo:** Interfaz gráfica estática (usando datos mockeados) con el estilo visual acordado.

- [x] 3.1 Estructura de carpetas en `lib/`:
  - [x] `/models` (Clases de datos).
  - [x] `/services` (Llamadas HTTP).
  - [x] `/providers` (Gestión de estado).
  - [x] `/screens` (Pantallas).
  - [x] `/widgets` (Componentes reutilizables).
  - [x] `/theme` (Colores y tipografía).
- [x] 3.2 Definir Tema (`theme/app_colors.dart`):
  - [x] Background: `Color(0xFF000000)`
  - [x] Card/Surface: `Color(0xFF1C1C1E)`
  - [x] Bullish (Alcista): `Color(0xFF30D158)`
  - [x] Bearish (Bajista): `Color(0xFFFF453A)`
- [x] 3.3 Crear Modelo de Datos (`models/etf_data.dart`):
  - [x] Crear clase `EtfData` con el método `fromJson` basado en el contrato del backend.
- [x] 3.4 Construir Widgets UI (Mockeados):
  - [x] `EtfCardWidget`: Tarjeta que muestra Ticker, Precio y Variación (con color condicional).
  - [x] `SentimentGaugeWidget`: Medidor radial (puedes usar un `CircularProgressIndicator` personalizado o un `CustomPainter`) del 0 al 100.
  - [x] `AiSummaryWidget`: Tarjeta de texto para el resumen de Gemini.
- [x] 3.5 Ensamblar Pantalla Principal (`screens/home_screen.dart`):
  - [x] Unir los widgets en un `ListView` o `PageView` para navegar entre los 3 tickers.

### Fase 4: Integración y Gestión de Estado (Día 5)
**Objetivo:** Conectar Flutter con FastAPI de forma reactiva.

- [x] 4.1 Servicio HTTP (`services/api_service.dart`):
  - [x] Función `fetchEtfData(String ticker)` que haga GET a `http://localhost:8000/api/v1/sentiment/{ticker}`.
- [x] 4.2 Configurar Provider (`providers/etf_provider.dart`):
  - [x] Estado de carga (`isLoading`).
  - [x] Manejo de errores (`errorMessage`).
  - [x] Lista o Mapa de `EtfData`.
  - [x] Método `loadData()` que itere sobre los 3 tickers (`VWCE.DE`, `EUNL.DE`, `8PSG.DE`) y llame a la API.
- [x] 4.3 Conectar UI al Provider:
  - [x] Envolver `MyApp` en `ChangeNotifierProvider`.
  - [x] Actualizar `HomeScreen` para usar `Consumer<EtfProvider>` mostrando un *spinner* mientras carga, y los datos reales al terminar.

### Fase 5: Integración de Audio con ElevenLabs - v1.5 (Día 6)
**Objetivo:** Incorporar la síntesis de voz (Flash Briefing).

- [x] 5.1 Backend (`tts_service.py`): 
  - [x] Crear función que reciba el resumen de Gemini, llame a ElevenLabs y genere el archivo de audio.
  - [x] Actualizar el endpoint de FastAPI para devolver la URL del audio o el buffer en base64 junto con los demás datos.
- [x] 5.2 Frontend (`services/audio_service.dart`):
  - [x] Configurar `audioplayers` para manejar el stream o el archivo codificado.
- [x] 5.3 UI de Reproducción:
  - [x] Añadir un botón flotante (FAB) de "Play/Pause" minimalista en la tarjeta de resumen.
  - [x] Implementar un pequeño indicador visual animado cuando el audio esté sonando.

### Fase 6: Pulido Final y Exportación para Portfolio (Día 7)
**Objetivo:** Dejar el proyecto listo para grabar una demo de LinkedIn.

- [ ] 6.1 Manejo de Excepciones (timeouts de IA, falta de noticias).
  - [ ] ¿Qué pasa si `yfinance` no encuentra noticias? (Fijar un mensaje por defecto).
  - [ ] ¿Qué pasa si Gemini da timeout? (Manejo de errores en la UI).
- [ ] 6.2 Pulido de UI/UX (animaciones implícitas y contrastes):
  - [ ] Añadir animaciones implícitas (`AnimatedContainer`, `TweenAnimationBuilder` para el medidor radial).
  - [ ] Revisar contrastes y espaciados (Padding estándar de 16px o 24px).
- [ ] 6.3 Documentación de Portfolio:
  - [ ] Escribir un `README.md` estelar en el repositorio con Gifs de la app funcionando.
  - [ ] Grabar video de demostración mostrando la interfaz y reproduciendo el audio del "Flash Briefing".

  ---
*Nota: Este documento debe residir en la raíz de tu proyecto. Actualiza las casillas a medida que avances.*