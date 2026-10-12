# 📊 Plan de Desarrollo: Smart Market Sentiment & ETF Dashboard

## 🎯 Visión General del Proyecto
Aplicación full-stack que combina extracción de datos financieros, análisis de sentimiento mediante IA (LLM), síntesis de voz hiperrealista y una interfaz móvil/web ultra-minimalista. Orientado a demostrar habilidades en integración de APIs, diseño UI/UX y arquitectura de software para el portfolio de LinkedIn.

## 🛠 Stack Tecnológico (v1.0 - v4.0)
*   **Backend:** Python 3.10+, FastAPI, `yfinance`, `google-genai` (Gemini 2.5 con Function Calling / Tools), `elevenlabs` (TTS), Uvicorn, PostgreSQL 16, SQLAlchemy, Alembic, Celery, Redis.
*   **Frontend:** Flutter (Dart), Provider (Gestor de estado), `speech_to_text` / captura de micrófono, `http` (Peticiones), `fl_chart` (Gráficos históricos y de tarta), `audioplayers`.
*   **Diseño:** Minimalismo "Apple Finance" (Fondo `#000000`, Superficie `#1C1C1E`, Acentos `#30D158` / `#FF453A`, Gráficas `#0A84FF` / `#FFD60A`).
*   **DevOps / Infraestructura:** Docker & Docker Compose (`db`, `redis`, `backend`, `celery_worker`).

---

## 🗺️ Mapa de Versiones (Roadmap)

### 📌 v1.0: "Weekend MVP" (Completado)
*Arquitectura Stateless (Sin Base de Datos).*
- [x] Backend FastAPI que consulta `yfinance` y Gemini en tiempo real.
- [x] Frontend Flutter de una sola pantalla con 3 tickers fijos (`VWCE.DE`, `EUNL.DE`, `8PSG.DE`).
- [x] UI con indicador radial de sentimiento y resumen de IA en texto.

### 📌 v1.5: "Flash Briefing" (Completado)
*El "efecto Wow" para LinkedIn con Text-to-Speech.*
- [x] Backend conectado a la API de ElevenLabs para narrar el resumen de Gemini.
- [x] Frontend con reproductor de audio integrado y animaciones de reproducción.

### 📌 v2.0: "Data Persistence" (Completado)
*Arquitectura Stateful & Automatizada.*
- [x] Integración de base de datos PostgreSQL con SQLAlchemy y Alembic (`etf_history`).
- [x] Automatización con Celery, Redis y Celery Beat (scraping al cierre de mercado 18:00 CET).
- [x] Despliegue en contenedores Docker (Backend, PostgreSQL, Redis, Celery Worker).
- [x] Gráficos históricos de sentimiento en Flutter con `fl_chart`.

### 📌 v3.0: "Simulador de Portfolio y Planes de Ahorro Automatizados" (Completado)
*Fintech, Dollar Cost Averaging (DCA) y Correlación Sentimiento-Rentabilidad.*
- [x] Arquitectura de datos Fintech en PostgreSQL (`User`, `Portfolio`, `Transaction`, `SavingsPlan`).
- [x] Lógica de simulación DCA con distribución porcentual entre renta variable (ETFs) y oro físico (`8PSG.DE`).
- [x] Endpoints en FastAPI para cálculo de valor temporal de cartera, ROI/P&L y correlación cruzada con curvas históricas de `sentiment_score`.
- [x] Pantalla "Mi Cartera" en Flutter con gráficos circulares (`PieChart` de `fl_chart`), configuración de ahorro mensual y métricas clave de rentabilidad.

### 📌 v4.0: "Asistente Financiero Bidireccional" (Objetivo Actual)
*Voz Total: Captura de voz (STT), Function Calling con Gemini y síntesis de respuesta multimodal.*
- [x] Integración de Speech-to-Text (STT) en Flutter con interfaz interactiva ("Escuchando...").
- [x] Procesamiento de lenguaje natural y Function Calling con Gemini en el backend para interpretar intenciones financieras.
- [x] Orquestación con PostgreSQL y servicios Fintech / DCA para ejecutar acciones y consultas vía voz.
- [ ] Bucle multimodal de respuesta integrando datos estructurados y síntesis de audio con ElevenLabs.

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
- [x] 2.4 Pruebas del Backend.
  - [x] Levantar servidor: `uvicorn main:app --reload`.
  - [x] Probar en `http://localhost:8000/docs` con el ticker `VWCE.DE`.

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

- [x] 6.1 Manejo de Excepciones (timeouts de IA, falta de noticias).
  - [x] ¿Qué pasa si `yfinance` no encuentra noticias? (Fijar un mensaje por defecto).
  - [x] ¿Qué pasa si Gemini da timeout? (Manejo de errores en la UI).
- [x] 6.2 Pulido de UI/UX (animaciones implícitas y contrastes):
  - [x] Añadir animaciones implícitas (`AnimatedContainer`, `TweenAnimationBuilder` para el medidor radial).
  - [x] Revisar contrastes y espaciados (Padding estándar de 16px o 24px).
