-- SILVER | stg_comarcas: padronização do cadastro de comarcas.

{{ config(location='../data/silver/stg_comarcas.parquet') }}

with fonte as (

    select * from {{ source('bronze', 'comarcas') }}

)

select
    cast(comarca_id as integer) as comarca_id,

    -- TODO (em aula): os nomes vêm com caixa e espaços inconsistentes
    --   ("dourados", "TRÊS LAGOAS", "  Aquidauana", "Naviraí ").
    --   Padronize para "Título" (primeira letra de cada palavra maiúscula).
    --   Dica (DuckDB não tem initcap!): quebre em palavras e recomponha:
    --   array_to_string(
    --       list_transform(string_split(lower(trim(nome_comarca)), ' '),
    --                      w -> upper(w[1]) || w[2:]),
    --       ' ')
    nome_comarca,

    upper(trim(uf)) as uf

from fonte
