# PoC — A Jornada do Dado: do sistema transacional à decisão

Prova de conceito da disciplina **Gestão e Governança de Dados**
(Especialização em Engenharia de Software Inteligente · FACOM/UFMS).

Na aula anterior, estudamos conceitualmente a jornada
`Fonte → Ingestão → Armazenamento → Transformação → Serving → Consumo`.
Aqui, essa jornada deixa de ser um desenho e vira um pipeline que você executa e completa.

## A pergunta de negócio

> **Qual é o tempo médio de tramitação por comarca, classe e período?**

Uma pergunta simples de enunciar. Todo o projeto existe para respondê-la de
forma **confiável e reproduzível** — e você vai descobrir que isso exige a jornada inteira.

## O problema

Os dados de que precisamos estão espalhados em fontes diferentes de um
Tribunal de Justiça fictício — CSVs e JSON, como se tivessem sido exportados
de sistemas distintos — e **contêm problemas reais de qualidade**: datas em
formatos misturados, registros duplicados, identificadores órfãos, grafias
inconsistentes. Nada aqui está perfeito de propósito.

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

### Por que Parquet e não CSV?

CSV é texto: sem tipos, sem compressão, lido linha a linha. Parquet é um
formato **colunar**: guarda tipos, comprime bem e permite ler só as colunas
que a consulta precisa — exatamente o padrão de acesso analítico (varrer
milhões de linhas de poucas colunas). É também a base dos formatos de
tabela (Delta/Iceberg/Hudi) que vimos na aula do Lakehouse.

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

Todas as camadas são **arquivos Parquet** — abra as pastas depois de rodar o
pipeline e o `dbt run` e veja o refinamento progressivo acontecer no disco.
O DuckDB registra *views* sobre esses arquivos no `data/analytics.duckdb`:
é a separação entre **armazenamento** (arquivos nas pastas) e **processamento**
(o engine que os consulta) — o mesmo princípio do Lakehouse, em miniatura.
Num projeto real, `data/` viraria um bucket de object storage (S3/MinIO) e
nada do raciocínio mudaria.

Em produção não existiria uma pasta `fontes` no repositório: os dados chegariam
por APIs, bancos e eventos. O Bronze é a **porta de entrada oficial** do pipeline.

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

**Como ler essa estrutura:** `data/` é o *lugar onde os dados vivem* (storage);
`src/` e `dbt/` são o *código que os move e transforma* (processamento). O dado
caminha da esquerda para a direita dentro de `data/` (`fontes_poc → bronze →
silver → gold`), e cada salto é feito por um pedaço de código diferente:
o primeiro pela ingestão Python, os demais pelo dbt. Os arquivos `schema.yml`
não movem dados — declaram **testes e documentação** sobre cada modelo.

## Preparação do ambiente

Requisitos: **Python 3.12+** e Git.

**Linux/macOS**

```bash
git clone <url-do-repositorio>
cd data-pipeline-poc

python -m venv .venv
source .venv/bin/activate

pip install -r requirements.txt
cp .env.example .env
```

**Windows (PowerShell)**

```powershell
git clone <url-do-repositorio>
cd data-pipeline-poc

python -m venv .venv
.venv\Scripts\Activate.ps1

pip install -r requirements.txt
copy .env.example .env
```

> Por que `.env`? Configuração não fica hardcoded no código. Aqui só há
> caminhos de pastas, mas em projetos reais é onde vivem credenciais e
> endereços de serviços — por isso o `.env` **nunca** é versionado.

## Primeira execução

```bash
python -m src.pipeline
```

**O que acontece quando você roda isso:**

1. `pipeline.py` carrega a configuração (`config.py` lê o `.env`) e percorre
   a lista de etapas de ingestão, em sequência — um pipeline é, antes de
   qualquer ferramenta, uma sequência de etapas com dependências.
2. Cada `ingest_*()` lê sua fonte em `data/fontes_poc/` com Pandas,
   **tudo como texto** (tipar é interpretação — e interpretação é papel da
   Silver), acrescenta o metadado `_ingerido_em` e grava Parquet em
   `data/bronze/`.
3. Os logs contam a história: quantos registros entraram, o que foi gravado.
   É a forma embrionária de responder "como sei se meu pipeline funcionou?".
4. Uma etapa avisa que ainda não existe (`ingest_movimentacoes`) —
   **ela é sua** (desafio).

Ao final: `data/bronze/processos.parquet`, `comarcas.parquet` e
`classes.parquet` existem. O dado entrou no pipeline — o que **não**
significa que está pronto para análise.

## dbt

```bash
cd dbt
dbt debug     # confere ambiente e conexão
dbt run       # constrói Silver e Gold
dbt test      # executa as regras de qualidade (alguns testes VÃO falhar: investigue!)
```

**O que acontece no `dbt run`:**

1. O dbt lê os modelos (`.sql`) e monta a **DAG** do projeto a partir de
   `source()` e `ref()` — ninguém escreve a ordem de execução; ela é
   deduzida das dependências declaradas.
2. Para cada modelo, o dbt compila o SQL e manda o **DuckDB** executar.
   O DuckDB lê o Parquet do Bronze diretamente (veja `external_location`
   no `sources.yml`) — os dados não são "importados" para lugar nenhum.