- [x] 6.3 Documentación de Portfolio:
  - [x] Escribir un `README.md` estelar en el repositorio con Gifs de la app funcionando.
  - [x] Grabar video de demostración mostrando la interfaz y reproduciendo el audio del "Flash Briefing".

  ---

## 🚀 Versión 2.0: Persistencia de Datos y Arquitectura Contenedorizada ("Data Persistence")
**Objetivo:** Evolucionar la plataforma hacia una arquitectura contenerizada y con base de datos relacional para trazabilidad histórica de cotizaciones y sentimiento.

### Fase 7: Infraestructura de Persistencia y Dockerización (Día 8)
- [x] 7.1 Dockerización Inicial:
  - [x] Crear `docker-compose.yml` en la raíz con servicios `db` (PostgreSQL 16) y `backend` (FastAPI).
  - [x] Crear `backend/Dockerfile` optimizado (`python:3.11-slim`) y `backend/.dockerignore`.
  - [x] Configuración de volúmenes persistentes y healthchecks de conexión en `docker-compose.yml`.
- [x] 7.2 Dependencias y Migración de SDK:
  - [x] Migrar de `google-generativeai` deprecado al nuevo SDK oficial `google-genai`.
  - [x] Refactorizar `ai_service.py` con `client = genai.Client()`, `client.models.generate_content(...)` y manejo de cuotas 429.
  - [x] Añadir `psycopg2-binary`, `sqlalchemy` y `alembic` a `backend/requirements.txt` e instalarlas en el entorno virtual.
- [x] 7.3 Configuración de SQLAlchemy:
  - [x] Crear `backend/db/database.py` (motor, sesión `SessionLocal`, base declarativa y dependency `get_db`).
  - [x] Crear `backend/db/models.py` con el modelo `EtfHistory` (ticker, price, change_percent, sentiment_score, ai_summary, timestamp).
  - [x] Crear `backend/db/__init__.py` para exportación modular.
- [x] 7.4 Migraciones con Alembic y Persistencia en Endpoints:
  - [x] Inicializar entorno de Alembic (`alembic init alembic`) y generar migración inicial.
  - [x] Aplicar migración a PostgreSQL (`alembic upgrade head`) para crear la tabla `etf_history`.
  - [x] Integrar guardado automático de consultas en `EtfHistory` en `backend/main.py`.
  - [x] Implementar endpoint `GET /api/v1/history/{ticker}` para consultar datos históricos.
- [x] 7.5 Automatización con Celery, Redis y Cron Beat:
  - [x] Añadir servicios `redis` (Redis Alpine) y `celery_worker` a `docker-compose.yml`.
  - [x] Configurar `celery_app.py` con broker/backend Redis y timezone CET (`Europe/Madrid`).
  - [x] Crear tarea periódica `tasks.analyze_daily_market` en `backend/tasks.py` para iterar sobre los ETFs y persistir en PostgreSQL.
  - [x] Configurar Celery Beat crontab (18:00 CET de lunes a viernes, cierre del mercado europeo).
  - [x] Añadir dependencias `celery` y `redis` a `requirements.txt`.

### Fase 8: Frontend v2.0 - Visualización de Histórico Temporal (Día 9)
- [x] 8.1 Cliente HTTP para Histórico (`api_service.dart`):
  - [x] Modelo `EtfHistoryEntry` y método `fetchEtfHistory(String ticker)`.
- [x] 8.2 Gestión de Estado Histórico (`etf_provider.dart`):
  - [x] Cachear y mapear historial por ticker en `_historyMap` y notificar reactivamente a la UI.
- [x] 8.3 Gráfica Temporal en Flutter con fl_chart (`widgets/history_chart_widget.dart`):
  - [x] Integrar paquete de gráficas `fl_chart` para renderizar evolución del sentimiento (0-100) en el tiempo.
  - [x] Aplicar estética Apple Finance (sin cuadrículas internas, curva suave con degradado, colores adaptativos y tooltips).
  - [x] Integrar `HistoryChartWidget` en `screens/home_screen.dart` debajo del medidor radial.

---

## 🚀 Versión 3.0: Fintech & Simulador de Portfolio ("Simulador de Portfolio y Planes de Ahorro Automatizados")
**Objetivo:** Evolucionar la plataforma a un entorno Fintech interactivo que permita simular planes de ahorro sistemáticos (Dollar Cost Averaging - DCA), gestionar carteras con asignación porcentual multiactivo (Renta Variable vs Oro) y analizar el rendimiento financiero en correlación directa con el sentimiento de mercado histórico procesado por IA.

### Fase 7: Arquitectura de Datos Fintech (Backend)
**Objetivo:** Diseñar e implementar el modelo de datos relacional para usuarios, carteras, transacciones y planes de ahorro en PostgreSQL mediante SQLAlchemy y migraciones con Alembic, junto con el motor de simulación de aportaciones periódicas (DCA).

