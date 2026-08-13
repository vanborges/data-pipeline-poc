# POC — Passo a passo da atividade

Este é o roteiro que você vai seguir. Leia o [`README.md`](README.md) antes: ele explica o que é a PoC, a pergunta de negócio e a arquitetura.

**A pergunta que precisamos responder ao final:**

> Qual é o tempo médio de tramitação por comarca, classe e período?

---

## Passo 0 — Preparar o ambiente

Requisitos: **Python 3.10 ou superior** e Git.

**Linux / macOS**

```bash
git clone <url-do-repositorio>
cd data-pipeline-poc

python3 -m venv .venv
source .venv/bin/activate

pip install -r requirements.txt
cp .env.example .env
```

Depois de ativar o ambiente, seu prompt mostra `(.venv)` — é o sinal de que você está no ambiente isolado do projeto. A partir daí, **os comandos dos próximos passos são sempre os mesmos**, inclusive `python -m src.pipeline`: dentro do venv, `python` e `pip` apontam para o interpretador do projeto.

**Alternativa: quem usa Anaconda/Miniconda**

```bash
conda create -n poc python=3.12 -y
conda activate poc

pip install -r requirements.txt
cp .env.example .env
```

Nesse caso o prompt mostra `(poc)` em vez de `(.venv)`. Use **um** dos dois caminhos (venv **ou** conda) — misturar os dois costuma gerar confusão sobre qual `python` está valendo.

### Se algo falhar

| Erro | O que fazer |
|---|---|
| `command not found: python` | use `python3` para **criar** o venv; depois de ativá-lo, `python` funciona |
| `pip: bad interpreter: .../python@3.x` | é o pip do sistema (Homebrew) quebrado — ignore-o: crie e ative o venv, e use o `pip` de dentro dele |
| `python3` não existe | instale com `brew install python@3.12` — ou use o caminho com conda acima |
| `source .venv/bin/activate` diz *no such file* | o venv não chegou a ser criado: rode o `python3 -m venv .venv` de novo e confira se ele terminou sem erro |

> O `.env` guarda a configuração (caminhos das pastas) e **não** é versionado. Em projetos reais é onde ficam credenciais — por isso essa separação existe desde o início.

---

## Passo 1 — Conhecer as fontes

Abra os arquivos em `data/fontes_poc/`:

| Arquivo | Formato | Conteúdo |
|---|---|---|
| `processos.csv` | CSV | processos: ids, comarca, classe, datas de distribuição/baixa, situação |
| `movimentacoes.json` | JSON | eventos de movimentação por processo |
| `comarcas.csv` | CSV | cadastro de comarcas |
| `classes.csv` | CSV | cadastro de classes processuais |

**Pense antes de seguir:** os dados existem e estão à mão. Você já consegue responder a pergunta de negócio? O que falta?

---

## Passo 2 — Executar a ingestão (Fontes → Bronze)

```bash
python -m src.pipeline
```

**O que aconteceu:**

- cada função de `src/ingest.py` leu uma fonte com Pandas (**tudo como texto**)
- acrescentou o metadado `_ingerido_em`
- gravou um Parquet em `data/bronze/`

Abra `data/bronze/` e confira os arquivos criados: quatro Parquet, um por fonte.

Vale abrir o `src/ingest.py` e comparar `ingest_processos()` (CSV) com `ingest_movimentacoes()` (JSON): muda o leitor, mas o destino é o mesmo. **É essa a função da ingestão — absorver a diversidade das fontes e entregar um formato único para o resto do pipeline.**

> Bronze = o que o pipeline capturou, próximo à origem.
> Mudou o **formato** (CSV/JSON → Parquet), não o **conteúdo**.

---

## Passo 3 — Investigar a qualidade dos dados

Consulte o Bronze direto, sem importar nada:

```bash
python -c "import duckdb; print(duckdb.sql(\"select * from 'data/bronze/processos.parquet' limit 10\"))"
```

> Prefere uma interface visual? Abra **`notebooks/exploracao.ipynb`** no VS Code: ele traz estas mesmas investigações prontas, além de uma seção que mostra o Parquet por dentro (schema, compressão por coluna) e a comparação entre as camadas.

Procure problemas. Sugestões de investigação:

```sql
-- datas em formatos diferentes?
select data_distribuicao from 'data/bronze/processos.parquet' order by 1 desc limit 10;

-- registros duplicados?
select processo_id, count(*) from 'data/bronze/processos.parquet'
group by 1 having count(*) > 1;

-- identificadores ausentes ou estranhos?
select * from 'data/bronze/processos.parquet' where processo_id is null or processo_id = '';

-- nomes de comarca padronizados?
select nome_comarca from 'data/bronze/comarcas.parquet';
```

**Anote o que encontrar.** Cada problema aqui vira uma decisão no próximo passo.

**Pense:** quem deve corrigir isso — e em qual camada?

---

## Passo 4 — Construir a Silver com dbt

