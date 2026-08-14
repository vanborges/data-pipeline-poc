"""Cria um e-SAJ normalizado (OLTP) para a demonstração.

Gera /tmp/esaj.duckdb com o modelo relacional normalizado a partir das
mesmas fontes da PoC — para comparar, ao vivo, a consulta no OLTP com a
consulta na Gold (ver docs/comparacao-oltp-vs-gold.md).

Uso, da raiz do projeto:
    python scripts/criar_esaj_simulado.py
    python -c "import duckdb; con=duckdb.connect('/tmp/esaj.duckdb'); print(con.sql('show tables'))"
"""

import duckdb

con = duckdb.connect("/tmp/esaj.duckdb")

con.execute("""
create or replace table comarca (comarca_id integer primary key, nome_comarca varchar, uf varchar);
create or replace table vara (vara_id integer primary key, comarca_id integer, numero_vara integer, nome_vara varchar);
create or replace table classe (classe_id integer primary key, nome_classe varchar);
create or replace table situacao (situacao_id integer primary key, descricao varchar);
create or replace table tipo_movimento (tipo_movimento_id integer primary key, descricao varchar);
create or replace table processo (
    processo_id bigint primary key, numero_processo varchar, classe_id integer,
    vara_id integer, situacao_id integer, data_distribuicao date
    -- NÃO existe data_baixa: a baixa é uma movimentação
);
create or replace table movimentacao (
    movimentacao_id bigint primary key, processo_id bigint,
    tipo_movimento_id integer, data_movimento date
);
""")

con.execute("""
insert into comarca
select cast(comarca_id as integer),
       array_to_string(list_transform(string_split(lower(trim(nome_comarca)),' '), w -> upper(w[1])||w[2:]),' '),
       upper(trim(uf))
from 'data/fontes_poc/comarcas.csv';

insert into classe
select distinct on (cast(classe_id as integer)) cast(classe_id as integer), nome_classe
from 'data/fontes_poc/classes.csv';

insert into situacao values (1,'Em andamento'), (2,'Baixado');
insert into tipo_movimento values
 (1,'Distribuição'),(2,'Conclusão'),(3,'Despacho'),(4,'Juntada de Petição'),
 (5,'Audiência'),(6,'Sentença'),(7,'Baixa Definitiva');

insert into vara
select row_number() over (order by c.comarca_id, v.n), c.comarca_id, v.n, v.n || 'ª Vara'
from comarca c cross join (select unnest([1,2,3,4,5]) as n) v;
""")

con.execute("""
create or replace temp table proc_raw as
select
    try_cast(processo_id as bigint) as processo_id,
    try_cast(classe_id as integer) as classe_id,
    try_cast(comarca_id as integer) as comarca_id,
    try_cast(vara_id as integer) as vara_local,
    coalesce(try_cast(data_distribuicao as date),
             try_cast(try_strptime(data_distribuicao,'%d/%m/%Y') as date)) as data_distribuicao,
    coalesce(try_cast(data_baixa as date),
             try_cast(try_strptime(data_baixa,'%d/%m/%Y') as date)) as data_baixa
from 'data/fontes_poc/processos.csv'
where try_cast(processo_id as bigint) is not null
  and try_cast(comarca_id as integer) in (select comarca_id from comarca);

insert into processo
select distinct on (p.processo_id)
    p.processo_id,
    printf('%07d-25.2026.8.12.%04d', p.processo_id % 10000000, p.comarca_id),
    p.classe_id, v.vara_id,
    case when p.data_baixa is not null then 2 else 1 end,
    p.data_distribuicao
from proc_raw p
join vara v on v.comarca_id = p.comarca_id and v.numero_vara = p.vara_local;

insert into movimentacao
select row_number() over () as movimentacao_id, processo_id, tipo_movimento_id, data_movimento
from (
    select processo_id, 1 as tipo_movimento_id, data_distribuicao as data_movimento
    from proc_raw
    union all
    select p.processo_id, 3, p.data_distribuicao + interval (30 + (p.processo_id % 200)) day
    from proc_raw p
    union all
    select p.processo_id, 6, p.data_baixa - interval 20 day
    from proc_raw p where p.data_baixa is not null
    union all
    -- a BAIXA como evento
    select p.processo_id, 7, p.data_baixa
    from proc_raw p where p.data_baixa is not null
);
""")

for t in ["comarca", "vara", "classe", "processo", "movimentacao"]:
    n = con.execute(f"select count(*) from {t}").fetchone()[0]
    print(f"{t:15s} {n}")
print("\nOK -> /tmp/esaj.duckdb")
