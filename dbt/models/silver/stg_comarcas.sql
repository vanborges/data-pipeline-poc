-- SILVER | stg_comarcas: padronização do cadastro de comarcas.

with fonte as (

    select * from {{ source('bronze', 'comarcas') }}

)

select
    cast(comarca_id as integer) as comarca_id,

    -- TODO (em aula): os nomes vêm com caixa e espaços inconsistentes
    --   ("dourados", "TRÊS LAGOAS", "  Aquidauana", "Naviraí ").
    --   Padronize: sugestão -> initcap(trim(nome_comarca))
    nome_comarca,

    upper(trim(uf)) as uf

from fonte