- [x] 7.1 Modelado Relacional de Entidades Financieras (`backend/db/models.py`):
  - [x] Crear modelo `User`: identificador único (`id`), `email`, `username` y `created_at`.
  - [x] Crear modelo `Portfolio`: relación One-to-One con `User`, nombre de cartera (`name`), divisa base (`currency`, default "EUR"), capital inicial (`initial_balance`) y marcas temporales.
  - [x] Crear modelo `Transaction`: registro granular de compras y ventas de participaciones. Campos: `portfolio_id` (FK), `ticker` (ej: `VWCE.DE`, `EUNL.DE`, `8PSG.DE`), `asset_class` (`EQUITY` vs `GOLD`), `shares` (cantidad de participaciones adquiridas, `Float`), `price_per_share` (precio de ejecución), `amount_invested` (capital invertido en EUR), `fee` (comisiones estimadas), `timestamp` e indicador `is_automated` (generada por DCA).
  - [x] Crear modelo `SavingsPlan`: definición del plan de ahorro recurrente. Campos: `portfolio_id` (FK), `monthly_deposit` (aportación mensual en EUR), `frequency` (mensual/quincenal), `allocation_equity_pct` (porcentaje destinado a ETFs de renta variable, ej: 80%), `allocation_gold_pct` (porcentaje destinado a oro físico como activo refugio, ej: 20%), `is_active`, `created_at` y `updated_at`.
  - [x] Configurar relaciones ORM bidireccionales (`relationship`), índices en claves foráneas y métodos de serialización `to_dict()`.
- [x] 7.2 Migración de Esquema con Alembic (`backend/alembic`):
  - [x] Generar script de migración declarativa: `55a192de36ee_create_fintech_tables.py` para crear `users`, `portfolios`, `savings_plans` y `transactions`.
  - [x] Validar restricciones de integridad referencial, tipos de datos numéricos (`Float`), índices y claves foráneas en cascada.
  - [x] Validación y compilación SQL transaccional para PostgreSQL (`alembic upgrade head --sql`).
- [x] 7.3 Motor de Simulación de Aportaciones Periódicas DCA (`backend/services/dca_simulator.py`):
  - [x] Desarrollar lógica de simulación DCA (Dollar Cost Averaging):
    - [x] Algoritmo de calendario financiero: iteración por fechas de aportación periódica mensual/quincenal en el rango temporal seleccionado.
    - [x] Lógica de reparto porcentual: división de la aportación (`monthly_deposit`) entre la cesta de renta variable (`allocation_equity_pct` para `VWCE.DE`) y la cobertura en oro (`allocation_gold_pct` para `8PSG.DE`).
    - [x] Consulta de precios más recientes de liquidación y acumulación de participaciones (`shares = amount / price`).
    - [x] Acumulación progresiva de saldo de participaciones, capital total desembolsado y cálculo del precio medio ponderado de compra (Break-Even / Cost Basis).
- [x] 7.4 Esquemas de Validación y DTOs con Pydantic (`backend/schemas.py`):
  - [x] Definir schemas de entrada: `UserCreate`, `SavingsPlanCreate`, `SavingsPlanUpdate`, `TransactionCreate`, `DcaSimulationRequest`.
  - [x] Definir schemas de salida: `UserResponse`, `PortfolioResponse`, `PortfolioDetailResponse`, `SavingsPlanResponse`, `TransactionResponse`, `DcaSimulationResult`.
- [x] 7.5 Inicialización y Seeding de Usuario Demo (`backend/db/seed.py` e integración en `startup`):
  - [x] Script `seed_demo_user` para inyectar automáticamente el usuario demo con su Cartera y Plan de Ahorro inicial si no existen.
  - [x] Integración en el evento `@app.on_event("startup")` de `backend/main.py`.
- [x] 7.6 Batería de Pruebas Unitarias y de Integración (`backend/test_fintech_phase7.py`):
  - [x] Tests de relaciones One-to-One y One-to-Many entre User, Portfolio, SavingsPlan y Transaction.
  - [x] Tests de validación de schemas Pydantic y lógica de seeding e idempotencia.

### Fase 8: Algoritmos de Rentabilidad y Sentimiento
**Objetivo:** Desarrollar los algoritmos de analítica financiera y exponer endpoints en FastAPI para evaluar el valor de la cartera en el tiempo, calculando métricas de rentabilidad (ROI, P&L) y contrastándolas contra la curva histórica de sentimiento de mercado (`sentiment_score`) consolidada en la v2.0.

- [x] 8.1 Motor de Métricas de Rentabilidad y Rendimiento Temporal:
  - [x] Implementar algoritmo de valoración liquidativa temporal:
    - [x] Valor actual de la cartera ($V_t$): $\sum (\text{shares}_i \times \text{precio\_actual}_i) + \text{efectivo\_remanente}$.
    - [x] Desglose de capital aportado acumulado ($C_{\text{inv}}$).
    - [x] Ganancia/Pérdida absoluta ($\text{P\&L} = V_t - C_{\text{inv}}$ en EUR).
    - [x] Retorno sobre la inversión ($\text{ROI} = \frac{\text{P\&L}}{C_{\text{inv}}} \times 100\%$).
    - [x] Acumulación de participaciones y precio medio de equilibrio (Break-Even Cost Basis).
