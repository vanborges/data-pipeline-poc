-- GOLD | fato_processo: um registro por processo (grão = processo),
-- com as chaves das dimensões e a MEDIDA que interessa ao negócio.
--
-- É esta tabela que responde:
--   "Qual é o tempo médio de tramitação por comarca, classe e período?"

with processos as (

    select * from {{ ref('stg_processos') }}

)

select
    processo_id,
    comarca_id,
    classe_id,
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