```bash
cd dbt
dbt debug     # confere ambiente e conexão
dbt run       # constrói Silver e Gold
dbt test      # executa as regras de qualidade
```

O `dbt test` vai **falhar**. Isso é esperado: as falhas apontam exatamente os problemas que você encontrou no Passo 3. Um teste que falha não é um bug do seu SQL — é um dado violando uma regra declarada.

Agora abra os modelos em `dbt/models/silver/` e resolva os `TODO`:

- **`stg_processos.sql`** — datas em `DD/MM/YYYY` viram NULL no `try_cast`;
trate o formato alternativo. Depois: linhas duplicadas e `processo_id` nulo.
- **`stg_comarcas.sql`** — padronize os nomes (caixa e espaços inconsistentes).
- **`stg_classes.sql`** — o mesmo `classe_id` aparece com duas grafias:
deduplique e escolha a grafia oficial.

A cada mudança, rode de novo:

```bash
dbt run && dbt test
```

Acompanhe os arquivos sendo reescritos em `data/silver/`.

> Silver = dado limpo, tipado, padronizado. Aqui muda o **conteúdo**.

---

## Passo 5 — Construir a Gold

Em `dbt/models/gold/`:

- **`fato_processo.sql`** — calcule `tempo_tramitacao_dias`
(dica: `date_diff('day', data_distribuicao, data_baixa)`). Decida: processos **em andamento** entram na média? E se o tempo der **negativo**, o que isso significa?
- **`dim_tempo.sql`** — acrescente `nome_mes`, `trimestre` e `fim_de_semana`.

```bash
dbt run
```

Repare no `ref()` dos modelos: você nunca escreveu a ordem de execução — o dbt a deduz das dependências declaradas. É assim que nasce a DAG.

> Gold = dado organizado para consumo. Aqui muda a **modelagem**
> (fato + dimensões = star schema) e nasce a **medida**.

---

## Passo 6 — Tratar as movimentações na Silver

A ingestão do JSON já veio pronta, mas o **tratamento** não. Abra `dbt/models/silver/stg_movimentacoes.sql` e resolva os TODOs:

- datas em formato `DD/MM/YYYY` (o mesmo problema da `stg_processos`);
- eventos integralmente duplicados.

```bash
dbt run && dbt test
```

Depois, uma pergunta de integridade: existe movimentação apontando para um processo que não está na base? (Dica: um `left join` entre `stg_movimentacoes` e `stg_processos` responde — e um teste `relationships` transforma isso em regra permanente.)

---

## Passo 7 — Ampliar os testes

Em `dbt/models/silver/schema.yml` e `gold/schema.yml`:

- teste `accepted_values` em `situacao` (aceitando `Baixado` e `Em andamento`)
- teste `unique` em `stg_classes.classe_id` (após deduplicar)
- teste `relationships` entre `fato_processo.classe_id` e `dim_classe`

Em `tests/test_ingestion.py`, escreva o teste da ingestão do JSON e rode:

```bash
pytest
```

> `pytest` testa o **código**; `dbt test` testa os **dados**. São complementares.

**Meta:** `dbt test` sem nenhuma falha.

---

## Passo 8 — Responder a pergunta de negócio

Com a Gold pronta, escreva a consulta que responde:

> Qual é o tempo médio de tramitação por comarca, classe e período?

Ela vai unir o fato às três dimensões. Execute a partir da raiz do projeto:

```bash
python -c "import duckdb; print(duckdb.sql(open('minha_consulta.sql').read()))"
```

Onde `minha_consulta.sql` lê a Gold direto do storage — por exemplo: `from 'data/gold/fato_processo.parquet' f join 'data/gold/dim_comarca.parquet' c on ...`

---

## Passo 9 — Documentação e lineage

```bash
cd dbt
dbt docs generate
dbt docs serve
```

Abra a DAG no navegador e percorra o caminho de um dado: da fonte até o fato. Compare com o desenho conceitual da aula:

```text
Fonte → Ingestão → Armazenamento → Transformação → Serving → Consumo
```

**Agora esse desenho existe de verdade.**

---

## Checklist de entrega

```text
[ ] Ambiente preparado e pipeline executado
[ ] Problemas de qualidade identificados e documentados
[ ] Silver tratando datas, duplicatas e padronização
[ ] Movimentações tratadas na Silver (datas e duplicatas)
[ ] Gold com tempo_tramitacao_dias e dim_tempo completa
[ ] Testes dbt ampliados e todos passando
[ ] Teste pytest adicional escrito
[ ] Consulta final respondendo a pergunta de negócio
[ ] dbt docs gerado (lineage)
```

## Para pensar e discutir

- **Engenharia:** o que você **construiu** nesta atividade?
- **Gestão:** o que precisaria ser **mantido** para isso continuar funcionando
amanhã, com dados novos?
- **Governança:** quais decisões você tomou que **não eram técnicas**?
(Qual grafia da classe é a oficial? Um processo com comarca inexistente deve ser descartado? Quem decide isso numa organização real?)