- [x] 8.2 Cruce y Correlación de Rentabilidad con la Curva de Sentimiento (`sentiment_score`):
  - [x] Diseñar algoritmo de alineación temporal: cruzar cada punto de la serie de valor del portfolio y fechas de compra DCA con el `sentiment_score` de mercado registrado en `etf_history` (v2.0).
  - [x] Generación de serie temporal enriquecida para graficar curvas dobles en Flutter: `{date, month_index, cumulative_invested, portfolio_value, pnl, roi_pct, market_sentiment_score}`.
- [x] 8.3 Endpoints REST en FastAPI (`backend/routers/fintech.py` y `backend/main.py`):
  - [x] Registro del router bajo el prefijo `/api/v1/fintech` con tags `["Fintech & Portfolio"]`.
  - [x] `GET /api/v1/fintech/portfolio`: Endpoint consolidado que devuelve estado actual de la cartera Demo (User ID 1), valoración liquidativa, desglose multiactivo (PieChart), plan de ahorro activo y transacciones.
  - [x] `GET /api/v1/fintech/portfolio/{portfolio_id}`: Consulta por identificador único de cartera.
  - [x] `POST /api/v1/fintech/simulate-dca`: Endpoint de simulación DCA retrospectiva que recibe capital inicial, aporte mensual, meses y alocación (% RV vs % Oro) y devuelve la curva temporal de crecimiento de capital y sentimiento.
  - [x] `GET /api/v1/fintech/savings-plan` y `POST /api/v1/fintech/savings-plan`: Consulta y actualización del plan de ahorro activo.
- [x] 8.4 Pruebas Unitarias y de Integración (`backend/test_fintech_phase8.py`):
  - [x] Tests unitarios y de integración con FastAPI `TestClient` (6/6 tests pasando 100%).
  - [x] Validación de schemas Pydantic y documentación Swagger OpenAPI verificada en `/docs`.

### Fase 9: Interfaz de Usuario Financiera (Flutter)
**Objetivo:** Desarrollar la experiencia de usuario financiera en Flutter implementando la pantalla "Mi Cartera", con gráficos circulares interactivos (`PieChart` de `fl_chart`), configuración dinámica de planes de ahorro mensual y visualización de métricas avanzadas (ROI, P&L) con estética Apple Finance.

- [x] 9.1 Capa de Datos y Modelos en Dart (`frontend/lib/models/` y `services/`):
  - [x] Crear `lib/models/portfolio_models.dart`:
    - [x] Clase `PortfolioStatus` (valor total, capital invertido, P&L, ROI, sentimiento ponderado).
    - [x] Clase `SavingsPlanConfig` (monto mensual, % renta variable, % oro, frecuencia).
    - [x] Clase `DcaStepPoint` y `DcaSimulationResult` (fecha, valor cartera, capital aportado, score sentimiento).
    - [x] Clase `AssetAllocationItem` (ticker, clase de activo, participaciones, precio, valor, porcentaje, P&L, ROI).
  - [x] Extender `lib/services/api_service.dart`:
    - [x] Método `Future<PortfolioStatus> fetchPortfolio()`.
    - [x] Método `Future<DcaSimulationResult> simulateDca(...)`.
    - [x] Método `Future<SavingsPlanConfig> updateSavingsPlan(...)`.
- [x] 9.2 Gestión de Estado Financiero (`frontend/lib/providers/portfolio_provider.dart`):
  - [x] Crear `PortfolioProvider` implementando `ChangeNotifier`.
  - [x] Manejo de estados reactivos: `isLoading`, `errorMessage`, datos de cartera, configuración del plan de ahorro y simulación en tiempo real.
  - [x] Métodos para actualizar sliders de distribución porcentual garantizando que la suma siempre sea exactamente 100%.
  - [x] Registrar `PortfolioProvider` en el `MultiProvider` de `lib/main.dart`.
- [x] 9.3 Gráfico de Alocación de Activos con PieChart (`frontend/lib/screens/portfolio_screen.dart`):
  - [x] Integrar `PieChart` de `fl_chart` con estilo ultra-minimalista:
    - [x] Secciones circulares en donut (`centerSpaceRadius: 46`, `radius: 25-30`) con colores corporativos Apple Finance:
      - Renta Variable Global (`VWCE.DE`): Acento azul tech (`#0A84FF`).
      - Oro Físico Cobertura (`8PSG.DE`): Acento dorado/ámbar (`#FFD60A`).
    - [x] Animaciones fluidas al tocar e interactuar con las secciones.
    - [x] Desglose interactivo con ticker, porcentaje asignado, valor monetario, participaciones y P&L.
