-- =====================================================================
-- CONSULTAS DE ANÁLISE — o CONSUMO da camada Gold
-- =====================================================================
-- Execute da raiz do projeto:
--   python -c "import duckdb; print(duckdb.sql(open('consultas/analise.sql').read()))"
--
-- (o DuckDB executa a ÚLTIMA instrução do arquivo — descomente uma por vez)
--
-- Repare em todas elas: NENHUMA regra de negócio. A medida já existe,
-- as decisões já foram tomadas no pipeline. Quem consulta apenas agrupa.
-- =====================================================================


-- =====================================================================
-- 1) A PERGUNTA OFICIAL DA POC
--    "tempo médio de tramitação por comarca, classe e período"
-- =====================================================================
-- 4 arquivos, 3 joins — o star schema em ação: a fato no centro,
-- as três dimensões dando contexto.
select
    c.nome_comarca,
    cl.nome_classe,
    t.ano,
    count(*)                                   as processos_baixados,
    round(avg(f.tempo_tramitacao_dias), 1)     as tempo_medio_dias
from 'data/gold/fato_processo.parquet' f
join 'data/gold/dim_comarca.parquet'  c  on f.comarca_id = c.comarca_id
join 'data/gold/dim_classe.parquet'   cl on f.classe_id  = cl.classe_id
-- ROLE-PLAYING: aqui dim_tempo está no papel de "data de distribuição".
-- Trocar para f.data_baixa responderia outra pergunta: processos
-- BAIXADOS no ano, em vez de DISTRIBUÍDOS no ano.
join 'data/gold/dim_tempo.parquet'    t  on f.data_distribuicao = t.data
-- exclui os processos em andamento (medida nula, por decisão do modelo)
where f.tempo_tramitacao_dias is not null
group by 1, 2, 3
order by 1, 2, 3;


-- =====================================================================
-- 2) EVOLUÇÃO NO TEMPO — por comarca e ano
-- =====================================================================
-- select
--     c.nome_comarca,
--     t.ano,
--     count(*)                                 as processos_baixados,
--     round(avg(f.tempo_tramitacao_dias), 1)   as tempo_medio_dias
-- from 'data/gold/fato_processo.parquet' f
-- join 'data/gold/dim_comarca.parquet' c on f.comarca_id = c.comarca_id
-- join 'data/gold/dim_tempo.parquet'   t on f.data_distribuicao = t.data
-- where f.tempo_tramitacao_dias is not null
-- group by 1, 2
-- order by 1, 2;


-- =====================================================================
-- 3) POR VARA — sempre com a comarca!
-- =====================================================================
-- ⚠ vara_id NÃO é único no estado: a "vara 2" existe em 8 comarcas.
--   Agrupar só por vara_id somaria a 2ª Vara de Campo Grande com a de
--   Dourados — um número que não significa nada.
--
--   O HAVING evita médias calculadas sobre 1 ou 2 processos: uma média
--   de um caso não é uma média.
--
-- select
--     c.nome_comarca,
--     f.vara_id                                as vara,
--     count(*)                                 as processos_baixados,
--     round(avg(f.tempo_tramitacao_dias), 1)   as tempo_medio_dias
-- from 'data/gold/fato_processo.parquet' f
-- join 'data/gold/dim_comarca.parquet' c on f.comarca_id = c.comarca_id
-- where f.tempo_tramitacao_dias is not null
-- group by 1, 2
-- having count(*) >= 3
-- order by tempo_medio_dias desc;


-- =====================================================================
-- 4) A ARMADILHA — mostre em aula antes da consulta 3
-- =====================================================================
-- Olhe a coluna comarcas_diferentes: a mesma vara aparece em várias
-- comarcas. É a prova de que agrupar só por vara_id está errado.
--
-- select
--     vara_id,
--     count(*)                    as processos,
--     count(distinct comarca_id)  as comarcas_diferentes
-- from 'data/gold/fato_processo.parquet'
-- where tempo_tramitacao_dias is not null
-- group by 1 order by 1;


-- =====================================================================
-- 5) FAN-OUT — o erro nº 1 com tabelas fato
-- =====================================================================
-- A fato está no grão de PROCESSO. Ao juntá-la com movimentações
-- (grão de EVENTO), cada processo vira várias linhas e a média muda —
-- sem nenhum erro de sintaxe.
--
-- Compare o resultado das duas:
--
-- select count(*) as linhas, round(avg(tempo_tramitacao_dias),1) as media
-- from 'data/gold/fato_processo.parquet' where tempo_tramitacao_dias is not null;
--
-- select count(*) as linhas, round(avg(f.tempo_tramitacao_dias),1) as media
-- from 'data/gold/fato_processo.parquet' f
-- join 'data/silver/stg_movimentacoes.parquet' m on m.processo_id = f.processo_id
-- where f.tempo_tramitacao_dias is not null;
