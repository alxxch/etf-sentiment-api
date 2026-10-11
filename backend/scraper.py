import re
import sys
from typing import Any, Dict, List, Optional
import yfinance as yf


def get_ticker_data(ticker_symbol: str) -> Dict[str, Any]:
    """Extrae datos de mercado y hasta 5 titulares de noticias para un ticker usando yfinance.

    Args:
        ticker_symbol: Símbolo del ticker (ej. 'VWCE.DE', 'EUNL.DE', '8PSG.DE').

    Returns:
        Diccionario con las claves:
            - ticker: str (símbolo en mayúsculas)
            - current_price: float
            - change_percent: float (variación porcentual diaria)
            - currency: str
            - news: List[str] (hasta 5 titulares)
    """
    clean_ticker = ticker_symbol.strip().upper()
    ticker = yf.Ticker(clean_ticker)

    current_price: Optional[float] = None
    change_percent: Optional[float] = None
    currency: str = "EUR"
    fund_name: Optional[str] = None

    # 1. Obtener precio actual y variación diaria desde fast_info
    try:
        fast_info = getattr(ticker, "fast_info", None)
        if fast_info:
            current_price = getattr(fast_info, "last_price", None)
            previous_close = getattr(fast_info, "previous_close", None)
            currency = getattr(fast_info, "currency", currency)

            if current_price is not None and previous_close is not None and previous_close > 0:
                change_percent = ((current_price - previous_close) / previous_close) * 100.0
    except Exception:
        pass

    # 2. Fallback a historial si fast_info no proporcionó precio o cambio
    if current_price is None or change_percent is None:
        try:
            hist = ticker.history(period="5d", interval="1d")
            if not hist.empty and len(hist) >= 1:
                current_price = float(hist["Close"].iloc[-1])
                if len(hist) >= 2:
                    prev_close = float(hist["Close"].iloc[-2])
                    if prev_close > 0:
                        change_percent = ((current_price - prev_close) / prev_close) * 100.0
                else:
                    change_percent = 0.0
        except Exception as e:
            print(f"[scraper] Info: Fallback a historial para {clean_ticker}: {e}")

    # 3. Fallback a ticker.info para completar datos faltantes y nombre
    try:
        info = ticker.info or {}
        if current_price is None:
            current_price = info.get("currentPrice") or info.get("regularMarketPrice") or info.get("navPrice")
        if change_percent is None:
            change_percent = info.get("regularMarketChangePercent")
        if currency == "EUR":
            currency = info.get("currency", currency)
        fund_name = info.get("longName") or info.get("shortName")
    except Exception:
        pass

    # Normalizar valores numéricos
    current_price = round(float(current_price), 2) if current_price is not None else 0.0
    change_percent = round(float(change_percent), 2) if change_percent is not None else 0.0

    # 4. Extracción de titulares de noticias (hasta 5)
    news_titles: List[str] = []

    def _extract_titles(items: list):
        for item in items:
            title = None
            if isinstance(item, dict):
                title = item.get("title")
                if not title and isinstance(item.get("content"), dict):
                    title = item["content"].get("title")
            if title and isinstance(title, str):
                cleaned_title = title.strip()
                if cleaned_title and cleaned_title not in news_titles:
                    news_titles.append(cleaned_title)
            if len(news_titles) >= 5:
                break

    # 4a. Noticias directas del ticker
    try:
        if ticker.news:
            _extract_titles(ticker.news)
    except Exception:
        pass

    # 4b. Búsqueda directa por símbolo
    if len(news_titles) < 5:
        try:
            search_ticker = yf.Search(clean_ticker)
            if search_ticker.news:
                _extract_titles(search_ticker.news)
        except Exception:
            pass

    # 4c. Búsqueda contextual basada en el activo o índice subyacente
    if len(news_titles) < 5 and fund_name:
        queries_to_try: List[str] = []

        # Detección de activos e índices conocidos
        if "gold" in fund_name.lower():
            queries_to_try.append("Gold")
        elif "msci world" in fund_name.lower():
            queries_to_try.append("MSCI World")
        elif "ftse all-world" in fund_name.lower():
            queries_to_try.append("Vanguard FTSE All-World")
        elif "s&p 500" in fund_name.lower():
            queries_to_try.append("S&P 500")

        # Nombre simplificado sin sufijos regulatorios
        clean_name = re.sub(
            r"\b(UCITS|ETF|USD|Acc|Accumulation|ETC|PLC|Dist|DR|O)\b",
            "",
            fund_name,
            flags=re.IGNORECASE,
        )
        clean_name = re.sub(r"[()\-]", " ", clean_name)
        clean_name = re.sub(r"\s+", " ", clean_name).strip()
        if clean_name and clean_name not in queries_to_try:
            queries_to_try.append(clean_name)

        for q in queries_to_try:
            if len(news_titles) >= 5:
                break
            try:
                search_q = yf.Search(q)
                if search_q.news:
                    _extract_titles(search_q.news)
            except Exception:
                pass

    # 4d. Fallback descriptivo si no hubo noticias
    if not news_titles:
        news_titles = [
            f"Sin noticias específicas recientes publicadas para {clean_ticker} en Yahoo Finance.",
            "Mercado ETF en seguimiento regular de cotizaciones y flujo de capitales globales."
        ]

    return {
        "ticker": clean_ticker,
        "current_price": current_price,
        "change_percent": change_percent,
        "currency": currency,
        "news": news_titles[:5]
    }


if __name__ == "__main__":
    test_tickers = [sys.argv[1]] if len(sys.argv) > 1 else ["VWCE.DE", "EUNL.DE", "8PSG.DE"]
    for t in test_tickers:
        print(f"\n==================== {t} ====================")
        res = get_ticker_data(t)
        print(f"Ticker: {res['ticker']}")
        print(f"Precio: {res['current_price']} {res['currency']}")
        print(f"Variación: {res['change_percent']}%")
        print(f"Titulares ({len(res['news'])}):")
        for i, h in enumerate(res["news"], 1):
            print(f"  {i}. {h}")