- [x] 9.4 Tarjeta de Métricas de Rentabilidad:
  - [x] Componente visual de alto impacto con fondo `#1C1C1E` y bordes sutiles:
    - [x] Valor Total de Cartera en tipografía titular (`32px` bold).
    - [x] Capital Total Aportado e indicador de plan recurrente.
    - [x] Indicador de P&L absoluto con código de color dinámico (Verde `#30D158` si es positivo, Rojo `#FF453A` si es negativo).
    - [x] Badge de ROI porcentual (`+X.XX%` / `-X.XX%`) con icono de tendencia y score de sentimiento.
- [x] 9.5 Formulario Interactivo del Plan de Ahorro DCA:
  - [x] Sliders para aportación mensual (25€ a 1.000€).
  - [x] Sliders vinculados para balancear la alocación: mover el slider de Renta Variable ajusta automáticamente el de Oro para totalizar 100%.
  - [x] Selector rápido de horizonte temporal (3, 6, 12, 24 meses).
  - [x] Botones de acción: "Guardar Configuración" y recalcular simulación DCA interactiva.
- [x] 9.6 Desglose de Simulación y Transacciones DCA:
  - [x] Resumen del resultado DCA con capital aportado, valor final y rentabilidad estimada.
  - [x] Lista de transacciones históricas automatizadas con badges de activo, fecha y precio de ejecución.
- [x] 9.7 Pantalla "Mi Cartera" y Navegación Global (`frontend/lib/screens/portfolio_screen.dart` y `home_screen.dart`):
  - [x] Diseñar `PortfolioScreen` integrando los componentes anteriores en un layout vertical optimizado con scroll suave y pull-to-refresh.
  - [x] Barra de navegación inferior `BottomNavigationBar` en `HomeScreen` permitiendo alternar fluidamente entre "Mercado" y "Mi Cartera" preservando el estado con `IndexedStack`.

---

## 🚀 Versión 4.0: Asistente Financiero Bidireccional ("Voz Total")
**Objetivo:** Transformar la plataforma en un ecosistema conversacional financiero bidireccional por voz. El usuario podrá interactuar en lenguaje natural mediante el micrófono en Flutter, Gemini procesará la intención utilizando Function Calling (Tools) conectado a la base de datos PostgreSQL y al motor de simulación DCA (v3.0), y el sistema responderá con datos visuales actualizados en tiempo real y síntesis de voz hiperrealista mediante ElevenLabs.

### Fase 10: Captura de Voz en Flutter (Frontend)
**Objetivo:** Implementar la captura de audio en tiempo real desde el dispositivo móvil/web, integrando el reconocimiento de voz (Speech-to-Text), gestionando permisos del sistema y ofreciendo una experiencia visual fluida con indicadores dinámicos de estado ("Escuchando...", onda/halo pulsante) antes de emitir la petición al backend.

- [x] 10.1 Integración de Paquetes y Permisos del Sistema (`frontend/pubspec.yaml`, `AndroidManifest.xml`, `Info.plist`):
  - [x] Añadir dependencias `speech_to_text` y `permission_handler` a `pubspec.yaml`.
  - [x] Configurar permisos obligatorios de micrófono en Android (`android.permission.RECORD_AUDIO`, `INTERNET`, `BLUETOOTH`) y servicio en `<queries>`.
  - [x] Configurar llaves de privacidad en iOS (`NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription`).
  - [x] Solicitud proactiva de permisos en tiempo de ejecución con validación de estado.
- [x] 10.2 Componente UI del Asistente y Botón de Escucha (`frontend/lib/widgets/voice_assistant_button.dart`):
  - [x] Botón flotante FAB con estética Apple Finance (`#1C1C1E`, bordes `#38383A`, acento `#0A84FF`) integrado en el Scaffold principal para acceso global.
  - [x] Halo concéntrico animado reactivo (estilo Siri / Apple Intelligence) activo exclusivamente durante la escucha para optimizar recursos y batería.
  - [x] Tarjeta flotante superior con indicador visual de estado ("ESCUCHANDO...", "PROCESANDO...", "ERROR DE AUDIO") y transcripción en vivo en tiempo real con botón de cancelación.
- [x] 10.3 Gestor de Estado de Voz (`frontend/lib/providers/voice_provider.dart`):
  - [x] Máquina de estados completa del asistente: `idle`, `listening`, `processing`, `speaking`, `error`.
  - [x] Detección de silencios, finalización automática de locución y feedback háptico (`HapticFeedback.mediumImpact`).
  - [x] Registro global en el `MultiProvider` de `main.dart`.
- [x] 10.4 Mock de Red y Batería de Pruebas (`frontend/test/voice_test.dart`):
  - [x] Implementación del mock de red: al terminar la escucha, imprime en consola el texto capturado, simula breve procesamiento y retorna a `idle` (listo para conectar endpoint en Fase 11).
  - [x] Suite de pruebas unitarias y de widgets en `voice_test.dart` verificando transiciones de estado, renderizado UI y cancelación (10/10 tests pasando 100%).

