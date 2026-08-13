-- SILVER | stg_movimentacoes: preparação dos eventos de movimentação.
--
-- A ingestão do JSON já vem pronta (src/ingest.py) — o tratamento da
-- qualidade, não: os TODOs abaixo são seus.

{{ config(location='../data/silver/stg_movimentacoes.parquet') }}

with fonte as (

    select * from {{ source('bronze', 'movimentacoes') }}

)

select
    try_cast(processo_id as bigint)     as processo_id,
    tipo_movimento,
    try_cast(data_movimento as date)    as data_movimento
    -- TODO (desafio): tratar datas em formato DD/MM/YYYY (como na stg_processos)

from fonte

-- TODO (desafio): existem movimentos integralmente duplicados — elimine-os.
