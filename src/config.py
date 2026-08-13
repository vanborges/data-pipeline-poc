"""Configuração central do projeto.

Por que isso existe?
    Caminhos e parâmetros NÃO ficam espalhados/hardcoded no código.
    Eles vêm do arquivo .env (que cada pessoa cria localmente a partir
    do .env.example). Assim o mesmo código roda em qualquer máquina —
    só a configuração muda. Em projetos reais, é aqui que entrariam
    credenciais, hosts de banco, buckets etc.
"""

import os
from pathlib import Path

from dotenv import load_dotenv

# Raiz do projeto = pasta que contém src/
PROJECT_ROOT = Path(__file__).resolve().parents[1]

# Carrega variáveis do arquivo .env (se existir)
load_dotenv(PROJECT_ROOT / ".env")

DATA_FONTES_PATH = PROJECT_ROOT / os.getenv("DATA_FONTES_PATH", "data/fontes_poc")
DATA_BRONZE_PATH = PROJECT_ROOT / os.getenv("DATA_BRONZE_PATH", "data/bronze")
DUCKDB_PATH = PROJECT_ROOT / os.getenv("DUCKDB_PATH", "data/analytics.duckdb")
LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO")