### Fase 11: NLP y Function Calling (Backend)
**Objetivo:** Evolucionar `ai_service.py` hacia una arquitectura basada en Agentes y Function Calling (Tools) con el SDK `google-genai` (Gemini 2.5). El modelo interpretará lenguaje natural financiero ("Simula una aportación de 100 euros al oro", "¿Cómo va mi cartera?", "¿Cuál es el sentimiento del mercado?"), seleccionará dinámicamente las herramientas apropiadas y las ejecutará contra PostgreSQL y los motores analíticos de la v3.0.

- [x] 11.1 Definición de Esquemas de Herramientas / Tools (`backend/services/ai_tools.py`):
  - [x] Declaración de `get_portfolio_summary`:
    - Consulta del estado de la cartera (balance actual, capital invertido, P&L, ROI y asignación actual entre ETFs y oro físico).
  - [x] Declaración de `simulate_dca_plan`:
    - Parámetros: `monthly_deposit` (float, ej: 100.0), `months` (int, ej: 12), `allocation_equity_pct` (float, ej: 0.0), `allocation_gold_pct` (float, ej: 100.0).
    - Mapeo inteligente de entidades coloquiales (ej: "oro" -> `8PSG.DE` 100%, "mundo/global" -> `VWCE.DE` 100%).
  - [x] Declaración de `get_market_sentiment`:
    - Parámetros: `ticker` (opcional, ej: `VWCE.DE`, `8PSG.DE`).
    - Consulta del último sentimiento histórico y precio registrado en `etf_history`.
  - [x] Declaración de `update_savings_plan`:
    - Parámetros: `monthly_deposit`, `allocation_equity_pct`, `allocation_gold_pct`.
    - Modificación persistente del plan de ahorro recurrente en PostgreSQL.
- [x] 11.2 Capa de Despacho y Ejecución de Herramientas (`backend/services/tool_dispatcher.py`):
  - [x] Mapeador declarativo que conecta las llamadas `function_call` generadas por Gemini con las funciones ORM en SQLAlchemy (`models.Portfolio`, `models.SavingsPlan`, `models.Transaction`) y `dca_simulator.py`.
  - [x] Ejecución en el contexto de la base de datos (`get_db`) de forma transaccional y segura.
  - [x] Serialización estructurada de los resultados de las herramientas para reenviarlos al contexto del modelo.
- [x] 11.3 Refactorización de `ai_service.py` para Agente Financiero:
  - [x] Configurar `client.models.generate_content` con lista de `tools` disponibles y cliente `google-genai`.
  - [x] Diseñar System Prompt especializado: perfil de asesor financiero cuantitativo, respuesta en español concisa y profesional, tono Apple Finance, confirmación clara de acciones ejecutadas y métricas clave.
  - [x] Implementar bucle de resolución de llamadas (LLM -> Tool Request -> Tool Execution -> Tool Response -> LLM Respuesta Final) con fallback semántico determinista de alta resiliencia.
- [x] 11.4 Endpoint REST del Asistente (`backend/routers/assistant.py` y `backend/main.py`):
  - [x] Definir schemas Pydantic en `schemas.py`: `AssistantChatRequest`, `AssistantChatResponse`.
  - [x] Crear endpoint `POST /api/v1/assistant/chat` bajo el router `/api/v1/assistant`.
  - [x] Integración en la aplicación FastAPI principal y verificación en `/docs`.
- [x] 11.5 Batería de Pruebas Unitarias de NLP y Function Calling (`backend/test_assistant_phase11.py`):
  - [x] Pruebas unitarias mockeadas y de integración para comandos de consulta de cartera.
  - [x] Pruebas para simulación DCA ("aporta 100 euros al oro") con extracción numérica de montos y porcentajes.
  - [x] Validación de la extracción correcta de parámetros numéricos y clases de activo (11/11 tests pasando 100%).

### Fase 12: Bucle Multimodal de Respuesta
**Objetivo:** Cerrar el ciclo conversacional completo. El backend generará la síntesis de voz mediante ElevenLabs a partir de la respuesta natural de Gemini y devolverá un payload multimodal unificado. Flutter reproducirá el audio resultante de forma inmediata y sincronizará de forma reactiva el estado visual (gráficos circulares, métricas de rentabilidad y sliders) según las acciones financieras ejecutadas.

- [x] 12.1 Optimización y Pipeline de Síntesis de Voz (`backend/tts_service.py`):
  - [x] Adaptar la generación de audio con ElevenLabs para el texto fluido y conversacional del asistente.
  - [x] Selección estricta de la voz corporativa financiera (`voice_id="t9LRTh3y1ioN00e9wsNh"`) y modelo multilingüe (`eleven_multilingual_v2`) optimizado para español neutro.
  - [x] Codificación del audio en Base64 (`mp3_44100_128`) listo para consumo inmediato sin latencia de disco.
