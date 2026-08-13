"""Testes Python (pytest) — testam o CÓDIGO da ingestão.

Complementares aos testes do dbt:
    pytest    -> o código se comporta como esperado?
    dbt test  -> os DADOS respeitam as regras declaradas?
"""

import pandas as pd

from src import ingest
from src.config import DATA_BRONZE_PATH, DATA_FONTES_PATH


def test_ingest_processos_gera_parquet():
    """A ingestão de processos deve criar o arquivo Parquet no Bronze."""
    ingest.ingest_processos()
    assert (DATA_BRONZE_PATH / "processos.parquet").exists()


def test_bronze_preserva_todas_as_linhas_da_origem():
    """Bronze preserva a origem: mesma quantidade de linhas do CSV."""
    ingest.ingest_processos()
    origem = pd.read_csv(DATA_FONTES_PATH / "processos.csv", dtype=str)
    bronze = pd.read_parquet(DATA_BRONZE_PATH / "processos.parquet")
    assert len(bronze) == len(origem)


def test_bronze_tem_metadado_de_ingestao():
    """Toda tabela Bronze carrega a coluna técnica _ingerido_em."""
    ingest.ingest_comarcas()
    bronze = pd.read_parquet(DATA_BRONZE_PATH / "comarcas.parquet")
    assert "_ingerido_em" in bronze.columns


def test_ingest_movimentacoes_gera_parquet_com_colunas():
    """A ingestão do JSON produz Parquet com as colunas esperadas."""
    ingest.ingest_movimentacoes()
    destino = DATA_BRONZE_PATH / "movimentacoes.parquet"
    assert destino.exists()
    bronze = pd.read_parquet(destino)
    for coluna in ["processo_id", "tipo_movimento", "data_movimento"]:
        assert coluna in bronze.columns


# TODO (desafio): escreva um teste garantindo que o Bronze de movimentações
#   preserva a mesma quantidade de eventos do JSON de origem.
#   (Dica: pd.read_json na fonte e compare os tamanhos.)
