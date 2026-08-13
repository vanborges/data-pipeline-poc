"""Testes Python (pytest) — testam o CÓDIGO da ingestão.

Complementares aos testes do dbt:
    pytest    -> o código se comporta como esperado?
    dbt test  -> os DADOS respeitam as regras declaradas?
"""

import pandas as pd

from src import ingest
from src.config import DATA_BRONZE_PATH, DATA_RAW_PATH


def test_ingest_processos_gera_parquet():
    """A ingestão de processos deve criar o arquivo Parquet no Bronze."""
    ingest.ingest_processos()
    assert (DATA_BRONZE_PATH / "processos.parquet").exists()


def test_bronze_preserva_todas_as_linhas_da_origem():
    """Bronze preserva a origem: mesma quantidade de linhas do CSV."""
    ingest.ingest_processos()
    origem = pd.read_csv(DATA_RAW_PATH / "processos.csv", dtype=str)
    bronze = pd.read_parquet(DATA_BRONZE_PATH / "processos.parquet")
    assert len(bronze) == len(origem)


def test_bronze_tem_metadado_de_ingestao():
    """Toda tabela Bronze carrega a coluna técnica _ingerido_em."""
    ingest.ingest_comarcas()
    bronze = pd.read_parquet(DATA_BRONZE_PATH / "comarcas.parquet")
    assert "_ingerido_em" in bronze.columns


# TODO (desafio): depois de implementar ingest_movimentacoes(),
#   escreva um teste que verifique a criação de movimentacoes.parquet
#   e a presença das colunas processo_id, tipo_movimento e data_movimento.
