-- GOLD | fato_processo: um registro por processo (grão = processo),
-- com as chaves das dimensões e a MEDIDA que interessa ao negócio.
--
-- É esta tabela que responde:
--   "Qual é o tempo médio de tramitação por comarca, classe e período?"

{{ config(location='../data/gold/fato_processo.parquet') }}

with processos as (

    select * from {{ ref('stg_processos') }}

)

select
    processo_id,
    comarca_id,
    classe_id,

    -- vara_id é uma DIMENSÃO DEGENERADA: fica na própria fato porque a
    -- origem só nos dá o identificador, sem nome nem atributos — não há
    -- o que colocar numa dim_vara. Se amanhã chegasse um cadastro de varas
    -- (nome, competência, magistrado), aí sim valeria uma dimensão própria.
    --
    -- ⚠ ATENÇÃO ao analisar: vara_id NÃO é único no estado — a "vara 2"
    -- existe em várias comarcas. Agrupar só por vara_id mistura varas
    -- diferentes. A identificação real é o par (comarca_id, vara_id).
    vara_id,

    data_distribuicao,
    data_baixa,
    situacao,

    -- TODO (em aula): calcular a medida central da PoC:
    --   tempo_tramitacao_dias = dias entre distribuição e baixa.
    --   Dica: date_diff('day', data_distribuicao, data_baixa)
    --   Discussão: e os processos ainda EM ANDAMENTO (data_baixa nula)?
    --   E se aparecer tempo NEGATIVO — o que isso diz sobre a origem?
    cast(null as integer) as tempo_tramitacao_dias

from processos
