# 📊 Plan de Desarrollo: Smart Market Sentiment & ETF Dashboard

## 🎯 Visión General del Proyecto
Aplicación full-stack que combina extracción de datos financieros, análisis de sentimiento mediante IA (LLM), síntesis de voz hiperrealista y una interfaz móvil/web ultra-minimalista. Orientado a demostrar habilidades en integración de APIs, diseño UI/UX y arquitectura de software para el portfolio de LinkedIn.

## 🛠 Stack Tecnológico (v1.0 - v3.0)
*   **Backend:** Python 3.10+, FastAPI, `yfinance`, `google-genai` (Gemini 2.5), `elevenlabs`, Uvicorn, PostgreSQL 16, SQLAlchemy, Alembic, Celery, Redis.
*   **Frontend:** Flutter (Dart), Provider (Gestor de estado), `http` (Peticiones), `fl_chart` (Gráficos históricos y de tarta), `audioplayers`.
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

### 📌 v3.0: "Simulador de Portfolio y Planes de Ahorro Automatizados" (Objetivo Actual)
*Fintech, Dollar Cost Averaging (DCA) y Correlación Sentimiento-Rentabilidad.*
- [ ] Arquitectura de datos Fintech en PostgreSQL (`User`, `Portfolio`, `Transaction`, `SavingsPlan`).
- [ ] Lógica de simulación DCA con distribución porcentual entre renta variable (ETFs) y oro físico (`8PSG.DE`).
- [ ] Endpoints en FastAPI para cálculo de valor temporal de cartera, ROI/P&L y correlación cruzada con curvas históricas de `sentiment_score`.
- [ ] Pantalla "Mi Cartera" en Flutter con gráficos circulares (`PieChart` de `fl_chart`), configuración de ahorro mensual y métricas clave de rentabilidad.

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

- [ ] 7.1 Modelado Relacional de Entidades Financieras (`backend/db/models.py`):
  - [ ] Crear modelo `User`: identificador único (`id`), `email`, `username`, `hashed_password` (o UUID mock para sesión local) y `created_at`.
  - [ ] Crear modelo `Portfolio`: relación 1:N con `User`, nombre de cartera (`name`), divisa base (`currency`, default "EUR"), capital inicial (`initial_balance`) y marcas temporales.
  - [ ] Crear modelo `Transaction`: registro granular de compras y ventas de participaciones. Campos: `portfolio_id` (FK), `ticker` (ej: `VWCE.DE`, `EUNL.DE`, `8PSG.DE`), `asset_class` (`EQUITY` vs `COMMODITY_GOLD`), `shares` (cantidad de participaciones adquiridas, `Float`), `price_per_share` (precio de ejecución), `amount_invested` (capital invertido en EUR), `fee` (comisiones estimadas), `timestamp` e indicador `is_automated` (generada por DCA).
  - [ ] Crear modelo `SavingsPlan`: definición del plan de ahorro recurrente. Campos: `portfolio_id` (FK), `user_id` (FK), `monthly_deposit` (aportación mensual en EUR), `frequency` (mensual/quincenal), `allocation_equity_pct` (porcentaje destinado a ETFs de renta variable, ej: 80%), `allocation_gold_pct` (porcentaje destinado a oro físico como activo refugio, ej: 20%), `start_date`, `is_active` y `last_execution_date`.
  - [ ] Configurar relaciones ORM bidireccionales (`relationship`), índices en claves foráneas y métodos de serialización `to_dict()`.
- [ ] 7.2 Migración de Esquema con Alembic (`backend/alembic`):
  - [ ] Generar script de migración declarativa: `alembic revision --autogenerate -m "create_fintech_tables_user_portfolio_transaction_savingsplan"`.
  - [ ] Validar restricciones de integridad referencial, tipos de datos numéricos de alta precisión (`Numeric`/`Float`) y valores por defecto.
  - [ ] Aplicar migración a PostgreSQL en entorno Docker: `alembic upgrade head`.
- [ ] 7.3 Motor de Simulación de Aportaciones Periódicas DCA (`backend/services/dca_simulator.py`):
  - [ ] Desarrollar lógica de simulación DCA (Dollar Cost Averaging):
    - [ ] Algoritmo de calendario financiero: iteración por fechas de aportación periódica mensual/quincenal en el rango temporal seleccionado.
    - [ ] Lógica de reparto porcentual: división de la aportación (`monthly_deposit`) entre la cesta de renta variable (`allocation_equity_pct` dividido entre tickers de renta variable como `VWCE.DE` y `EUNL.DE`) y la cesta de cobertura en oro (`allocation_gold_pct` asignado a `8PSG.DE`).
    - [ ] Consulta y cruce con precios históricos de ejecución: recuperar precios de cierre desde `etf_history` (o fallback a `yfinance` para fechas previas) para calcular participaciones compradas (`shares = amount / price`).
    - [ ] Acumulación progresiva de saldo de participaciones, capital total desembolsado y cálculo del precio medio ponderado de compra (Break-Even / Cost Basis).