- [x] 12.2 Consolidación del Payload Multimodal en el Backend (`backend/routers/assistant.py` y `schemas.py`):
  - [x] Estructurar la respuesta de `POST /api/v1/assistant/chat` conteniendo:
    - `text_response`: Texto en lenguaje natural redactado por Gemini.
    - `audio_base64`: Audio sintetizado por ElevenLabs listo para reproducción.
    - `action_type`: Tipo de acción normalizada (`PORTFOLIO_QUERY`, `DCA_SIMULATED`, `SAVINGS_PLAN_UPDATED`, `MARKET_SENTIMENT_QUERY`, `GENERAL_QUERY`).
    - `action_executed`: Nombre exacto de la herramienta ejecutada.
    - `tool_args`: Argumentos cuantitativos extraídos.
    - `data_payload`: Diccionario estructurado con los datos calculados (simulación DCA completa, estado de balance, parámetros de ahorro).
- [x] 12.3 Reproducción de Audio y Sincronización Reactiva en Flutter (`frontend/lib/providers/` y `widgets/`):
  - [x] Reproducción automática del audio devuelto mediante `audioplayers` al recibir HTTP 200, transicionando la UI al estado reactivo `speaking`.
  - [x] Sincronización cruzada de estados entre `VoiceProvider` (`VoiceAssistantProvider`) y `PortfolioProvider`:
    - Inyección reactiva automática del `data_payload` ante mutaciones (`DCA_SIMULATED` o `SAVINGS_PLAN_UPDATED`), actualizando sliders de aportación y gráficos circulares (`PieChart`) en tiempo real sin interacción manual del usuario.
    - Consulta de balance (`PORTFOLIO_QUERY`) con recarga forzada y refresco visual instantáneo.
  - [x] Control interactivo de reproducción en `VoiceAssistantButton`: botón flotante dinámico con icono de altavoz animado, tarjeta de transcripción y respuesta, y capacidad de pausar o silenciar la locución al pulsar.
- [x] 12.4 Resiliencia, Manejo de Casos Límite y Experiencia Conversacional:
  - [x] Manejo de degradación elegante (Graceful Degradation): si la API de ElevenLabs sufre latencia, límite de cuota o no tiene API key, captura la excepción y retorna `audio_base64: null`, permitiendo a Flutter mostrar la respuesta textual y actualizar gráficos sin romper la experiencia conversacional.
  - [x] Suite completa de pruebas unitarias y de integración pasando 100% en backend (`test_assistant_phase12.py`) y frontend (`voice_test.dart`).

---

## 🏛️ v5.0: Open Banking & Live Broker Integration

### Fase 13: Pasarela de Open Banking & Conectividad con Brokers (Backend)
**Objetivo:** Desarrollar la arquitectura de datos, adaptadores y endpoints REST para conectar brokers reales (empezando por Trade Republic) y garantizar sincronizaciones idempotentes con prevención de transacciones duplicadas.

- [x] 13.1 Extensión del Modelo Relacional (`backend/db/models.py`):
  - [x] Modelo `BrokerAccount` (`id`, `user_id`, `broker_name`, `account_reference`, `sync_status` [PENDING, SYNCED, ERROR], `last_synced_at`).
  - [x] Actualización del modelo `Transaction`: campos `external_tx_id` (String, unique=True, index=True), `broker_fee` (Float) y `currency` (String, default="EUR").
  - [x] Migración con Alembic generada y aplicada con éxito en PostgreSQL (`0f3e6a450c98_add_broker_accounts.py`).
- [x] 13.2 Capa de Servicios y Adaptadores (`backend/services/broker_service.py`):
  - [x] Patrón Adapter con clase base abstracta `BaseBrokerAdapter`.
  - [x] Implementación `TradeRepublicAdapter` con mock estructurado de balance y últimas transacciones de ETFs/Oro físico en formato unificado.
  - [x] Servicio orquestador `sync_broker_account(account_id, db)` con verificación idempotente de `external_tx_id` para evitar duplicidades al resincronizar.
- [x] 13.3 Endpoints REST (`backend/routers/banking.py` y `schemas.py`):
  - [x] Schemas Pydantic: `BrokerAccountCreate`, `BrokerAccountResponse`, `SyncResponse`.
  - [x] `POST /api/v1/banking/link-account`: Registro y vinculación de brokers externos.
  - [x] `POST /api/v1/banking/sync/{account_id}`: Disparo de sincronización bajo demanda.
  - [x] `GET /api/v1/banking/accounts`: Listado de brokers conectados por usuario.
  - [x] Registro del router en `main.py` bajo `/api/v1/banking` con tag `["Open Banking"]`.
- [x] 13.4 Testing Exhaustivo (`backend/test_banking_phase13.py`):
  - [x] Pruebas de integración con `TestClient` para los 3 endpoints.
  - [x] Validación estricta de idempotencia: dos llamadas consecutivas a `sync` con el mismo mock registran 0 transacciones duplicadas y preservan la integridad del saldo (6/6 tests pasando 100%).

### Fase 14: Motor de Rebalanceo Inteligente y Alocación Dinámica (Backend)
**Objetivo:** Desarrollar el motor cuantitativo de rebalanceo de carteras que detecta desviaciones (Portfolio Drift) y genera directrices matemáticas para orientar la aportación mensual DCA hacia los activos rezagados sin ventas forzadas, con soporte REST y Function Calling.

