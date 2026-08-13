"""Ingestão: leva os dados das FONTES (data/fontes_poc) para o BRONZE (data/bronze).

Regras desta camada:
    - Ler os arquivos de origem (CSV/JSON) com Pandas.
    - Fazer APENAS normalizações técnicas mínimas (nomes de coluna,
      metadado de ingestão). Regra de negócio NÃO entra aqui —
      limpeza, padronização e integração são papel do dbt (Silver).
    - Persistir em Parquet, preservando o dado o mais próximo
      possível de como ele chegou.

fontes = os arquivos que a origem nos entregou (versionados no repo).
bronze = o que o NOSSO pipeline capturou e persistiu (gerado ao executar).
(Evitamos o nome "raw" porque, no mercado, raw zone costuma ser sinônimo de Bronze.)
"""

import logging
from datetime import datetime, timezone

import pandas as pd

from src.config import DATA_BRONZE_PATH, DATA_FONTES_PATH

logger = logging.getLogger(__name__)


def _gravar_bronze(df: pd.DataFrame, nome: str) -> None:
    """Acrescenta metadado técnico de ingestão e grava Parquet no Bronze."""
    df = df.copy()
    df["_ingerido_em"] = datetime.now(timezone.utc).isoformat()
    DATA_BRONZE_PATH.mkdir(parents=True, exist_ok=True)
    destino = DATA_BRONZE_PATH / f"{nome}.parquet"
    df.to_parquet(destino, index=False)
    logger.info("Bronze gravado: %s (%d registros)", destino.name, len(df))


def ingest_processos() -> None:
    """[PRONTO — referência] Ingestão do CSV de processos."""
    origem = DATA_FONTES_PATH / "processos.csv"
    logger.info("Lendo %s", origem.name)
    # dtype=str => tudo chega como texto.
    # Decisão consciente: o Bronze preserva o dado como veio;
    # tipar é decisão de transformação (Silver/dbt).
    df = pd.read_csv(origem, dtype=str)
    logger.info("%d registros encontrados", len(df))
    _gravar_bronze(df, "processos")


def ingest_comarcas() -> None:
    """[PRONTO] Ingestão do CSV de comarcas."""
    origem = DATA_FONTES_PATH / "comarcas.csv"
    logger.info("Lendo %s", origem.name)
    df = pd.read_csv(origem, dtype=str)
    logger.info("%d registros encontrados", len(df))
    _gravar_bronze(df, "comarcas")


def ingest_classes() -> None:
    """[PRONTO] Ingestão do CSV de classes processuais."""
    origem = DATA_FONTES_PATH / "classes.csv"
    logger.info("Lendo %s", origem.name)
    df = pd.read_csv(origem, dtype=str)
    logger.info("%d registros encontrados", len(df))
    _gravar_bronze(df, "classes")


def ingest_movimentacoes() -> None:
    """Ingestão do JSON de movimentações."""
    origem = DATA_FONTES_PATH / "movimentacoes.json"
    logger.info("Lendo %s", origem.name)
    # read_json infere tipos; convertemos tudo para texto para manter
    # o padrão do Bronze (tipar é papel da Silver).
    df = pd.read_json(origem).astype(str)
    logger.info("%d registros encontrados", len(df))
    _gravar_bronze(df, "movimentacoes")
