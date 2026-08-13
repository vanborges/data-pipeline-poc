# PoC — A Jornada do Dado: do sistema transacional à decisão

Prova de conceito da disciplina **Gestão e Governança de Dados** (Especialização em Engenharia de Software Inteligente · FACOM/UFMS).

Na aula anterior, estudamos conceitualmente a jornada `Fonte → Ingestão → Armazenamento → Transformação → Serving → Consumo`. Aqui, essa jornada deixa de ser um desenho e vira um pipeline que você executa e completa.

## A pergunta de negócio

> **Qual é o tempo médio de tramitação por comarca, classe e período?**

Uma pergunta simples de enunciar. Todo o projeto existe para respondê-la de forma **confiável e reproduzível** — e você vai descobrir que isso exige a jornada inteira.

## O problema

Os dados de que precisamos estão espalhados em fontes diferentes de um Tribunal de Justiça fictício — CSVs e JSON, como se tivessem sido exportados de sistemas distintos — e **contêm problemas reais de qualidade**: datas em formatos misturados, registros duplicados, identificadores órfãos, grafias inconsistentes. Nada aqui está perfeito de propósito.

## Arquitetura

```text
FONTES            CSV / JSON            (data/fontes_poc)
  ↓
INGESTÃO          Python + Pandas       (src/)
  ↓
BRONZE            Parquet               (data/bronze)
  ↓
TRANSFORMAÇÃO     dbt + DuckDB          (dbt/)
  ↓
SILVER            limpos, tipados, integrados
  ↓
GOLD              modelo analítico (fato + dimensões)
  ↓
SERVING           DuckDB                (data/analytics.duckdb)
  ↓
CONSUMO           SQL / indicadores
```

Detalhes e diagrama em [`docs/architecture.md`](docs/architecture.md).

### Quem faz o quê

| Tecnologia | Responsabilidade | O que NÃO faz aqui |
|---|---|---|
| **Python + Pandas** | Ler as fontes e persistir o Bronze (ingestão) | Regra de negócio |
| **Parquet** | Armazenamento colunar do Bronze | — |
| **DuckDB** | Engine analítico local (consulta Parquet, executa o dbt) | Servidor de banco |
| **dbt** | Transformação declarativa: Silver, Gold, testes, docs, lineage | Ingestão |

> O dbt começa a trabalhar quando os dados **já estão disponíveis para um
> engine analítico**. Trazer os dados até lá é papel da ingestão.

### `data/fontes_poc` não é Bronze

- **`data/fontes_poc/`** — os arquivos que a origem nos entregou (versionados no repo, para a atividade).
- **`data/bronze/`** — o que o **nosso pipeline capturou e persistiu** (gerado quando você executa a ingestão), preservado o mais próximo possível da origem, com metadado de ingestão e formato eficiente.

> Nota sobre nomes: em muitas empresas a camada Bronze é chamada de **raw zone** —
> por isso evitamos batizar a pasta de origem de `raw`. Aqui, "fontes" são os
> arquivos ANTES do pipeline; Bronze é o que o pipeline capturou.

### O Medallion mora em `data/`

A pasta `data/` é o **storage** desta PoC — um mini data lake local:

```text
data/
├── fontes_poc/   # sistemas de origem (simulados)
├── bronze/       # dado capturado, próximo à origem      <- escrito pela INGESTÃO (Pandas)
├── silver/       # dado limpo, tipado, padronizado       <- escrito pelo DBT
└── gold/         # dado modelado para consumo (fato/dims) <- escrito pelo DBT
```

Todas as camadas são **arquivos Parquet** — abra as pastas depois de rodar o pipeline e o `dbt run` e veja o refinamento progressivo acontecer no disco. O DuckDB registra *views* sobre esses arquivos no `data/analytics.duckdb`: é a separação entre **armazenamento** (arquivos nas pastas) e **processamento** (o engine que os consulta) — o mesmo princípio do Lakehouse, em miniatura. Num projeto real, `data/` viraria um bucket de object storage (S3/MinIO) e nada do raciocínio mudaria.

Em produção não existiria uma pasta `fontes` no repositório: os dados chegariam por APIs, bancos e eventos. O Bronze é a **porta de entrada oficial** do pipeline.

## Estrutura do repositório

```text
data-pipeline-poc/
├── README.md
├── .gitignore            # o que NÃO vai para o Git (dados gerados, .env, artefatos)
├── .env.example          # modelo de configuração (copie para .env)
├── requirements.txt      # dependências Python do projeto
│
├── data/                 # o STORAGE da PoC (nosso mini data lake local)
│   ├── fontes_poc/       #   sistemas de origem simulados (CSV/JSON) — versionados
│   ├── bronze/           #   camada Bronze: Parquet gravado pela INGESTÃO
│   ├── silver/           #   camada Silver: Parquet gravado pelo DBT
│   ├── gold/             #   camada Gold:   Parquet gravado pelo DBT
│   └── analytics.duckdb  #   catálogo/serving do DuckDB (gerado no 1º dbt run)
│
├── src/                  # código de INGESTÃO (Python)
│   ├── config.py         #   lê o .env e centraliza caminhos (nada hardcoded)
│   ├── ingest.py         #   uma função de ingestão por fonte (Pandas -> Parquet)
│   └── pipeline.py       #   orquestrador: executa as ingestões em sequência
│
├── dbt/                  # projeto de TRANSFORMAÇÃO (dbt)
│   ├── dbt_project.yml   #   configuração do projeto (camadas, materializações)
│   ├── profiles.yml      #   conexão com o DuckDB (sem credenciais -> versionado)
│   └── models/
│       ├── sources.yml   #   declara o Bronze como fonte (source) do dbt
│       ├── silver/       #   stg_*: tipagem, limpeza, padronização (1 .sql por tabela)
│       │   └── schema.yml#   testes de qualidade da Silver
│       └── gold/         #   fato_processo + dimensões (modelo analítico)
│           └── schema.yml#   testes de qualidade da Gold
│
├── tests/                # pytest: testa o CÓDIGO da ingestão
└── docs/
    └── architecture.md   # diagrama e decisões de arquitetura
```

**Como ler essa estrutura:** `data/` é o *lugar onde os dados vivem* (storage); `src/` e `dbt/` são o *código que os move e transforma* (processamento). O dado caminha da esquerda para a direita dentro de `data/` (`fontes_poc → bronze → silver → gold`), e cada salto é feito por um pedaço de código diferente: o primeiro pela ingestão Python, os demais pelo dbt. Os arquivos `schema.yml` não movem dados — declaram **testes e documentação** sobre cada modelo.

---

## Como executar

O passo a passo completo da atividade — instalação, execução do pipeline, uso do dbt e o que você precisa implementar — está em **[`POC.md`](POC.md)**.

---

**Engenharia de Dados não existe apenas para mover arquivos ou alimentar dashboards.** Ela constrói e mantém a jornada necessária para transformar dados em informação confiável e utilizável.