- [x] 14.1 Motor Cuantitativo Puro (`backend/services/rebalance_engine.py`):
  - [x] Algoritmo `calculate_rebalance_plan` que calcula el valor actual, porcentajes reales, desviaciones porcentuales y en euros frente al objetivo del plan de ahorro.
  - [x] Algoritmo de asignación no negativa de flujo de caja para la cuota mensual: corrige desviaciones mitigando costes fiscales (sin ventas forzadas) y resuelve escenarios límite (cuando el drift supera la cuota disponible, asigna el 100% al activo rezagado).
  - [x] Función orquestadora `get_portfolio_rebalance_advice` integrada con PostgreSQL y cotizaciones de mercado.
- [x] 14.2 Integración Conversacional (`backend/services/ai_tools.py`, `tool_dispatcher.py` y `ai_service.py`):
  - [x] Declaración de la herramienta Gemini `calculate_portfolio_rebalance`.
  - [x] Enrutamiento transaccional en `tool_dispatcher.py` (`execute_calculate_portfolio_rebalance`).
  - [x] Reconocimiento de intención en `ai_service.py` y mapeo de acción `PORTFOLIO_REBALANCE` en `assistant.py`.
- [x] 14.3 Endpoints REST y Schemas (`backend/routers/fintech.py` y `schemas.py`):
  - [x] Schemas Pydantic: `AssetRebalanceItem`, `RebalanceAdviceResponse`.
  - [x] Endpoint `GET /api/v1/fintech/rebalance-advice` con soporte de parámetro opcional `custom_deposit`.
- [x] 14.4 Suite de Pruebas Matemáticas y de Integración (`backend/test_rebalance_phase14.py`):
  - [x] Pruebas unitarias de exactitud aritmética: cartera equilibrada (Drift=0%), rebalanceo completo (100%), escenario límite (100% al rezagado) y cartera vacía.
### Fase 15: Sistema Proactivo de Alertas y Notificaciones Celery (Backend)
**Objetivo:** Desarrollar el sistema proactivo de alertas y notificaciones en segundo plano mediante Celery y Celery Beat, detectando descompensaciones críticas en carteras (Portfolio Drift > 5%) y oportunidades de compra ante caídas severas de mercado (< -3%), con persistencia relacional en PostgreSQL y endpoints REST para lectura y gestión.

- [x] 15.1 Persistencia de Alertas (`backend/db/models.py` y Alembic):
  - [x] Modelo `Notification`: campos `id`, `user_id` (FK a `users.id`), `title`, `message`, `type` (Enum: `OPPORTUNITY`, `DRIFT`, `SYSTEM`), `is_read` (Boolean, default False) y `timestamp` (DateTime UTC).
  - [x] Relación bidireccional `User.notifications` con eliminación en cascada.
  - [x] Migración con Alembic generada y aplicada con éxito en PostgreSQL (`7359b188a61d_add_notifications.py`).
- [x] 15.2 Tareas Programadas Automáticas en Celery (`backend/tasks.py` y `celery_app.py`):
  - [x] Tarea `check_portfolio_drift_task`: evalúa el drift de los usuarios mediante el motor cuantitativo (`rebalance_engine.py`) y genera alertas `DRIFT` cuando la descompensación supera el umbral crítico (> 5%), con control de idempotencia para no duplicar alertas no leídas.
  - [x] Tarea `check_market_opportunities_task`: evalúa caídas bruscas en ETFs rastreados (`change_percent <= -3.0%`) y genera alertas `OPPORTUNITY` aconsejando aprovechar las rebajas con la próxima aportación DCA, también con control de idempotencia.
  - [x] Registro y programación periódica en Celery Beat (`celery_app.py`): `daily-portfolio-drift-check` (09:00 CET) y `daily-market-opportunity-check` (18:30 CET).
- [x] 15.3 Endpoints REST y Schemas (`backend/routers/notifications.py` y `schemas.py`):
  - [x] Schema Pydantic `NotificationResponse` con configuración `from_attributes=True`.
  - [x] `GET /api/v1/notifications`: Listado de notificaciones del usuario ordenadas cronológicamente de forma descendente, con soporte para filtro `unread_only` y paginación `limit`.
  - [x] `PATCH /api/v1/notifications/{id}/read`: Marcado de alerta leída (`is_read = True`).
  - [x] Registro del router en `main.py` bajo `/api/v1/notifications` con tag `["Notifications & Alerts"]`.
- [x] 15.4 Suite de Pruebas de Integración (`backend/test_notifications_phase15.py`):
  - [x] Ejecución síncrona directa de tareas Celery (sin worker) para evaluar umbrales y persistencia en BD.
  - [x] Pruebas de integración HTTP de listado y marcado de lectura con `TestClient` (9/9 tests pasando 100%).

---
*Nota: Este documento debe residir en la raíz de tu proyecto. Actualiza las casillas a medida que avances.*