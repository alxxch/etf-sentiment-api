"""Definición de Esquemas de Herramientas (Tools / Function Declarations) para Google Gemini.
Permite a Gemini 2.5 interpretar intenciones del usuario y emitir llamadas estructuradas
para interactuar con el motor DCA, PostgreSQL y los servicios de análisis financiero.
"""
from typing import List
from google.genai import types


def get_assistant_tools() -> types.Tool:
    """Retorna el conjunto de herramientas disponibles para el Asistente Financiero."""
    declarations: List[types.FunctionDeclaration] = [
        # 1. Consulta consolidada de cartera
        types.FunctionDeclaration(
            name="get_portfolio_summary",
            description=(
                "Obtiene la valoración liquidativa actual de la cartera del usuario, "
                "incluyendo capital total aportado, valor de mercado, beneficio/pérdida (P&L), "
                "retorno de inversión (ROI%), desglose de activos (renta variable vs oro) "
                "y el plan de ahorro activo."
            ),
            parameters_json_schema={
                "type": "object",
                "properties": {},
            },
        ),

        # 2. Simulación DCA retrospectiva
        types.FunctionDeclaration(
            name="simulate_dca_plan",
            description=(
                "Ejecuta una simulación matemática de compras periódicas (Dollar Cost Averaging - DCA) "
                "a lo largo del tiempo, repartiendo la cuota mensual entre renta variable (ETFs) y oro físico. "
                "Úsalo cuando el usuario pida simular aportaciones periódicas, inversiones recurrentes "
                "o escenarios hipotéticos de ahorro sistemático (ej: 'simula 100 euros al oro', "
                "'¿qué pasaría si aporto 150€ al mes?')."
            ),
            parameters_json_schema={
                "type": "object",
                "properties": {
                    "monthly_deposit": {
                        "type": "number",
                        "description": "Monto de la aportación mensual periódica en euros (ej: 100.0, 200.0).",
                    },
                    "months": {
                        "type": "integer",
                        "description": "Número de meses a simular retrospectivamente (por defecto 6 o 12).",
                    },
                    "allocation_equity_pct": {
                        "type": "number",
                        "description": (
                            "Porcentaje asignado a renta variable / ETFs globales (VWCE.DE) entre 0 y 100. "
                            "Si el usuario pide solo oro, debe ser 0.0."
                        ),
                    },
                    "allocation_gold_pct": {
                        "type": "number",
                        "description": (
                            "Porcentaje asignado a oro físico de cobertura (8PSG.DE) entre 0 y 100. "
                            "Si el usuario pide solo oro, debe ser 100.0."
                        ),
                    },
                    "initial_capital": {
                        "type": "number",
                        "description": "Capital inicial antes de iniciar las aportaciones (por defecto 0.0).",
                    },
                },
                "required": ["monthly_deposit"],
            },
        ),

        # 3. Consulta de sentimiento de mercado y cotización
        types.FunctionDeclaration(
            name="get_market_sentiment",
            description=(
                "Consulta el sentimiento de mercado más reciente analizado por IA (0 a 100) "
                "y la última cotización de un ticker específico o del mercado general. "
                "Úsalo ante preguntas como '¿cómo está el mercado?', '¿cuál es el sentimiento del oro?', "
                "o '¿cómo cotiza el VWCE?'."
            ),
            parameters_json_schema={
                "type": "object",
                "properties": {
                    "ticker": {
                        "type": "string",
                        "description": (
                            "Símbolo del ticker a consultar (ej: 'VWCE.DE' para renta variable, "
                            "'8PSG.DE' para oro físico, o 'EUNL.DE'). Si no se especifica, se asume 'VWCE.DE'."
                        ),
                    },
                },
            },
        ),

        # 4. Actualización del plan de ahorro recurrente
        types.FunctionDeclaration(
            name="update_savings_plan",
            description=(
                "Modifica y persiste la configuración del plan de ahorro DCA del usuario en la base de datos "
                "(cambio de cuota mensual o cambio en el balance porcentual entre acciones y oro). "
                "Úsalo cuando el usuario dé una orden de cambio permanente como 'cambia mi plan a 150€ al mes' "
                "o 'ajusta mi cartera a 70% renta variable y 30% oro'."
            ),
            parameters_json_schema={
                "type": "object",
                "properties": {
                    "monthly_deposit": {
                        "type": "number",
                        "description": "Nueva aportación mensual en euros.",
                    },
                    "allocation_equity_pct": {
                        "type": "number",
                        "description": "Nuevo porcentaje destinado a renta variable (0-100).",
                    },
                    "allocation_gold_pct": {
                        "type": "number",
                        "description": "Nuevo porcentaje destinado a oro físico (0-100).",
                    },
                },
            },
        ),
    ]

    return types.Tool(function_declarations=declarations)