- [ ] 7.4 Esquemas de Validación y DTOs con Pydantic (`backend/schemas/portfolio.py`):
  - [ ] Definir schemas de entrada: `SavingsPlanCreateRequest`, `DcaSimulationRequest`.
  - [ ] Definir schemas de salida: `TransactionResponse`, `SavingsPlanResponse`, `PortfolioSummaryResponse`, `DcaSimulationResultResponse`.

### Fase 8: Algoritmos de Rentabilidad y Sentimiento
**Objetivo:** Desarrollar los algoritmos de analítica financiera y exponer endpoints en FastAPI para evaluar el valor de la cartera en el tiempo, calculando métricas de rentabilidad (ROI, P&L) y contrastándolas contra la curva histórica de sentimiento de mercado (`sentiment_score`) consolidada en la v2.0.

- [ ] 8.1 Motor de Métricas de Rentabilidad y Rendimiento Temporal:
  - [ ] Implementar algoritmo de valoración liquidativa temporal:
    - [ ] Valor actual de la cartera ($V_t$): $\sum (\text{shares}_i \times \text{precio\_actual}_i) + \text{efectivo\_remanente}$.
    - [ ] Desglose de capital aportado acumulado ($C_{\text{inv}}$).
    - [ ] Ganancia/Pérdida absoluta ($\text{P\&L} = V_t - C_{\text{inv}}$ en EUR).
    - [ ] Retorno sobre la inversión ($\text{ROI} = \frac{\text{P\&L}}{C_{\text{inv}}} \times 100\%$).
    - [ ] Tasa interna de retorno anualizada o rentabilidad ponderada por dinero (MWRR - Money-Weighted Rate of Return simplificado).
- [ ] 8.2 Cruce y Correlación de Rentabilidad con la Curva de Sentimiento (`sentiment_score`):
  - [ ] Diseñar algoritmo de alineación temporal: cruzar cada punto de la serie de valor del portfolio y fechas de compra DCA con el `sentiment_score` promedio de mercado registrado en `etf_history` (v2.0).
  - [ ] Métricas de análisis de comportamiento y "Timing Alpha":
    - [ ] Calcular rentabilidad media de las aportaciones ejecutadas en momentos de pánico/pesimismo (sentimiento < 40) frente a momentos de euforia/codicia (sentimiento > 70).
    - [ ] Indicador cuantitativo de correlación sentimiento-rendimiento para validar la hipótesis contraria ("Buy the Fear").
- [ ] 8.3 Endpoints REST en FastAPI (`backend/main.py`):
  - [ ] `POST /api/v1/portfolio/savings-plan`: Crear o actualizar la configuración del plan de ahorro recurrente del usuario.
  - [ ] `GET /api/v1/portfolio/savings-plan/{portfolio_id}`: Consultar la configuración vigente del plan de ahorro y distribución porcentual.
  - [ ] `POST /api/v1/portfolio/simulate-dca`: Endpoint de simulación que recibe capital mensual, horizonte temporal y distribución (% Renta Variable vs % Oro) y devuelve el desglose de compras, coste medio y evolución de balance.
  - [ ] `GET /api/v1/portfolio/{portfolio_id}/performance`: Endpoint principal de rendimiento que entrega:
    - [ ] Resumen de métricas: `current_value`, `total_invested`, `pnl_amount`, `roi_percentage`.
    - [ ] Desglose de alocación actual por activo y clase de activo (porcentajes reales vs objetivo).
    - [ ] Serie temporal para gráficos: array de puntos `{date, portfolio_value, total_invested, market_sentiment_score}`.
- [ ] 8.4 Pruebas Unitarias y de Integración:
  - [ ] Tests de cálculo financiero en `backend/tests/test_portfolio.py` para asegurar consistencia en redondeos y decimales.
  - [ ] Tests de validación de endpoints y respuestas JSON en FastAPI Docs (`/docs`).

### Fase 9: Interfaz de Usuario Financiera (Flutter)
**Objetivo:** Desarrollar la experiencia de usuario financiera en Flutter implementando la pantalla "Mi Cartera", con gráficos circulares interactivos (`PieChart` de `fl_chart`), configuración dinámica de planes de ahorro mensual y visualización de métricas avanzadas (ROI, P&L) con estética Apple Finance.

