-- =====================================================================
-- SILVER | stg_movimentacoes
-- =====================================================================
-- Mesmos tratamentos das outras stg_ — mas repare numa coisa: este dado
-- veio de um JSON, e os outros vieram de CSV. Daqui para frente, isso
-- é INDIFERENTE.
--
-- Foi a camada de ingestão que absorveu a diferença entre os formatos
-- e entregou tudo como Parquet. É essa a função dela.
-- =====================================================================

{{ config(location='../data/silver/stg_movimentacoes.parquet') }}

with fonte as (

    select * from {{ source('bronze', 'movimentacoes') }}

)

-- DISTINCT: a origem trouxe 5 eventos integralmente duplicados.
select distinct
    try_cast(processo_id as bigint) as processo_id,
    tipo_movimento,

    -- o mesmo problema de formato de data das outras tabelas:
    -- a maioria em ISO, algumas em DD/MM/AAAA
    coalesce(
        try_cast(data_movimento as date),
        try_cast(try_strptime(data_movimento, '%d/%m/%Y') as date)
    ) as data_movimento

from fonte
