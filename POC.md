# Roteiro de leitura da PoC

Este projeto está **completo e comentado**. Ele não é um exercício: é um pipeline funcionando, escrito para ser **lido e explicado**.

Cada arquivo traz comentários que respondem três perguntas: *o que este código faz*, *qual problema ele resolve* e *que conceito ele materializa*.

> **A pergunta que move tudo:** qual é o tempo médio de tramitação por comarca, classe e período?

---

## Executando (5 minutos)

```bash
python3 -m venv .venv && source .venv/bin/activate     # ou: conda create -n poc python=3.12
pip install -r requirements.txt
cp .env.example .env

python -m src.pipeline        # Fontes -> Bronze
cd dbt && dbt run             # Bronze -> Silver -> Gold
dbt test                      # 17 testes de qualidade
```

O que esperar:

| Comando | Resultado |
|---|---|
| `python -m src.pipeline` | 4 Parquet em `data/bronze/` (122, 8, 7 e 408 registros) |
| `dbt run` | 8 modelos: 4 Silver + 4 Gold, gravados como Parquet |
| `dbt test` | **17 passed** |
| `pytest` | **5 passed** |

---

## A ordem de leitura

Siga esta sequência — ela é a própria jornada do dado.

### 1. As fontes · `data/fontes_poc/`

Três CSVs e um JSON, como se tivessem sido exportados de sistemas diferentes do Tribunal. **Contêm problemas de propósito**: datas em dois formatos, duplicatas, identificador vazio, comarca inexistente, grafias inconsistentes.

*Pergunta para a turma:* "os dados estão todos aqui. Já conseguimos responder a pergunta?"

### 2. A ingestão · `src/ingest.py`

Lê cada fonte e grava Parquet no Bronze. Repare em duas decisões comentadas no código:

- **tudo é lido como texto** (`dtype=str`) — tipar é interpretar, e interpretar é transformar (papel da Silver);
- **compare `ingest_processos` (CSV) com `ingest_movimentacoes` (JSON)** — muda o leitor, não muda o destino. É a ingestão absorvendo a diversidade das fontes.

`src/pipeline.py` é o orquestrador: 15 linhas mostrando que um pipeline é, antes de tudo, uma sequência de etapas com dependências.

### 3. O Bronze · `data/bronze/`

O que o pipeline capturou, preservado. **Mudou o formato, não o conteúdo** — as duplicatas e as datas malformadas continuam todas lá.

Para olhar dentro de um Parquet (que é binário):

```bash
python -c "import duckdb; print(duckdb.sql(\"select * from 'data/bronze/processos.parquet' limit 5\"))"
```

*Repare no `FROM`:* no lugar do nome da tabela, um **caminho de arquivo**. Nenhum servidor, nenhum import — armazenamento e processamento separados.

### 4. A Silver · `dbt/models/silver/`

Onde o dado vira **confiável**. Leia nesta ordem:

| Modelo | O que demonstra |
|---|---|
| `stg_processos.sql` | tipagem, deduplicação e o tratamento dos **dois formatos de data** |
| `stg_comarcas.sql` | padronização de texto (as quatro grafias de "Campo Grande") |
| `stg_classes.sql` | deduplicação que exige uma **decisão de negócio** — qual grafia é a oficial? |
| `stg_movimentacoes.sql` | o dado que veio de JSON, tratado igual aos de CSV |

O `stg_classes.sql` é o mais interessante para discutir: o SQL escolhe uma grafia, mas quem *deveria* escolher é o dono do dado. É governança aparecendo dentro de um modelo dbt.

### 5. A Gold · `dbt/models/gold/`

Onde o dado ganha **forma** para responder à pergunta.

| Modelo | O que demonstra |
|---|---|
| `fato_processo.sql` | grão, medida derivada, dimensão degenerada, decisões de negócio explícitas |
| `dim_comarca.sql` | dimensão conformada + nota sobre SCD |
| `dim_classe.sql` | como um problema não tratado na Silver contaminaria a Gold |
| `dim_tempo.sql` | dimensão gerada (não vem de fonte nenhuma) e role-playing |

O `fato_processo.sql` é o coração: leia os comentários da medida `tempo_tramitacao_dias` — eles explicam por que processos em andamento ficam nulos, por que tempo negativo é descartado, e por que a medida é guardada **por processo** em vez de já agregada.

### 6. Os testes · `schema.yml` e `tests/`

- `dbt/models/*/schema.yml` — qualidade de dados como código executável
- `tests/test_ingestion.py` — testes do **código** da ingestão

O teste `relationships` (em `gold/schema.yml`) é o mais didático: em Parquet **não existe chave estrangeira**, então a integridade referencial vira verificação. A FK *impedia*; o teste apenas *detecta*.

Para ver o SQL que um teste vira:

```bash
cat dbt/target/compiled/tribunal/models/silver/schema.yml/not_null_stg_processos_processo_id.sql
```

### 7. O consumo · `consultas/analise.sql`

Cinco consultas comentadas: a pergunta oficial, a evolução por ano, a análise por vara — mais **duas armadilhas** para demonstrar ao vivo (o `group by vara_id` sozinho e o fan-out ao misturar grãos).

### 8. O lineage

```bash
cd dbt && dbt docs generate && dbt docs serve
```

A DAG do projeto no navegador, com a documentação que nasceu dos mesmos `schema.yml` que declaram os testes.

---

## Material de apoio

| Documento | Conteúdo |
|---|---|
| [`docs/architecture.md`](docs/architecture.md) | as camadas, as decisões de arquitetura e **as 5 etapas do `dbt run`** |
| [`docs/comparacao-oltp-vs-gold.md`](docs/comparacao-oltp-vs-gold.md) | a mesma pergunta no OLTP (5 tabelas, 4 joins, 1 CTE) e na Gold (2 arquivos, 1 join) |
| [`scripts/criar_esaj_simulado.py`](scripts/criar_esaj_simulado.py) | monta um e-SAJ normalizado para demonstrar a comparação acima ao vivo |

---

## Demonstrações ao vivo

**Um teste falhando.** Comente o `coalesce` da `data_distribuicao` em `stg_processos.sql` (deixando só o `try_cast`) e rode `dbt run && dbt test`. Duas datas em `DD/MM/AAAA` viram NULL e o teste `not_null` acusa. Mostra que **dado ruim quebra uma regra executável**.

**A DAG se resolvendo sozinha.** `dbt run --select +fato_processo` — o dbt constrói `stg_processos` e `stg_comarcas` antes, sem que ninguém tenha escrito essa ordem.

**O fan-out.** As duas últimas consultas de `consultas/analise.sql`: a média muda de 756,1 para 770,3 dias só por juntar tabelas de grãos diferentes.

**Storage × engine.** Apague `data/gold/dim_comarca.parquet` e tente consultar a Gold: erro. Prova que o dado mora no arquivo, e o DuckDB apenas sabe o endereço.