- [ ] 9.1 Capa de Datos y Modelos en Dart (`frontend/lib/models/` y `services/`):
  - [ ] Crear `lib/models/portfolio_models.dart`:
    - [ ] Clase `PortfolioSummary` (valor total, capital invertido, P&L, ROI).
    - [ ] Clase `SavingsPlanConfig` (monto mensual, % renta variable, % oro, frecuencia).
    - [ ] Clase `PortfolioPerformancePoint` (fecha, valor cartera, capital aportado, score sentimiento).
    - [ ] Clase `AssetAllocationItem` (ticker, nombre, porcentaje actual, monto en EUR, color asociado).
  - [ ] Extender `lib/services/api_service.dart`:
    - [ ] Método `Future<PortfolioSummary> fetchPortfolioSummary()`.
    - [ ] Método `Future<SavingsPlanConfig> fetchSavingsPlan()`.
    - [ ] Método `Future<bool> saveSavingsPlan(SavingsPlanConfig config)`.
    - [ ] Método `Future<List<PortfolioPerformancePoint>> fetchPortfolioPerformance()`.
    - [ ] Método `Future<Map<String, dynamic>> simulateDca(double monthlyDeposit, double equityPct, double goldPct)`.
- [ ] 9.2 Gestión de Estado Financiero (`frontend/lib/providers/portfolio_provider.dart`):
  - [ ] Crear `PortfolioProvider` implementando `ChangeNotifier`.
  - [ ] Manejo de estados reactivos: `isLoading`, `errorMessage`, datos de cartera, configuración del plan de ahorro y simulación en tiempo real.
  - [ ] Métodos para actualizar sliders de distribución porcentual garantizando que la suma siempre sea exactamente 100%.
  - [ ] Registrar `PortfolioProvider` en el `MultiProvider` de `lib/main.dart`.
- [ ] 9.3 Gráfico de Alocación de Activos con PieChart (`frontend/lib/widgets/asset_allocation_chart.dart`):
  - [ ] Integrar `PieChart` de `fl_chart` con estilo ultra-minimalista:
    - [ ] Secciones circulares en donut (`centerSpaceRadius: 40-50`) con colores corporativos Apple Finance:
      - Renta Variable Global (`VWCE.DE` / `EUNL.DE`): Acentos verde alcista (`#30D158`) y azul tech (`#0A84FF`).
      - Oro Físico Cobertura (`8PSG.DE`): Acento dorado/ámbar (`#FFD60A`).
    - [ ] Animaciones fluidas al cargar y al interactuar con las secciones.
    - [ ] Leyenda interactiva inferior con ticker, porcentaje asignado y valor monetario correspondiente.
- [ ] 9.4 Tarjeta de Métricas de Rentabilidad (`frontend/lib/widgets/portfolio_metrics_card.dart`):
  - [ ] Componente visual de alto impacto con fondo `#1C1C1E` y bordes sutiles:
    - [ ] Valor Total de Cartera en tipografía titular (`EUR XXX.XX`).
    - [ ] Capital Total Aportado (`Invertido: EUR XXX.XX`).
    - [ ] Indicador de P&L absoluto con código de color dinámico (Verde `#30D158` si es positivo, Rojo `#FF453A` si es negativo).
    - [ ] Badge de ROI porcentual (`+X.XX%` / `-X.XX%`) con icono de tendencia.
- [ ] 9.5 Formulario Interactivo del Plan de Ahorro DCA (`frontend/lib/widgets/savings_plan_form.dart`):
  - [ ] Campo numérico y chips de selección rápida de aportación mensual (ej: `100€`, `250€`, `500€`, `1.000€`).
  - [ ] Sliders vinculados para balancear la alocación: mover el slider de Renta Variable ajusta automáticamente el de Oro para totalizar 100%.
  - [ ] Botón de acción principal con retroalimentación háptica/visual: "Actualizar Plan de Ahorro" y "Ejecutar Simulación DCA".
- [ ] 9.6 Gráfico Combinado de Evolución Temporal y Sentimiento (`frontend/lib/widgets/portfolio_performance_chart.dart`):
  - [ ] Gráfico lineal avanzado (`LineChart` de `fl_chart`):
    - [ ] Curva del valor de la cartera con degradado sombreado inferior.
    - [ ] Línea de referencia del capital aportado (demostrando visualmente el efecto del interés compuesto y DCA).
    - [ ] Visualización superpuesta o tooltip sincronizado con el `sentiment_score` para identificar compras en mínimos/máximos de sentimiento.
- [ ] 9.7 Pantalla "Mi Cartera" y Navegación Global (`frontend/lib/screens/portfolio_screen.dart`):
  - [ ] Diseñar `PortfolioScreen` integrando los componentes anteriores en un layout vertical optimizado con scroll suave y pull-to-refresh.
  - [ ] Actualizar navegación principal de la app (Barra de navegación inferior `BottomNavigationBar` o pestañas superiores en `HomeScreen`) permitiendo alternar fluidamente entre "Mercado & Sentimiento" y "Mi Cartera".

---
*Nota: Este documento debe residir en la raíz de tu proyecto. Actualiza las casillas a medida que avances.*