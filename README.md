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
FONTES            CSV / JSON            (data/raw)
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

### `data/raw` não é Bronze

- **`data/raw/`** — os arquivos que a origem nos entregou (versionados no repo, para a atividade).
- **`data/bronze/`** — o que o **nosso pipeline capturou e persistiu** (gerado quando você executa a ingestão), preservado o mais próximo possível da origem, com metadado de ingestão e formato eficiente.

Em produção não existiria uma pasta `raw` no repositório: os dados chegariam
por APIs, bancos e eventos. O Bronze é a **porta de entrada oficial** do pipeline.

## Estrutura do repositório

```text
data-pipeline-poc/
├── README.md
├── .gitignore
├── .env.example          # modelo de configuração (copie para .env)
├── requirements.txt
├── data/
│   ├── raw/              # FONTES da atividade (versionadas)
│   └── bronze/           # gerada pelo pipeline (não versionada)
├── src/
│   ├── config.py         # configuração via .env
│   ├── ingest.py         # ingestão (Pandas -> Parquet)
│   └── pipeline.py       # orquestrador simples
├── dbt/
│   ├── dbt_project.yml
│   ├── profiles.yml      # sem credenciais -> versionado (leia o comentário!)
│   └── models/
│       ├── sources.yml   # onde o Bronze entra no mundo dbt
│       ├── silver/       # stg_*: limpeza, tipagem, padronização
│       └── gold/         # fato + dimensões (modelo analítico)
├── tests/                # pytest (testa o CÓDIGO)
└── docs/
    └── architecture.md
```

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

Você verá a ingestão criar `data/bronze/*.parquet` — e avisar que duas
etapas ainda não existem. **Elas são suas.**

## dbt

```bash
cd dbt
dbt debug     # confere ambiente e conexão
dbt run       # constrói Silver e Gold no DuckDB
dbt test      # executa as regras de qualidade (alguns testes VÃO falhar: investigue!)
```

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
[ ] Entender as fontes (abra os arquivos de data/raw!)
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
from fato_processo f
join dim_comarca c  on f.comarca_id = c.comarca_id
join dim_classe cl  on f.classe_id  = cl.classe_id
join dim_tempo t    on f.data_distribuicao = t.data
group by 1, 2, 3
order by 1, 2, 3;
```

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