3. Cada modelo é materializado como **Parquet** na sua camada
   (`data/silver/` ou `data/gold/` — veja o `location` no config de cada
   `.sql`), e o DuckDB registra uma *view* sobre o arquivo em
   `data/analytics.duckdb`. Abra as pastas após o `dbt run` e veja o
   refinamento acontecer no disco.

**O que acontece no `dbt test`:** cada regra declarada nos `schema.yml`
(not_null, unique, relationships...) vira uma consulta SQL que procura
violações. Teste que falha não é (necessariamente) bug do seu SQL —
é um dado violando uma expectativa. Alguns testes deste projeto **falham
de propósito** logo após o clone: eles apontam para os problemas de
qualidade que você vai tratar na Silver.

**E quem orquestra o quê?** Existem duas orquestrações aqui, de propósito:
a **ingestão** é sequenciada pelo `pipeline.py` (em produção, viraria uma
DAG de Airflow/Dagster — também Python); a **transformação** é orquestrada
pelo próprio dbt via DAG dos `ref()`. No mundo real, o orquestrador ficaria
POR CIMA dos dois: `ingestão → dbt run → dbt test`, com agendamento,
retries e alertas.

Documentação e lineage:

```bash
dbt docs generate
dbt docs serve      # abre a DAG do projeto no navegador
```

## Testes Python

```bash
pytest
```

`pytest` testa o **código** (a ingestão se comporta como esperado?).
`dbt test` testa os **dados** (eles respeitam as regras declaradas?).
São complementares — qualidade de dados vira código executável.

## Os dados

| Fonte | Formato | Conteúdo |
|---|---|---|
| `processos.csv` | CSV | Processos: ids, comarca, classe, datas de distribuição/baixa, situação |
| `movimentacoes.json` | JSON | Eventos de movimentação por processo |
| `comarcas.csv` | CSV | Cadastro de comarcas |
| `classes.csv` | CSV | Cadastro de classes processuais |

São dados **sintéticos** (~120 processos) — pequenos o suficiente para você
inspecionar no olho, imperfeitos o suficiente para justificar a Silver.

## O que vamos construir

```text
[x] Clonar e preparar o ambiente
[ ] Entender as fontes (abra os arquivos de data/fontes_poc!)
[ ] Ingerir CSV               (uma pronta, uma em aula)
[ ] Ingerir JSON              (desafio)
[ ] Inspecionar schema
[ ] Criar Bronze em Parquet
[ ] Identificar problemas de qualidade
[ ] Criar a Silver com dbt    (TODOs nos modelos stg_*)
[ ] Fazer os testes passarem  (dbt test)
[ ] Integrar os dados
[ ] Criar a Gold              (fato_processo + dimensões)
[ ] Consultar com DuckDB
[ ] Responder à pergunta de negócio
[ ] Gerar documentação e lineage (dbt docs)
```

A consulta final terá esta forma (conceitual):

```sql
select
    c.nome_comarca,
    cl.nome_classe,
    t.ano,
    avg(f.tempo_tramitacao_dias) as tempo_medio_dias
from 'data/gold/fato_processo.parquet' f
join 'data/gold/dim_comarca.parquet' c  on f.comarca_id = c.comarca_id
join 'data/gold/dim_classe.parquet'  cl on f.classe_id  = cl.classe_id
join 'data/gold/dim_tempo.parquet'   t  on f.data_distribuicao = t.data
group by 1, 2, 3
order by 1, 2, 3;
```

Repare: a consulta lê a Gold **direto do storage** — o DuckDB consulta os
Parquet sem precisar "importar" nada. (As views registradas em
`data/analytics.duckdb` usam caminhos relativos à pasta `dbt/`; se quiser
consultá-las pelo catálogo, abra o DuckDB a partir de lá.)

## Onde a Governança entra?

O dbt fornece **mecanismos técnicos que podem apoiar práticas de governança**:
documentação, lineage, testes, rastreabilidade. Mas ferramenta não governa nada
sozinha. Continuam sendo decisões organizacionais: quem é responsável por cada
dado, qual qualidade é aceitável, quem pode acessar o quê, por quanto tempo
reter, para qual finalidade usar. Você vai esbarrar nisso já na `stg_classes`:
qual grafia da classe é a "oficial"? **Quem decide?**

> Engenharia constrói o caminho. Gestão mantém o caminho funcionando.
> Governança define as regras do caminho.

## Para onde este projeto pode evoluir?

```text
Hoje:    Python + Pandas + Parquet + DuckDB + dbt   (tudo local)

Depois:  Object Storage (MinIO / S3)
             ↓
         Formato de tabela (Delta / Iceberg / Hudi)  -> ACID, time travel
             ↓
         Lakehouse
```

E, conforme surgirem requisitos: orquestração (Airflow/Dagster), catálogo,
observabilidade, controle de acesso, streaming, cloud. A arquitetura simples
desta PoC não será descartada — será **evoluída**. Os conceitos (Bronze/Silver/
Gold, testes, lineage) permanecem os mesmos.

---

**Mensagem final:** Engenharia de Dados não existe apenas para mover arquivos
ou alimentar dashboards. Ela constrói e mantém a jornada necessária para
transformar dados em informação confiável e utilizável.
