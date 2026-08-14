# A mesma pergunta, dois caminhos

> "Qual é o tempo médio de tramitação por vara?"

Este documento mostra a **mesma pergunta** respondida de dois jeitos: direto no banco transacional (OLTP, como no e-SAJ) e na camada Gold do nosso pipeline. Os dois chegam ao **mesmo número** — o que muda é o esforço, o risco de erro e quem paga a conta.

## Caminho 1 — Direto no OLTP

Num sistema transacional real, o modelo é normalizado e orientado a **eventos**:

```text
processo      (processo_id, numero_processo, classe_id, vara_id, situacao_id, data_distribuicao)
vara          (vara_id, comarca_id, numero_vara, nome_vara)
comarca       (comarca_id, nome_comarca, uf)
movimentacao  (movimentacao_id, processo_id, tipo_movimento_id, data_movimento)
tipo_movimento(tipo_movimento_id, descricao)
```

Repare no que **não existe**: uma coluna `data_baixa`. A baixa é uma **movimentação**, como qualquer outro andamento. A consulta:

```sql
with baixa as (
    -- A baixa não é uma coluna: é um EVENTO na tabela de movimentações.
    -- E pode haver mais de uma (reativação!), então pegamos a primeira.
    select
        m.processo_id,
        min(m.data_movimento) as data_baixa
    from movimentacao m
    join tipo_movimento tm on tm.tipo_movimento_id = m.tipo_movimento_id
    where tm.descricao = 'Baixa Definitiva'
    group by m.processo_id
)
select
    c.nome_comarca,
    v.nome_vara,
    count(*)                                                           as processos_baixados,
    round(avg(date_diff('day', p.data_distribuicao, b.data_baixa)), 1) as tempo_medio_dias
from processo p
join vara    v on v.vara_id     = p.vara_id
join comarca c on c.comarca_id  = v.comarca_id     -- comarca vem VIA vara
join baixa   b on b.processo_id = p.processo_id
where p.data_distribuicao is not null
  and b.data_baixa >= p.data_distribuicao          -- descarta data implausível
group by 1, 2
having count(*) >= 3
order by tempo_medio_dias desc;
```

**O que foi preciso saber para escrever isso:**

1. que a baixa é uma **movimentação**, e não uma coluna do processo;
2. que o tipo de movimento está em **outra tabela** (normalização) — mais um join;
3. que um processo pode ter **mais de uma baixa** (reativação) — daí o `min()`;
4. que a comarca **não** se liga direto ao processo: vem **através** da vara;
5. que existem datas implausíveis a filtrar;
6. que a média sobre 1 ou 2 casos não é média.

Total: **5 tabelas, 4 joins, 1 CTE** — e seis decisões de negócio embutidas no SQL. Cada analista que reescrever isso pode tomar decisões diferentes em qualquer um dos seis pontos. É assim que dois relatórios sobre o mesmo dado divergem.

E o custo: essa consulta varre a tabela `movimentacao` — a que mais cresce em qualquer tribunal — **no banco que está atendendo advogados naquele momento**.

## Caminho 2 — Na Gold

```sql
select
    c.nome_comarca,
    f.vara_id                                as vara,
    count(*)                                 as processos_baixados,
    round(avg(f.tempo_tramitacao_dias), 1)   as tempo_medio_dias
from 'data/gold/fato_processo.parquet' f
join 'data/gold/dim_comarca.parquet'  c on f.comarca_id = c.comarca_id
where f.tempo_tramitacao_dias is not null
group by 1, 2
having count(*) >= 3
order by tempo_medio_dias desc;
```

**2 arquivos, 1 join.** As seis decisões continuam existindo — só que foram tomadas **uma vez**, no pipeline, de forma versionada, testada e documentada. `tempo_tramitacao_dias` já é a medida oficial da organização.

## O resultado

Idêntico nos dois caminhos:

| comarca | vara | processos | tempo médio (dias) |
|---|---|---|---|
| Aquidauana | 5ª | 4 | 1007,8 |
| Dourados | 2ª | 6 | 960,8 |
| Campo Grande | 1ª | 6 | 944,5 |

## A moral

O pipeline **não existe para dar respostas diferentes**. Ele existe para que a resposta certa seja:

- **fácil de obter** — 1 join em vez de 4 mais uma CTE;
- **consistente** — a regra da medida está num lugar só, testada;
- **barata** — não compete com o sistema que atende o público;
- **rastreável** — o lineage mostra de onde cada número veio;
- **reproduzível** — amanhã, com dados novos, é só rodar.

> A pergunta não ficou mais fácil de responder. Ela ficou mais difícil de responder **errado**.
