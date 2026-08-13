-- GOLD | dim_tempo: dimensão de tempo (calendário).
--
-- Por que uma dimensão de tempo? Para "por período" não virar
-- lógica de data repetida em cada consulta: ano, mês, trimestre
-- ficam calculados UMA vez, prontos para agrupar.

{{ config(location='../data/gold/dim_tempo.parquet') }}

with datas as (

    -- Calendário contínuo entre a menor e a maior data do fato.
    select
        cast(range as date) as data
    from range(
        (select min(data_distribuicao) from {{ ref('stg_processos') }}),
        (select coalesce(max(data_baixa), current_date) from {{ ref('stg_processos') }}) + interval 1 day,
        interval 1 day
    )

)

select
    data,
    extract(year from data)  as ano,
    extract(month from data) as mes
    -- TODO (desafio): acrescente nome_mes, trimestre e um marcador de
    --   fim_de_semana. (Dicas: strftime(data, '%B'), quarter(data),
    --   isodow(data) in (6, 7))

from datas
